local ADDON_NAME, ns = ...
local MAT = ns.MAT
local L = ns.L

local LFG = MAT:NewModule("LFG", "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0")
MAT.LFG = LFG

-- ============================================================
-- LFG/LFM — peer-to-peer team finder over a hidden custom
-- chat channel. Only players who also run Meteora Arena Tool
-- see and post listings.
--
-- Wire format (LibSerialize + LibDeflate, encoded for addon
-- channel):
--   { op = "POST", listing = { ... } }   -- broadcast (re-sent every 30s while active)
--   { op = "CLEAR" }                     -- sender stops their listing
--   { op = "PING" }                      -- request: please re-broadcast now
--
-- Listing schema (db.profile.lfg.myListing mirror):
--   {
--     kind        = "LFG" or "LFM",
--     bracket     = "2v2" / "3v3" / "5v5" / "Skirmish",
--     myClassFile = "PALADIN",  -- auto-filled from UnitClass on Post
--     myRating    = 1750 or nil,
--     wantClasses = { "PALADIN", "DRUID" } or {},   -- empty = any
--     comment     = "glad exp" or "",
--     createdAt   = epoch seconds,
--     expiresAt   = epoch seconds,
--   }
--
-- Receivers track lastSeen and prune anything older than TTL.
-- ============================================================

LFG.commPrefix  = "MATLFG2"
LFG.channelName = "MeteoraArena"

local BCAST_INTERVAL   = 30   -- secs: re-send our own listing
local CLEANUP_INTERVAL = 15   -- secs: drop stale listings
local LISTING_TTL      = 90   -- secs without bcast → drop remote listing
local CHANNEL_CHECK    = 20   -- secs: try rejoin if dropped
local DEFAULT_EXPIRY_MIN = 30 -- minutes for new listing
local MAX_LISTINGS     = 200  -- cap to avoid runaway memory
local MAX_COMMENT_LEN  = 120

local LibSerialize = LibStub("LibSerialize")
local LibDeflate   = LibStub("LibDeflate")

local listings = {}     -- [senderName] = { listing = {...}, lastSeen = GetTime() }
local sentPrefixRegistered = false

-- ------------------------------------------------------------
-- Encoding
-- ------------------------------------------------------------

local function encode(tbl)
    local ok, ser = pcall(LibSerialize.Serialize, LibSerialize, tbl)
    if not ok or not ser then return nil end
    local comp = LibDeflate:CompressDeflate(ser, { level = 5 })
    if not comp then return nil end
    return LibDeflate:EncodeForWoWAddonChannel(comp)
end

local function decode(str)
    if type(str) ~= "string" or str == "" then return nil end
    local comp = LibDeflate:DecodeForWoWAddonChannel(str)
    if not comp then return nil end
    local ser = LibDeflate:DecompressDeflate(comp)
    if not ser then return nil end
    local ok, tbl = LibSerialize:Deserialize(ser)
    if not ok then return nil end
    return tbl
end

-- ------------------------------------------------------------
-- Channel join / hide
-- ------------------------------------------------------------

local function channelId()
    if not GetChannelName then return 0 end
    local id = GetChannelName(LFG.channelName)
    return id or 0
end

local function hideChannelFromUI()
    -- Strip the channel from all chat windows so the user doesn't see addon noise.
    if not ChatFrame_RemoveChannel then return end
    local n = _G.NUM_CHAT_WINDOWS or 10
    for i = 1, n do
        local cf = _G["ChatFrame" .. i]
        if cf then pcall(ChatFrame_RemoveChannel, cf, LFG.channelName) end
    end
end

local joinAnnounced = false

local function tryJoinChannel()
    local existing = channelId()
    if existing ~= 0 then
        if not joinAnnounced then
            MAT:Print(string.format("|cffffd200LFG|r " ..
                ((L["lfg_chan_joined"] or "joined channel #%d (%s)")),
                existing, LFG.channelName))
            joinAnnounced = true
        end
        return true
    end
    if not JoinTemporaryChannel then return false end
    pcall(JoinTemporaryChannel, LFG.channelName)
    -- Defer hide a tick — channel join is async; chat frames pick it up next frame.
    if LFG.ScheduleTimer then
        LFG:ScheduleTimer(hideChannelFromUI, 0.5)
        LFG:ScheduleTimer(hideChannelFromUI, 2.0)
    end
    local id = channelId()
    if id ~= 0 and not joinAnnounced then
        MAT:Print(string.format("|cffffd200LFG|r " ..
            ((L["lfg_chan_joined"] or "joined channel #%d (%s)")),
            id, LFG.channelName))
        joinAnnounced = true
    end
    return id ~= 0
end

-- ------------------------------------------------------------
-- Send helpers
-- ------------------------------------------------------------

local function rawSend(prefix, text, dist, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(prefix, text, dist, target)
    end
    if _G.SendAddonMessage then
        return _G.SendAddonMessage(prefix, text, dist, target)
    end
end

local function ensurePrefixRegistered()
    if sentPrefixRegistered then return end
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, LFG.commPrefix)
    end
    sentPrefixRegistered = true
end

local function broadcast(msg)
    local id = channelId()
    if id == 0 then return false end
    local enc = encode(msg)
    if not enc then return false end
    ensurePrefixRegistered()
    -- TBC 2.5.5: target for "CHANNEL" must be the numeric channel index
    -- (as a stringified number), NOT the channel name. Passing the name
    -- silently drops the message.
    rawSend(LFG.commPrefix, enc, "CHANNEL", tostring(id))
    return true
end

-- ------------------------------------------------------------
-- Validation
-- ------------------------------------------------------------

local VALID_BRACKETS = { ["2v2"] = true, ["3v3"] = true, ["5v5"] = true, ["Skirmish"] = true }
local VALID_KINDS    = { LFG = true, LFM = true }
local VALID_CLASSES  = {
    WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true,
    DEATHKNIGHT = true,  -- accept in case of expansion future-proofing
}

local function sanitizeListing(l)
    if type(l) ~= "table" then return nil end
    if not VALID_KINDS[l.kind] then return nil end
    if not VALID_BRACKETS[l.bracket] then return nil end

    local out = {
        kind        = l.kind,
        bracket     = l.bracket,
        myClassFile = VALID_CLASSES[l.myClassFile] and l.myClassFile or nil,
        myRating    = (type(l.myRating) == "number" and l.myRating > 0 and l.myRating < 10000) and math.floor(l.myRating) or nil,
        wantClasses = {},
        comment     = "",
        createdAt   = (type(l.createdAt) == "number") and l.createdAt or time(),
        expiresAt   = (type(l.expiresAt) == "number") and l.expiresAt or (time() + DEFAULT_EXPIRY_MIN * 60),
    }

    if type(l.wantClasses) == "table" then
        local seen = {}
        for _, c in ipairs(l.wantClasses) do
            if VALID_CLASSES[c] and not seen[c] then
                seen[c] = true
                table.insert(out.wantClasses, c)
            end
        end
    end

    if type(l.comment) == "string" then
        local c = l.comment:gsub("[%c]", " "):sub(1, MAX_COMMENT_LEN)
        out.comment = c
    end

    return out
end

-- ------------------------------------------------------------
-- Module lifecycle
-- ------------------------------------------------------------

local bcastTimer, cleanupTimer, channelTimer

function LFG:OnEnable()
    MAT.db.profile.lfg = MAT.db.profile.lfg or {}
    local lfg = MAT.db.profile.lfg
    if lfg.expiryMin == nil then lfg.expiryMin = DEFAULT_EXPIRY_MIN end
    if lfg.minRating == nil then lfg.minRating = 0 end
    if lfg.maxRating == nil then lfg.maxRating = 3000 end
    if lfg.filterBracket == nil then lfg.filterBracket = "all" end
    if lfg.filterClass == nil then lfg.filterClass = "all" end
    -- lfg.myListing = nil or persisted listing table

    ensurePrefixRegistered()

    self:RegisterComm(self.commPrefix, "OnCommReceived")

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", "OnChannelNotice")

    channelTimer = self:ScheduleRepeatingTimer("EnsureChannel", CHANNEL_CHECK)
    cleanupTimer = self:ScheduleRepeatingTimer("PruneStale", CLEANUP_INTERVAL)

    -- Boot: try to join after the world is up (chat system needs a beat).
    self:ScheduleTimer("EnsureChannel", 5)

    -- Restore broadcast loop if a listing was persisted across logout.
    local my = lfg.myListing
    if my and my.expiresAt and my.expiresAt > time() then
        -- valid persisted listing → resume broadcasting
        self:ScheduleTimer(function() self:StartBroadcastLoop() end, 8)
    elseif my then
        lfg.myListing = nil  -- expired
    end
end

function LFG:OnEnteringWorld()
    self:ScheduleTimer("EnsureChannel", 3)
    -- Re-announce ourselves so peers in the new zone see us immediately.
    if MAT.db.profile.lfg.myListing then
        self:ScheduleTimer(function() self:BroadcastSelf() end, 5)
    end
end

function LFG:OnChannelNotice(_, kind, _, _, _, _, _, _, _, _, channelName)
    if channelName ~= self.channelName then return end
    if kind == "YOU_LEFT" or kind == "SUSPENDED" or kind == "INVALID_NAME" then
        self:ScheduleTimer("EnsureChannel", 3)
    elseif kind == "YOU_JOINED" then
        self:ScheduleTimer(hideChannelFromUI, 0.3)
        self:ScheduleTimer(hideChannelFromUI, 1.5)
        -- Ask peers to re-broadcast so our list populates fast.
        self:ScheduleTimer(function() broadcast({ op = "PING" }) end, 2)
        if MAT.db.profile.lfg.myListing then
            self:ScheduleTimer(function() self:BroadcastSelf() end, 3)
        end
    end
end

function LFG:EnsureChannel()
    tryJoinChannel()
end

-- ------------------------------------------------------------
-- Incoming
-- ------------------------------------------------------------

local function shortSender(sender)
    -- Strip "-Realm" suffix for our display/key (TBC Anniversary is single-realm in practice).
    if type(sender) ~= "string" then return sender end
    return sender:match("^([^-]+)") or sender
end

function LFG:OnCommReceived(_, payload, _, sender)
    if not sender or sender == "" then return end
    local me = UnitName("player")
    if shortSender(sender) == me then return end  -- ignore our own echoes

    local msg = decode(payload)
    if not msg or type(msg) ~= "table" then return end

    local op = msg.op
    if op == "POST" then
        local l = sanitizeListing(msg.listing)
        if not l then return end
        if l.expiresAt < time() then return end
        listings[shortSender(sender)] = { listing = l, lastSeen = GetTime(), sender = sender }
        self:CapListings()
        MAT:SendMessage("MAT_LFG_UPDATED")
    elseif op == "CLEAR" then
        if listings[shortSender(sender)] then
            listings[shortSender(sender)] = nil
            MAT:SendMessage("MAT_LFG_UPDATED")
        end
    elseif op == "PING" then
        if MAT.db.profile.lfg.myListing then
            -- jitter 0.5..3.5s so 20 addon users don't all reply in the same frame
            local jitter = 0.5 + math.random() * 3.0
            self:ScheduleTimer(function() self:BroadcastSelf() end, jitter)
        end
    end
end

function LFG:CapListings()
    local count = 0
    for _ in pairs(listings) do count = count + 1 end
    if count <= MAX_LISTINGS then return end
    -- Drop oldest by lastSeen
    local arr = {}
    for k, v in pairs(listings) do table.insert(arr, { k = k, t = v.lastSeen or 0 }) end
    table.sort(arr, function(a, b) return a.t < b.t end)
    for i = 1, count - MAX_LISTINGS do
        listings[arr[i].k] = nil
    end
end

function LFG:PruneStale()
    local now = GetTime()
    local realnow = time()
    local changed = false
    for k, v in pairs(listings) do
        local dead = false
        if (v.lastSeen or 0) + LISTING_TTL < now then dead = true end
        if v.listing and v.listing.expiresAt and v.listing.expiresAt < realnow then dead = true end
        if dead then
            listings[k] = nil
            changed = true
        end
    end
    -- Auto-expire our own listing
    local my = MAT.db.profile.lfg.myListing
    if my and my.expiresAt and my.expiresAt < realnow then
        self:Clear(true)  -- silent: no need to send CLEAR for expiry
        changed = true
    end
    if changed then MAT:SendMessage("MAT_LFG_UPDATED") end
end

-- ------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------

function LFG:GetListings()
    -- newest first
    local out = {}
    for name, v in pairs(listings) do
        table.insert(out, {
            name     = name,
            sender   = v.sender,
            listing  = v.listing,
            lastSeen = v.lastSeen,
        })
    end
    table.sort(out, function(a, b)
        return (a.listing.createdAt or 0) > (b.listing.createdAt or 0)
    end)
    return out
end

function LFG:GetMyListing()
    return MAT.db.profile.lfg.myListing
end

function LFG:IsActive()
    local my = MAT.db.profile.lfg.myListing
    return my ~= nil and my.expiresAt and my.expiresAt > time()
end

function LFG:Post(input)
    -- input: { kind, bracket, myRating, wantClasses, comment, expiryMin }
    local _, classFile = UnitClass("player")
    local expiryMin = tonumber(input.expiryMin) or DEFAULT_EXPIRY_MIN
    if expiryMin < 5 then expiryMin = 5 end
    if expiryMin > 120 then expiryMin = 120 end

    local listing = {
        kind        = input.kind,
        bracket     = input.bracket,
        myClassFile = classFile,
        myRating    = tonumber(input.myRating),
        wantClasses = input.wantClasses or {},
        comment     = input.comment or "",
        createdAt   = time(),
        expiresAt   = time() + expiryMin * 60,
    }
    listing = sanitizeListing(listing)
    if not listing then
        MAT:Print("|cffff5555LFG:|r " .. (L["lfg_invalid"] or "invalid listing"))
        return false
    end

    MAT.db.profile.lfg.myListing = listing
    self:StartBroadcastLoop()
    self:BroadcastSelf()  -- send first one immediately
    MAT:SendMessage("MAT_LFG_UPDATED")
    return true
end

function LFG:Clear(silent)
    local had = MAT.db.profile.lfg.myListing ~= nil
    MAT.db.profile.lfg.myListing = nil
    if bcastTimer then self:CancelTimer(bcastTimer); bcastTimer = nil end
    if had and not silent then
        broadcast({ op = "CLEAR" })
    end
    MAT:SendMessage("MAT_LFG_UPDATED")
end

function LFG:BroadcastSelf()
    local my = MAT.db.profile.lfg.myListing
    if not my then return end
    if my.expiresAt and my.expiresAt < time() then
        self:Clear(true); return
    end
    broadcast({ op = "POST", listing = my })
end

function LFG:StartBroadcastLoop()
    if bcastTimer then self:CancelTimer(bcastTimer) end
    bcastTimer = self:ScheduleRepeatingTimer("BroadcastSelf", BCAST_INTERVAL)
end

function LFG:RequestPing()
    -- UI "Refresh" button → ask everyone to re-broadcast
    return broadcast({ op = "PING" })
end

function LFG:WipeRemote()
    -- Debug/support
    wipe(listings)
    MAT:SendMessage("MAT_LFG_UPDATED")
end

function LFG:DebugStatus()
    local count = 0
    for _ in pairs(listings) do count = count + 1 end
    MAT:Print(string.format("|cffffd200LFG|r channel id=%d, listings=%d, mine=%s",
        channelId(), count,
        MAT.db.profile.lfg.myListing and "yes" or "no"))
end

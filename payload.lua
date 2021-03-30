local _, ns = ...

local PARTY_GROUP_TYPE = 0
local RAID_GROUP_TYPE = 1
local GCD_PATTERN = '!%H%M%d%m%Y'

local payload = ns:AddModule("payload")
local util = ns:GetModule("util")
local partyTracker = ns:GetModule("partyTracker")


local _d = date

local function grp()
    return util:GetNameRealm("player")
end

local function mbt(bits)
	local f = { }
	for i = 0, 255 do
		f[i] = { }
	end
	
	f[0][0] = bits[1] * 255

	local m = 1
	
	for k = 0, 7 do
		for i = 0, m - 1 do
			for j = 0, m - 1 do
				local fij = f[i][j] - bits[1] * m
				f[i  ][j+m] = fij + bits[2] * m
				f[i+m][j  ] = fij + bits[3] * m
				f[i+m][j+m] = fij + bits[4] * m
			end
		end
		m = m * 2
	end
	
	return f
end
local byte_xor = mbt { 0, 1, 1, 0 }

local function generate(self, count)
	local S, i, j = self.S, self.i, self.j
	local o = { }
	local char = string.char
	
	for z = 1, count do
		i = (i + 1) % 256
		j = (j + S[i]) % 256
		S[i], S[j] = S[j], S[i]
		o[z] = char(S[(S[i] + S[j]) % 256])
	end
	
	self.i, self.j = i, j
	return table.concat(o)
end

local function rehpic(self, plaintext)
	local pad = generate(self, #plaintext)
	local r = { }
	local byte = string.byte
	local char = string.char
	
	for i = 1, #plaintext do
		r[i] = char(byte_xor[byte(plaintext, i)][byte(pad, i)])
	end
	
	return table.concat(r)
end

local function schedule(self, key)
	local S = self.S
	local j, kz = 0, #key
	local byte = string.byte
	
	for i = 0, 255 do
		j = (j + S[i] + byte(key, (i % kz) + 1)) % 256;
		S[i], S[j] = S[j], S[i]
	end
end

local function new(key)
	local S = { }
	local r = {
		S = S, i = 0, j = 0,
		generate = generate,
		rehpic = rehpic,
		schedule = schedule	
	}
	
	for i = 0, 255 do
		S[i] = i
	end
	
	if key then
		r:schedule(key)
	end
	
	return r	
end


local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_' 
function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function payload:Generate()
    local cd = _d(GCD_PATTERN, GetServerTime())
    local rpn = grp()
    local pm = partyTracker:GetData()
    local pmD = ""

    for n, d in pairs(pm) do
        pmD = pmD .. n
        pmD = pmD .. "["
        
        pmD = pmD .. d.raceId
        pmD = pmD .. d.classId
        pmD = pmD .. d.genderId
        pmD = pmD .. d.joined
        pmD = pmD .. d.lastSeenAt
        pmD = pmD .. tostring(not d.emittedLeftEvent)

        pmD = pmD .. "];"
    end

    if pmD == "" then
        return nil, nil
    end

    return new(cd):rehpic(pmD), new(rpn):rehpic(cd)
end

local copyPayloadPopup = {
    id = "WOWREPIO_COPY_PAYLOAD_URL",
    text = "Use this URL to review your team mates",
    button2 = CLOSE,
    hasEditBox = true,
    hasWideEditBox = true,
    editBoxWidth = 500,
    preferredIndex = 3,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self)
        self:SetWidth(420)
        local editBox = _G[self:GetName() .. "WideEditBox"] or _G[self:GetName() .. "EditBox"]
        editBox:SetText(self.text.text_arg1)
        editBox:SetFocus()
        editBox:HighlightText(false)
        local button = _G[self:GetName() .. "Button2"]
        button:ClearAllPoints()
        button:SetWidth(200)
        button:SetPoint("CENTER", editBox, "CENTER", 0, -30)
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    OnHide = nil,
    OnAccept = nil,
    OnCancel = nil
}

function payload:Show()
    local p1, p2 = payload:Generate()

    if not p1 and not p2 then 
        StaticPopup_Show(copyPayloadPopup.id, "There is no data")
        return
    end

    StaticPopup_Show(copyPayloadPopup.id, format("https://wowrep.io/team_review?payload=%s", enc(format("%s%s", p1, p2))))
end

function payload:OnReady() 
    StaticPopupDialogs[copyPayloadPopup.id] = copyPayloadPopup
end
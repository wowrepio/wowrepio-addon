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


local function check_int(n)
   -- checking not float
   if(n - math.floor(n) > 0) then
      error("trying to use bitwise operation on non-integer!")
   end
end

local function to_bits(n)
   check_int(n)
   if(n < 0) then
      -- negative
      return to_bits(bit.bnot(math.abs(n)) + 1)
   end
   -- to bits table
   local tbl = {}
   local cnt = 1
   while (n > 0) do
      local last = mod(n,2)
      if(last == 1) then
         tbl[cnt] = 1
      else
         tbl[cnt] = 0
      end
      n = (n-last)/2
      cnt = cnt + 1
   end
   
   return tbl
end

local function tbl_to_number(tbl)
   local n = table.getn(tbl)
   
   local rslt = 0
   local power = 1
   for i = 1, n do
      rslt = rslt + tbl[i]*power
      power = power*2
   end
   
   return rslt
end

local function expand(tbl_m, tbl_n)
   local big = {}
   local small = {}
   if(table.getn(tbl_m) > table.getn(tbl_n)) then
      big = tbl_m
      small = tbl_n
   else
      big = tbl_n
      small = tbl_m
   end
   -- expand small
   for i = table.getn(small) + 1, table.getn(big) do
      small[i] = 0
   end
   
end

local function bit_or(m, n)
   local tbl_m = to_bits(m)
   local tbl_n = to_bits(n)
   expand(tbl_m, tbl_n)
   
   local tbl = {}
   local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
   for i = 1, rslt do
      if(tbl_m[i]== 0 and tbl_n[i] == 0) then
         tbl[i] = 0
      else
         tbl[i] = 1
      end
   end
   
   return tbl_to_number(tbl)
end

local function bit_and(m, n)
   local tbl_m = to_bits(m)
   local tbl_n = to_bits(n)
   expand(tbl_m, tbl_n) 
   
   local tbl = {}
   local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
   for i = 1, rslt do
      if(tbl_m[i]== 0 or tbl_n[i] == 0) then
         tbl[i] = 0
      else
         tbl[i] = 1
      end
   end
   
   return tbl_to_number(tbl)
end

local function bit_not(n)
   
   local tbl = to_bits(n)
   local size = math.max(table.getn(tbl), 32)
   for i = 1, size do
      if(tbl[i] == 1) then 
         tbl[i] = 0
      else
         tbl[i] = 1
      end
   end
   return tbl_to_number(tbl)
end

local function bit_xor(m, n)
   local tbl_m = to_bits(m)
   local tbl_n = to_bits(n)
   expand(tbl_m, tbl_n) 
   
   local tbl = {}
   local rslt = math.max(table.getn(tbl_m), table.getn(tbl_n))
   for i = 1, rslt do
      if(tbl_m[i] ~= tbl_n[i]) then
         tbl[i] = 1
      else
         tbl[i] = 0
      end
   end
   
   --table.foreach(tbl, print)
   
   return tbl_to_number(tbl)
end

local function bit_rshift(n, bits)
   check_int(n)
   
   local high_bit = 0
   if(n < 0) then
      -- negative
      n = bit_not(math.abs(n)) + 1
      high_bit = 2147483648 -- 0x80000000
   end
   
   for i=1, bits do
      n = n/2
      n = bit_or(math.floor(n), high_bit)
   end
   return math.floor(n)
end

-- logic rightshift assures zero filling shift
local function bit_logic_rshift(n, bits)
   check_int(n)
   if(n < 0) then
      -- negative
      n = bit_not(math.abs(n)) + 1
   end
   for i=1, bits do
      n = n/2
   end
   return math.floor(n)
end

local function bit_lshift(n, bits)
   check_int(n)
   
   if(n < 0) then
      -- negative
      n = bit_not(math.abs(n)) + 1
   end
   
   for i=1, bits do
      n = n*2
   end
   return bit_and(n, 4294967295) -- 0xFFFFFFFF
end

local function bit_xor2(m, n)
   local rhs = bit_or(bit_not(m), bit_not(n))
   local lhs = bit_or(m, n)
   local rslt = bit_and(lhs, rhs)
   return rslt
end

--------------------
-- bit lib interface

local bit = {
   -- bit operations
   bnot = bit_not,
   band = bit_and,
   bor  = bit_or,
   bxor = bit_xor,
   brshift = bit_rshift,
   blshift = bit_lshift,
   bxor2 = bit_xor2,
   blogic_rshift = bit_logic_rshift,
   
   -- utility func
   tobits = to_bits,
   tonumb = tbl_to_number,
}



local base64 = {}

--- octet -> char encoding.
local ENCODABET = {
   'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
   'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
   'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd',
   'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
   'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
   'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7',
   '8', '9', '-', '_'
}

--- char -> octet encoding.
-- Offset by 44 (from index 1).
local DECODABET = {
   62,  0,  0, 52, 53, 54, 55, 56, 57, 58,
   59, 60, 61,  0,  0,  0,  0,  0,  0,  0,
   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,
   10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
   20, 21, 22, 23, 24, 25,  0,  0,  0,  0,
   63,  0, 26, 27, 28, 29, 30, 31, 32, 33,
   34, 35, 36, 37, 38, 39, 40, 41, 42, 43,
   44, 45, 46, 47, 48, 49, 50, 51
}

--- Encodes a string into a Base64 string.
-- The input can be any string of arbitrary bytes.
--
-- @param input The input string.
-- @return The Base64 representation of the input string.
function base64.encode(input)
   
   local bytes = { input:byte(i, #input) }
   
   local out = {}
   
   -- Go through each triplet of 3 bytes, which produce 4 octets.
   local i = 1
   while i <= #bytes - 2 do
      local buffer = 0
      
      -- Fill the buffer with the bytes, producing a 24-bit integer.
      local b = bit.blshift(bytes[i], 16)
      b = bit.band(b, 0xff0000)
      buffer = bit.bor(buffer, b)
      
      b = bit.blshift(bytes[i + 1], 8)
      b = bit.band(b, 0xff00)
      buffer = bit.bor(buffer, b)
      
      b = bit.band(bytes[i + 2], 0xff)
      buffer = bit.bor(buffer, b)
      
      -- Read out the 4 octets into the output buffer.
      b = bit.blogic_rshift(buffer, 18)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      b = bit.blogic_rshift(buffer, 12)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      b = bit.blogic_rshift(buffer, 6)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      b = bit.band(buffer, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      i = i + 3
   end
   
   -- Special case 1: One byte extra, will produce 2 octets.
   if #bytes % 3 == 1 then
      local buffer = bit.blshift(bytes[i], 16)
      buffer = bit.band(buffer, 0xff0000)
      
      local b = bit.blogic_rshift(buffer, 18)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      b = bit.blogic_rshift(buffer, 12)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      -- Special case 2: Two bytes extra, will produce 3 octets.
   elseif #bytes % 3 == 2 then
      local buffer = 0
      
      local b = bit.blshift(bytes[i], 16)
      b = bit.band(b, 0xff0000)
      buffer = bit.bor(buffer, b)
      
      b = bit.blshift(bytes[i + 1], 8)
      b = bit.band(b, 0xff00)
      buffer = bit.bor(buffer, b)
      
      b = bit.blogic_rshift(buffer, 18)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      b = bit.blogic_rshift(buffer, 12)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
      
      b = bit.blogic_rshift(buffer, 6)
      b = bit.band(b, 0x3f)
      out[#out + 1] = ENCODABET[b + 1]
   end
   
   -- Remove trailing padding characters, as it seems they are sometimes unnecessarily added 
   -- (probably because non-ASCII names take more bytes)
   local d = unpack(out)
   d = string.gsub(d, "=", "")
   
   return table.concat(out)
end

--- Decodes a Base64 string into an output string of arbitrary bytes.
-- Currently does not check the input for valid Base64, so be careful.
--
-- @param input The Base64 input to decode.
-- @return The decoded Base64 string, as a string of bytes.
function base64.decode(input)
   
   local out = {}
   
   -- Go through each group of 4 octets to obtain 3 bytes.
   local i = 1
   while i <= #input - 3 do
      local buffer = 0
      
      -- Read the 4 octets into the buffer, producing a 24-bit integer.
      local b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 18)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 12)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 6)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = input:byte(i)
      b = DECODABET[b - 44]
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      -- Append the 3 re-constructed bytes into the output buffer.
      b = bit.blogic_rshift(buffer, 16)
      b = bit.band(b, 0xff)
      out[#out + 1] = b
      
      b = bit.blogic_rshift(buffer, 8)
      b = bit.band(b, 0xff)
      out[#out + 1] = b
      
      b = bit.band(buffer, 0xff)
      out[#out + 1] = b
   end
   
   -- Special case 1: Only 2 octets remain, producing 1 byte.
   if #input % 4 == 2 then
      local buffer = 0
      
      local b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 18)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 12)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = bit.blogic_rshift(buffer, 16)
      b = bit.band(b, 0xff)
      out[#out + 1] = b
      
      -- Special case 2: Only 3 octets remain, producing 2 bytes.
   elseif #input % 4 == 3 then
      local buffer = 0
      
      local b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 18)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 12)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = input:byte(i)
      b = DECODABET[b - 44]
      b = bit.blshift(b, 6)
      buffer = bit.bor(buffer, b)
      i = i + 1
      
      b = bit.blogic_rshift(buffer, 16)
      b = bit.band(b, 0xff)
      out[#out + 1] = b
      
      b = bit.blogic_rshift(buffer, 8)
      b = bit.band(b, 0xff)
      out[#out + 1] = b
   end

   -- Remove trailing padding characters, as it seems they are sometimes unnecessarily added 
   -- (probably because non-ASCII names take more bytes)
   local d = string.char(unpack(out))
   d = string.gsub(d, "=", "")
   
   return d
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

    StaticPopup_Show(copyPayloadPopup.id, format("https://wowrep.io/team_review?payload=%s", base64.encode(p1..p2)))
end

function payload:OnReady() 
    StaticPopupDialogs[copyPayloadPopup.id] = copyPayloadPopup
end
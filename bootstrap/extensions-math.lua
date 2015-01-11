local math_ex = {}

local function basic_round(what)
	if what % 1 >= 0.5 then -- haha, the 1 was 0.5, thanks to unit testing i found it...
		return math.ceil(what)
	else
		return math.floor(what)
	end
end

function math_ex.round(what, quantum_size)
	quantum_size = quantum_size or 1
	expects("number", "number")
	
	quantum_size = 1 / quantum_size
	return basic_round(what * quantum_size) / quantum_size
end
	
function math_ex.secure_random(min, max) expects("number", "number")
	-- read from /dev/urandom
	local size = max - min
	local bits = math.ceil( math.log(size) / math.log(2) )
	local bytes = math.ceil( bits / 8 )
	
	local file = io.open("/dev/urandom", "r")

	-- meh, we don't have that device, probably on Windows
	if not file then return math.random(min, max) end
	local data = file:read(bytes)
	file:close()
	
	local result = min
	for i = bytes, 1, -1 do
		
		local byte = data:byte(i)
		result = result + bit32.lshift(byte, (i - 1) * 8)
	end

	if result > max then -- try again, i don't know how else to do this without reducing security
		return math.secure_random(min, max)
	end

	return result
end

return math_ex

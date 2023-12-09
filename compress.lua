DNF = require "DNF"

local compressres_meta = {}

function compressres_meta:__tostring()
    local res = "Compression Table:\n\n"
    for i,v in pairs(self) do
        res = res .. "'" .. string.char(i) .. "'\n" .. tostring(v) .. "\n"
    end
    return res
end

local function do_compress(str, i, j, res)
    if not res then
        res = {}
        setmetatable(res, compressres_meta)
    end
    i = i or 0
    if i >= #str then
        return res
    end
    j = j or 1 << math.ceil(math.log(#str, 2))
    if i+1 == j then
        local v = str:byte(i+1)
        if not res[v] then res[v] = DNF:new() end
        res[v]:add(i)
        return res
    end
    local res2 = {}
    res2 = do_compress(str, i, i + ((j-i) >> 1), res2)
    res2 = do_compress(str, i + ((j-i) >> 1), j, res2)
    for i,v in pairs(res2) do
        if not res[i] then res[i] = DNF:new() end
        res[i]:add(v)
    end
    return res
end

function compress(str)
    local res = {}
    setmetatable(res, compressres_meta)
    if #str == 0 then return res end
    local i = 0
    local j = 1 << math.ceil(math.log(#str, 2))
    res = do_compress(str, i, j, res)
    local res_count = 0
    local index_count = 0
    for _,v in pairs(res) do
        index_count = index_count + 1
        res_count = res_count + #v.disjs
    end
    local compr_bytecount = index_count + res_count * math.log(3 ^ math.log(#str, 2), 2) / 8
    print(string.format(
        "%d bytes compressable into %.2f bytes (%d symbols; %d disjuncts a %.2f bits)\n",
        #str, compr_bytecount, res_count, index_count,
        math.log(3 ^ math.log(#str, 2), 2)))
    return res
end

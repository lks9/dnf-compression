DNF = require "DNF"

local compressres_meta = {}

function compressres_meta:__tostring()
    local res = "Compression Table:\n\n"
    for sym,dnf in pairs(self) do
        res = res .. "'" .. string.char(sym) .. "'\n" .. tostring(dnf) .. "\n"
    end
    return res
end

local function do_compress(str, i, j, res, mask)
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
        local sym = str:byte(i+1)
        if not res[sym] then
            res[sym] = DNF:dnf()
        end
        local disj = DNF:disjunct(i, mask)
        res[sym]:add(disj)
        return res
    end
    local res2 = {}
    res2 = do_compress(str, i, i + ((j-i) >> 1), res2, mask)
    res2 = do_compress(str, i + ((j-i) >> 1), j, res2, mask)
    for sym,dnf in pairs(res2) do
        if not res[sym] then
            res[sym] = dnf
        else
            res[sym]:add(dnf)
        end
    end
    return res
end

function compress(str)
    local res = {}
    setmetatable(res, compressres_meta)
    if #str == 0 then return res end

    local i = 0
    local j = 1 << math.ceil(math.log(#str, 2))
    local mask = j - 1
    res = do_compress(str, i, j, res, mask)

    local res_count = 0
    local index_count = 0
    for _,dnf in pairs(res) do
        index_count = index_count + 1
        res_count = res_count + #dnf.disjs
    end
    local compr_bytecount = index_count + res_count * math.log(3 ^ math.log(#str, 2), 2) / 8
    print(string.format(
        "%d bytes compressable into %.2f bytes (%d symbols; %d disjuncts a %.2f bits)\n",
        #str, compr_bytecount, res_count, index_count,
        math.log(3 ^ math.log(#str, 2), 2)))
    return res
end

DNF = require "DNF"

local compressres_meta = {}

function compressres_meta:__tostring()
    local res = "Compression Table:\n\n"
    for sym,dnf in pairs(self) do
        res = res .. "'" .. string.char(sym) .. "'\n" .. tostring(dnf) .. "\n"
    end
    return res
end

local function do_compress(str, i, j, prev_res)
    if i+1 == j then
        local sym = str:byte(i+1)
        return {
            [sym] = DNF:dnf { DNF:disjunct() }
        }
    end

    local cur_bit = (j-i) >> 1
    local middle = i + cur_bit
    local res1 = do_compress(str, i, middle, prev_res)

    if middle >= #str then
        return res1
    end

    table.insert(prev_res, res1)
    local res2 = do_compress(str, middle, j, prev_res)
    table.remove(prev_res) -- removes res1

    -- add cur_bit to distinguish res1 and res2
    for sym, dnf in pairs(res1) do
        dnf:clear_bits(cur_bit)
    end
    for sym, dnf in pairs(res2) do
        dnf:set_bits(cur_bit)
        if not res1[sym] then
            res1[sym] = dnf
        else
            res1[sym]:add(dnf)
        end
    end
    return res1
end

function compress(str)
    if #str == 0 then
        local res = {}
        setmetatable(res, compressres_meta)
        return res
    end

    local i = 0
    local j = 1 << math.ceil(math.log(#str, 2))
    local res = do_compress(str, i, j, {})

    setmetatable(res, compressres_meta)

    local res_count = 0
    local index_count = 0
    for _,dnf in pairs(res) do
        index_count = index_count + 1
        res_count = res_count + #dnf.disjs
    end
    local bit_len_disj = math.log(3 ^ math.ceil(math.log(#str, 2)), 2)
    local compr_bytecount = index_count + res_count * bit_len_disj / 8
    print(string.format(
        "%d bytes compressable to roughly %.2f bytes (%d symbols; %d disjuncts a %.2f bits)\n",
        #str, compr_bytecount, index_count, res_count, bit_len_disj))
    return res
end

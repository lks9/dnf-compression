DNF = require "DNF"

local compressres_meta = {}
local perm_meta = {}

function compressres_meta:__tostring()
    local res = "Compression Table:\n\n"
    for sym,dnf in pairs(self) do
        res = res .. "'" .. string.char(sym) .. "'\n" .. tostring(dnf) .. "\n"
    end
    return res
end

function perm_meta:__tostring()
    local res = "\nPermutations: "
    for _,v in ipairs(self) do
        if v then
            res = res .. "1"
        else
            res = res .. "0"
        end
    end
    res = res .. "\n"
    return res
end

local function dnfs_for_sym(prev_res, sym)
    local dnfs = {}
    for _, res in ipairs(prev_res) do
        if res[sym] then
            table.insert(dnfs, res[sym])
        end
    end
    return dnfs
end

local function do_compress(str, i, j, prev_res, perm)
    if i+1 == j then
        local sym = str:byte(i+1)
        return {
            [sym] = DNF:dnf { DNF:disjunct() }
        }
    end

    local cur_bit = (j-i) >> 1
    local cur_mask = j - i - 1
    local middle = i + cur_bit
    local res1 = do_compress(str, i, middle, prev_res, perm)

    if middle >= #str then
        for sym, dnf in pairs(res1) do
            local dnfs_sym = dnfs_for_sym(prev_res, sym)
            --local only_mask = (1 << math.ceil(math.log(#str - i,2))) - 1
            --local free_bits = ((j-i) -1) & ~only_mask
            --dnf:nicer_bits(dnfs_sym, only_mask, free_bits)
            dnf:nicer_bits(dnfs_sym, cur_mask & ~cur_bit, cur_bit)
        end
        return res1
    end

    table.insert(prev_res, res1)
    local res2 = do_compress(str, middle, j, prev_res, perm)
    table.remove(prev_res) -- removes res1

    -- add cur_bit to distinguish res1 and res2
    local perm_desicion
    if #prev_res == 0 then
        perm_desicion = false
    else
        -- count to decide which permutation is better
        local count1, count2 = 0, 0
        for sym, dnf in pairs(res2) do
            local dnfs_sym = dnfs_for_sym(prev_res, sym)
            if res1[sym] then
                -- do not count twice
            else
                dnf:set_bits(cur_bit)
                count1 = count1 + dnf:mergecount(dnfs_sym, cur_mask)
                dnf:clear_bits(cur_bit)
                count2 = count2 + dnf:mergecount(dnfs_sym, cur_mask)
            end
        end
        for sym, dnf in pairs(res1) do
            local dnfs_sym = dnfs_for_sym(prev_res, sym)
            if res2[sym] then
                dnf2 = res2[sym]
                dnf:clear_bits(cur_bit)
                dnf2:set_bits(cur_bit)
                count1 = count1 + (dnf | dnf2):mergecount(dnfs_sym, cur_mask)
                dnf:set_bits(cur_bit)
                dnf2:clear_bits(cur_bit)
                count2 = count2 + (dnf | dnf2):mergecount(dnfs_sym, cur_mask)
            else
                dnf:clear_bits(cur_bit)
                count1 = count1 + dnf:mergecount(dnfs_sym, cur_mask)
                dnf:set_bits(cur_bit)
                count2 = count2 + dnf:mergecount(dnfs_sym, cur_mask)
            end
        end
        perm_desicion = count2 > count1
        table.insert(perm, perm_desicion)
    end
    if not perm_desicion then
        for _,dnf in pairs(res1) do
            dnf:clear_bits(cur_bit)
        end
    end
    for sym, dnf in pairs(res2) do
        if not perm_desicion then
            dnf:set_bits(cur_bit)
        end
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
    local perm = {}
    local res = do_compress(str, i, j, {}, perm)

    setmetatable(res, compressres_meta)
    setmetatable(perm, perm_meta)

    local res_count = 0
    local index_count = 0
    for _,dnf in pairs(res) do
        index_count = index_count + 1
        res_count = res_count + #dnf.disjs
    end
    local bit_len_disj = math.log(3 ^ math.ceil(math.log(#str, 2)), 2)
    local compr_bytecount = index_count + res_count * bit_len_disj / 8 + #perm / 8
    print(string.format(
        "%d bytes compressable to roughly %.2f bytes\n",
        #str, compr_bytecount
        ))
    print(string.format(
        "(%d symbols; %d disjuncts a %.2f bits; %d bits for permutation)\n",
        index_count, res_count, bit_len_disj, #perm
        ))
    return res, perm
end

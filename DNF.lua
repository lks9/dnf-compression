local DNF = {}
DNF.__index = DNF

----------------------------
-- first we define disjuncts
----------------------------

local Disjunct = {}
Disjunct.__index = Disjunct

function Disjunct:new(index, mask)
    local o = {}
    setmetatable(o, self)

    o.bits = index or 0
    o.mask = mask or 0
    return o
end

function Disjunct:copy()
    return Disjunct:new(self.bits, self.mask)
end

function Disjunct:__tostring()
    local i = 0
    local rem = self.bits
    local mask = self.mask
    local res = ""
    while true do
        if mask & 1 == 1 then
            res = (rem & 1) .. res
        else
            res = "*" .. res
        end
        mask = mask >> 1
        rem = rem >> 1
        if mask == 0 then
            return res
        end
        i = i + 1
    end
end

-- TODO both encode2 and encode4 are inefficient in run-time
function Disjunct:encode2()
    local i = 0
    local rem = self.bits
    local mask = self.mask
    local res = 0
    while true do
        if mask & 1 == 1 then
            res = res | (3^i) * (rem & 1)
        else
            res = res | (3^i) * 2
        end
        mask = mask >> 1
        rem = rem >> 1
        if mask == 0 then
            return res
        end
        i = i + 1
    end
end

function Disjunct:encode4()
    local i = 0
    local rem = self.bits
    local mask = self.mask
    local res = 0
    while true do
        if mask & 1 == 1 then
            res = res | (1<<(2*i)) * (rem & 1)
        else
            res = res | (1<<(2*i)) * 2
        end
        mask = mask >> 1
        rem = rem >> 1
        if mask == 0 then
            return res
        end
        i = i + 1
    end
end

function Disjunct:tolist()
    local i = 0
    -- needed since the following assumes bit 0 for mask bit 1
    self.bits = self.bits & self.mask
    local mask = self.mask
    local list = {self.bits}
    while not (mask == 0) do
        if mask & 1 == 0 then
            for k = 1, #list do
                -- this keeps the list sorted
                table.insert(list, list[k] | (1 << i))
            end
        end
        mask = mask >> 1
        i = i + 1
    end
    return list
end

function Disjunct:mergeable(to_merge, only_mask)
    local merge_bits
    if type(to_merge) == "number" then
        merge_bits = to_merge
    elseif getmetatable(to_merge) == Disjunct then
        if not (self.mask & only_mask == to_merge.mask & only_mask) then
            -- not mergeable, not the same mask!
            return false
        end
        merge_bits = to_merge.bits
    else
        for _,v in pairs(to_merge) do
            if self:mergeable(v, only_mask) then
                return true
            end
        end
        return false
    end
    local diff = (self.bits ~ merge_bits) & self.mask & only_mask
    return diff == 0
end

-- prepare for merge
-- sets free bits to whatever
-- returns true if successful
function Disjunct:nicer_bits(to_merge, only_mask, free_bits)
    if getmetatable(to_merge) == Disjunct then
        local mergeable = self:mergeable(to_merge, only_mask)
        if not mergeable then
            return false
        end
        self.bits = self.bits & ~(~to_merge.bits & free_bits)
        self.bits = self.bits |  ( to_merge.bits & free_bits)
        self.mask = self.mask & ~(~to_merge.mask & free_bits)
        self.mask = self.mask |  ( to_merge.mask & free_bits)
        return true
        --if self.mask == to_merge.mask then
        --    return true
        --else
        --    -- possibly there is another way to make it even nicer
        --    return false
        --end
    else
        for _,v in pairs(to_merge) do
            if self:nicer_bits(v, only_mask, free_bits) then
                return true
            end
        end
        return false
    end
end

function Disjunct:addable(to_add)
    local diff
    if type(to_add) == "number" then
        diff = (self.bits ~ to_add) & self.mask
    elseif getmetatable(to_add) == Disjunct then
        if self.mask == to_add.mask then
            diff = (self.bits ~ to_add.bits) & self.mask
        else
            return false
        end
    else
        return false
    end
    if (diff & (diff - 1)) == 0 then
        -- diff is really just one or zero bits
        return true
    else
        return false
    end
end

-- gives incorrect result if not addable
function Disjunct:add(to_add)
    if type(to_add) == "number" then
        self.mask = self.mask & ~(self.bits ~ to_add)
    elseif getmetatable(to_add) == Disjunct then
        self.mask = self.mask & ~(self.bits ~ to_add.bits)
    end
end

function Disjunct:__bor(to_add)
    -- check if it is really just one or zero bits
    if self:addable(to_add) then
        local new = self:copy()
        new:add(to_add)
        return new
    elseif to_add:addable(self) then
        local new = to_add:copy()
        new:add(self)
        return new
    else
        local dnf = DNF:dnf()
        dnf:dump_add(self)
        dnf:dump_add(to_add)
        return dnf
    end
end

function Disjunct:set_bits(bits)
    self.mask = self.mask | bits
    self.bits = self.bits | bits
end

function Disjunct:clear_bits(bits)
    self.mask = self.mask | bits
    self.bits = self.bits & ~bits
end

function Disjunct:star_bits(bits)
    self.mask = self.mask & ~bits
end

---------------------
-- code for DNFs
---------------------


-- same implementation for DNF and Disjunct
DNF.__bor = Disjunct.__bor

function DNF:dnf(disjs)
    o = {}
    setmetatable(o, self)

    o.disjs = disjs or {}
    return o
end

function DNF:disjunct(bits, mask)
    return Disjunct:new(bits, mask)
end

-- for convenience, the empty dnf
-- should not be modified
-- (although nothing bad happens to the current module if modified)
DNF.empty = DNF:dnf()

function DNF:copy()
    local disjs = {}
    for i,v in ipairs(self.disjs) do
        disjs[i] = v:copy()
    end
    return DNF:dnf(disjs)
end

function DNF:addable(to_add)
    return true
end

function DNF:dump_add(to_add)
    local disj
    if type(to_add) == "number" then
        disj = Disjunct:new(to_add)
    else
        disj = to_add
    end
    table.insert(self.disjs, disj)
end

function DNF:add(to_add)
    if type(to_add) == "number" or getmetatable(to_add) == Disjunct then
        for _,v in ipairs(self.disjs) do
            if v:addable(to_add) then
                return v:add(to_add)
            end
        end
        -- not addable
        return self:dump_add(to_add)
    elseif getmetatable(to_add) == DNF then
        -- not most compact in all cases
        -- but sufficient for us
        for _,v in ipairs(to_add.disjs) do
            self:add(v)
        end
    else
        error("only numbers, disjuncts and DNFs can be added")
    end
end

-- does not add but counts the number of new disjuncts that would be added
function DNF:addcount(to_add)
    if type(to_add) == "number" or getmetatable(to_add) == Disjunct then
        for _,v in ipairs(self.disjs) do
            if v:addable(to_add) then
                return 0
            end
        end
        -- not addable, new disjunct
        return 1
    elseif getmetatable(to_add) == DNF then
        local res = 0
        for _,disj in ipairs(to_add.disjs) do
            res = res + self:addcount(disj)
        end
        return res
    else
        error("only numbers, disjuncts and DNFs can be added")
    end
end

function DNF:tolist()
    local res = {}
    for _,disj in ipairs(self.disjs) do
        for _,bits in ipairs(disj:tolist()) do
            table.insert(res, bits)
        end
    end
    -- nicer to work with sorted lists
    table.sort(res)
    return res
end

function DNF:__tostring()
    local ss = {}
    local len = 0
    local res = ""
    for _, disj in ipairs(self.disjs) do
        local s = tostring(disj)
        len = math.max(len, #s)
        table.insert(ss, s)
    end
    for _,s in ipairs(ss) do
        res = res .. string.rep(" ", len - #s) .. s .. "\n"
    end
    return res
end

function DNF:set_bits(bits)
    for _, disj in ipairs(self.disjs) do
        disj:set_bits(bits)
    end
end

function DNF:clear_bits(bits)
    for _, disj in ipairs(self.disjs) do
        disj:clear_bits(bits)
    end
end

function DNF:star_bits(bits)
    for _, disj in ipairs(self.disjs) do
        disj:star_bits(bits)
    end
end

function DNF:nicer_bits(list, only_mask, bits)
    for _, disj in ipairs(self.disjs) do
        disj:nicer_bits(list, only_mask, bits)
    end
end

function DNF:mergecount(list, only_mask)
    local count = 0
    for _, disj in ipairs(self.disjs) do
        if disj:mergeable(list, only_mask) then
            count = count + 1
        end
    end
    return count
end

-- end of module DNF
return DNF

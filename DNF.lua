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

    o.bits = assert(index)
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
            res = "*" .. res
        else
            res = (rem & 1) .. res
        end
        mask = mask >> 1
        rem = rem >> 1
        if rem == 0 and mask == 0 then
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
            res = res | (3^i) * 2
        else
            res = res | (3^i) * (rem & 1)
        end
        mask = mask >> 1
        rem = rem >> 1
        if rem == 0 and mask == 0 then
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
            res = res | (1<<(2*i)) * 2
        else
            res = res | (1<<(2*i)) * (rem & 1)
        end
        mask = mask >> 1
        rem = rem >> 1
        if rem == 0 and mask == 0 then
            return res
        end
        i = i + 1
    end
end

function Disjunct:tolist()
    local i = 0
    -- needed since the following assumes bit 0 for mask bit 1
    self.bits = self.bits & ~self.mask
    local mask = self.mask
    local list = {self.bits}
    while not (mask == 0) do
        if mask & 1 == 1 then
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

function Disjunct:addable(to_add)
    local diff
    if type(to_add) == "number" then
        if self.mask == 0 then
            diff = self.bits ~ to_add
        else
            return false
        end
    elseif getmetatable(to_add) == Disjunct then
        if self.mask == to_add.mask then
            diff = (self.bits ~ to_add.bits) & ~self.mask
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
        self.mask = self.mask | (self.bits ~ to_add)
    elseif getmetatable(to_add) == Disjunct then
        self.mask = self.mask | (self.bits ~ to_add.bits)
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
        local dnf = DNF:new()
        dnf:dump_add(self)
        dnf:dump_add(to_add)
        return dnf
    end
end

---------------------
-- code for DNFs
---------------------


-- same implementation for DNF and Disjunct
DNF.__bor = Disjunct.__bor

function DNF:new(disjs)
    o = {}
    setmetatable(o, self)

    o.disjs = disjs or {}
    return o
end

-- for convenience, the empty dnf
-- should not be modified
-- (although nothing bad happens to the current module if modified)
DNF.empty = DNF:new()

function DNF:copy()
    local disjs = {}
    for i,v in ipairs(self.disjs) do
        disjs[i] = v:copy()
    end
    return DNF:new(disjs)
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
        for _,v in ipairs(to_add.disjs) do
            res = res + self:addcount(v)
        end
        return res
    else
        error("only numbers, disjuncts and DNFs can be added")
    end
end

function DNF:tolist()
    local res = {}
    for _,v in ipairs(self.disjs) do
        for _,bits in ipairs(v:tolist()) do
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
    for _,disj in ipairs(self.disjs) do
        local s = tostring(disj)
        len = math.max(len, #s)
        table.insert(ss, s)
    end
    for _,s in ipairs(ss) do
        res = res .. string.rep(" ", len - #s) .. s .. "\n"
    end
    return res
end

return DNF

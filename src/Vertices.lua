--!optimize 2
-- CONSTANTS

local PI2 = math.pi * 2
local PHI = (1 + math.sqrt(5)) / 2

local RIGHT = Vector3.new(1, 0, 0)
local UP = Vector3.new(0, 1, 0)
local LEFT = Vector3.new(-1, 0, 0)

local CORNERS = {
	Vector3.new(1, 1, 1);
	Vector3.new(-1, 1, 1);
	Vector3.new(-1, 1, -1);
	Vector3.new(1, 1, -1);
	Vector3.new(1, -1, 1);
	Vector3.new(-1, -1, 1);
	Vector3.new(-1, -1, -1);
	Vector3.new(1, -1, -1);
}

-- VERTICE INDEX ARRAYS

local BLOCK = {1, 2, 3, 4, 5, 6, 7, 8}
local WEDGE = {1, 2, 5, 6, 7, 8}
local CORNERWEDGE = {4, 5, 6, 7, 8}

-- VERTICE FUNCTIONS

local function fromIndexArray(array)
	local output = table.create(#array)
	for index, value in array do
		output[index] = CORNERS[value]
	end

	return output
end

local function cylinder(n)
	local output = table.create(n * 2)
	local arc = PI2 / n
	for i = 1, n do
		local vi = CFrame.fromAxisAngle(RIGHT, i * arc) * UP
		output[i] = RIGHT + vi
		output[n + i] = LEFT + vi
	end

	return output
end

local function icoSphere(n)
	local verts = {
		Vector3.new(-1, PHI, 0);
		Vector3.new(1, PHI, 0);
		Vector3.new(-1, -PHI, 0);
		Vector3.new(1, -PHI, 0);

		Vector3.new(0, -1, PHI);
		Vector3.new(0, 1, PHI);
		Vector3.new(0, -1, -PHI);
		Vector3.new(0, 1, -PHI);

		Vector3.new(PHI, 0, -1);
		Vector3.new(PHI, 0, 1);
		Vector3.new(-PHI, 0, -1);
		Vector3.new(-PHI, 0, 1);
	}

	-- stylua: ignore
	local indices = {
		1, 12, 6,
		1, 6, 2,
		1, 2, 8,
		1, 8, 11,
		1, 11, 12,

		2, 6, 10,
		6, 12, 5,
		12, 11, 3,
		11, 8, 7,
		8, 2, 9,

		4, 10, 5,
		4, 5, 3,
		4, 3, 7,
		4, 7, 9,
		4, 9, 10,

		5, 10, 6,
		3, 5, 12,
		7, 3, 11,
		9, 7, 8,
		10, 9, 2
	}

	local splits = {}

	local function split(i, j)
		local key = if i < j then i .. "," .. j else j .. "," .. i

		if not splits[key] then
			table.insert(verts, (verts[i] + verts[j]) / 2)
			splits[key] = #verts
		end

		return splits[key]
	end

	for _ = 1, n do
		for i = #indices, 1, -3 do
			local v1, v2, v3 = indices[i - 2], indices[i - 1], indices[i]
			local a = split(v1, v2)
			local b = split(v2, v3)
			local c = split(v3, v1)

			table.insert(indices, v1)
			table.insert(indices, a)
			table.insert(indices, c)

			table.insert(indices, v2)
			table.insert(indices, b)
			table.insert(indices, a)

			table.insert(indices, v3)
			table.insert(indices, c)
			table.insert(indices, b)

			table.insert(indices, a)
			table.insert(indices, b)
			table.insert(indices, c)

			table.remove(indices, i)
			table.remove(indices, i - 1)
			table.remove(indices, i - 2)
		end
	end

	-- normalize
	for index, value in verts do
		verts[index] = value.Unit
	end

	return verts
end

-- Useful functions

local function vertShape(cf, size2, array): {Vector3}
	local output = table.create(#array)
	for index, value in array do
		output[index] = cf:PointToWorldSpace(value * size2)
	end

	return output
end

local function getCentroidFromSet(set)
	local sum = set[1]
	for _ = 2, #set do
		sum += set[2]
	end

	return sum / #set
end

local function classify(part): "Block" | "Cylinder" | "Ball" | "Wedge" | "CornerWedge"
	if part.ClassName == "Part" then
		if part.Shape == Enum.PartType.Block then
			return "Block"
		elseif part.Shape == Enum.PartType.Cylinder then
			return "Cylinder"
		elseif part.Shape == Enum.PartType.Ball then
			return "Ball"
		else
			return "Block"
		end
	elseif part:IsA("WedgePart") then
		return "Wedge"
	elseif part:IsA("CornerWedgePart") then
		return "CornerWedge"
	elseif part:IsA("BasePart") then -- mesh, CSG, truss, etc... just use block
		return "Block"
	else
		return "Block"
	end
end

local BLOCK_ARRAY = fromIndexArray(BLOCK)
local WEDGE_ARRAY = fromIndexArray(WEDGE)
local CORNERWEDGE_ARRAY = fromIndexArray(CORNERWEDGE)
local CYLINDER_ARRAY = cylinder(20)
local SPHERE_ARRAY = icoSphere(2)

local Vertices = {
	Block = function(cf: CFrame, size2: Vector3): {Vector3}
		return vertShape(cf, size2, BLOCK_ARRAY)
	end;

	Wedge = function(cf: CFrame, size2: Vector3): {Vector3}
		return vertShape(cf, size2, WEDGE_ARRAY)
	end;

	CornerWedge = function(cf: CFrame, size2: Vector3): {Vector3}
		return vertShape(cf, size2, CORNERWEDGE_ARRAY)
	end;

	Cylinder = function(cf: CFrame, size2: Vector3): {Vector3}
		return vertShape(cf, size2, CYLINDER_ARRAY)
	end;

	Ball = function(cf: CFrame, size2: Vector3): {Vector3}
		return vertShape(cf, size2, SPHERE_ARRAY)
	end;

	GetCentroid = getCentroidFromSet;
	Classify = classify;
}

table.freeze(Vertices)
return Vertices

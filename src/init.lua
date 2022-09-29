--!optimize 2
--[[

This is a Rotated Region3 Class that behaves much the same as the standard Region3 class expect that it allows
for both rotated regions and also a varying array of shapes.

API:

Constructors:
	RotatedRegion3.new(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to
		> the corners like a block part.
	RotatedRegion3.Block(CFrame cframe, Vector3 size)
		> This is the exact same as the region.new constructor, but has a different name.
	RotatedRegion3.Wedge(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to
		> the corners like a wedge part.
	RotatedRegion3.CornerWedge(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to
		> the corners like a cornerWedge part.
	RotatedRegion3.Cylinder(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to
		> the corners like a cylinder part.
	RotatedRegion3.Ball(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to
		> the corners like a ball part.
	RotatedRegion3.FromPart(part)
		> Creates a region from a part in the game. It can be used on any base part, but the region
		> will treat unknown shapes (meshes, unions, etc) as block shapes.

Methods:
	RotatedRegion3:CastPoint(Vector3 point)
		> returns true or false if the point is within the RotatedRegion3 object
	RotatedRegion3:CastPart(BasePart part)
		> returns true or false if the part is withing the RotatedRegion3 object
	RotatedRegion3:FindPartsInRegion3(Instance ignore, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of or actually are the [ignore] instance will be ignored
	RotatedRegion3:FindPartsInRegion3WithIgnoreList(Instance Array ignore, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of the [ignore array] or actually are the [ignore array] instances will be ignored
	RotatedRegion3:FindPartsInRegion3WithWhiteList(Instance Array whiteList, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of the [whiteList array] or actually are the [whiteList array] instances are all that will be checked
	RotatedRegion3:Cast(Instance or Instance Array ignore, Integer maxParts)
		> Same as the `:FindPartsInRegion3WithIgnoreList` method, but will check if the ignore argument is an array or single instance

Properties:
	RotatedRegion3.CFrame
		> cframe that represents the center of the region
	RotatedRegion3.Size
		> vector3 that represents the size of the region
	RotatedRegion3.Shape
		> string that represents the shape type of the RotatedRegion3 object
	RotatedRegion3.Set
		> array of vector3 that are passed to the support function
	RotatedRegion3.Support
		> function that is used for support in the GJK algorithm
	RotatedRegion3.Centroid
		> vector3 that represents the center of the set, again used for the GJK algorithm
	RotatedRegion3.AlignedRegion3
		> standard region3 that represents the world bounding box of the RotatedRegion3 object

Note: I haven't actually done anything to enforce this, but you should treat all these properties as read only

Enjoy!
- EgoMoose

--]]

local Workspace = game:GetService("Workspace")

local IsColliding = require(script:WaitForChild("IsColliding"))
local Supports = require(script:WaitForChild("Supports"))
local Vertices = require(script:WaitForChild("Vertices"))

--[=[
	@class RotatedRegion3
]=]
local RotatedRegion3 = {}
RotatedRegion3.ClassName = "RotatedRegion3"
RotatedRegion3.__index = RotatedRegion3

--[=[
	The RotatedRegion3's shape.
	@type ShapeType "Ball" | "Block" | "CornerWedge" | "Cylinder" | "Wedge"
	@within RotatedRegion3
]=]

--[=[
	A support function.
	@type SupportFunction (Set: {Vector3}, Direction: Vector3) -> Vector3
	@within RotatedRegion3
]=]

--[=[
	A CFrame that represents the center of the region.
	@prop CFrame CFrame
	@within RotatedRegion3
]=]

--[=[
	A Vector3 that represents the size of the region.
	@prop Size Vector3
	@within RotatedRegion3
]=]

--[=[
	A string that represents the shape type of the RotatedRegion3 object.
	@prop Shape ShapeType
	@within RotatedRegion3
]=]

--[=[
	An array of Vector3s that are passed to the support function.
	@prop Set {Vector3}
	@within RotatedRegion3
]=]

--[=[
	A function that is used for support in the GJK algorithm.
	@prop Support SupportFunction
	@within RotatedRegion3
]=]

--[=[
	A Vector3 that represents the center of the set, again used for the GJK algorithm.
	@prop Centroid Vector3
	@within RotatedRegion3
]=]

--[=[
	A standard Region3 that represents the world bounding box of the RotatedRegion3 object.
	@prop AlignedRegion3 Region3
	@within RotatedRegion3
]=]

-- Private functions

local function GetCorners(CoordinateFrame: CFrame, Size2: Vector3)
	local X, Y, Z = Size2.X, Size2.Y, Size2.Z
	return {
		CoordinateFrame:PointToWorldSpace(Vector3.new(-X, Y, Z));
		CoordinateFrame:PointToWorldSpace(Vector3.new(-X, -Y, Z));
		CoordinateFrame:PointToWorldSpace(-Size2);
		CoordinateFrame:PointToWorldSpace(Vector3.new(X, -Y, -Z));
		CoordinateFrame:PointToWorldSpace(Vector3.new(X, Y, -Z));
		CoordinateFrame:PointToWorldSpace(Size2);
		CoordinateFrame:PointToWorldSpace(Vector3.new(X, -Y, Z));
		CoordinateFrame:PointToWorldSpace(Vector3.new(-X, Y, -Z));
	}
end

local MAX_VECTOR3 = Vector3.one * -math.huge
local MIN_VECTOR3 = Vector3.one * math.huge

local function WorldBoundingBox(Set: {Vector3}): (Vector3, Vector3)
	return MIN_VECTOR3:Min(table.unpack(Set)), MAX_VECTOR3:Max(table.unpack(Set))
end

-- Public Constructors

--[=[
	Creates a region from a CFrame which acts as the center of the region and size
	which extends to the corners like a block part.

	@param CoordinateFrame CFrame -- The center of the region.
	@param Size Vector3 -- The size of the region.

	@return RotatedRegion3
]=]
function RotatedRegion3.new(CoordinateFrame: CFrame, Size: Vector3)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = CoordinateFrame
	self.Size = Size
	self.Shape = "Block"

	local Set = Vertices.Block(CoordinateFrame, Size / 2)

	self.Set = Set
	self.Support = Supports.PointCloud
	self.Centroid = CoordinateFrame.Position

	self.AlignedRegion3 = Region3.new(WorldBoundingBox(Set))

	return self
end

--[=[
	Creates a region from a CFrame which acts as the center of the region and size
	which extends to the corners like a block part.

	:::info
	This is the exact same as the [`RotatedRegion3.new`](/api/RotatedRegion3#new) constructor.
	:::

	@param CoordinateFrame CFrame -- The center of the region.
	@param Size Vector3 -- The size of the region.

	@return RotatedRegion3
]=]
function RotatedRegion3.Block(CoordinateFrame: CFrame, Size: Vector3)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = CoordinateFrame
	self.Size = Size
	self.Shape = "Block"

	local Set = Vertices.Block(CoordinateFrame, Size / 2)

	self.Set = Set
	self.Support = Supports.PointCloud
	self.Centroid = CoordinateFrame.Position

	self.AlignedRegion3 = Region3.new(WorldBoundingBox(Set))

	return self
end

--[=[
	Creates a region from a CFrame which acts as the center of the region and size
	which extends to the corners like a [WedgePart].

	@param CoordinateFrame CFrame -- The center of the region.
	@param Size Vector3 -- The size of the region.

	@return RotatedRegion3
]=]
function RotatedRegion3.Wedge(CoordinateFrame: CFrame, Size: Vector3)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = CoordinateFrame
	self.Size = Size
	self.Shape = "Wedge"

	local Set = Vertices.Wedge(CoordinateFrame, Size / 2)

	self.Set = Set
	self.Support = Supports.PointCloud
	self.Centroid = Vertices.GetCentroid(Set)

	self.AlignedRegion3 = Region3.new(WorldBoundingBox(Set))

	return self
end

--[=[
	Creates a region from a CFrame which acts as the center of the region and size
	which extends to the corners like a [CornerWedgePart].

	@param CoordinateFrame CFrame -- The center of the region.
	@param Size Vector3 -- The size of the region.

	@return RotatedRegion3
]=]
function RotatedRegion3.CornerWedge(CoordinateFrame: CFrame, Size: Vector3)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = CoordinateFrame
	self.Size = Size
	self.Shape = "CornerWedge"

	local Set = Vertices.CornerWedge(CoordinateFrame, Size / 2)
	self.Set = Set
	self.Support = Supports.PointCloud
	self.Centroid = Vertices.GetCentroid(Set)

	self.AlignedRegion3 = Region3.new(WorldBoundingBox(Set))

	return self
end

--[=[
	Creates a region from a CFrame which acts as the center of the region and size
	which extends to the corners like a cylinder part.

	@param CoordinateFrame CFrame -- The center of the region.
	@param Size Vector3 -- The size of the region.

	@return RotatedRegion3
]=]
function RotatedRegion3.Cylinder(CoordinateFrame: CFrame, Size: Vector3)
	local self = setmetatable({}, RotatedRegion3)

	local HalfSize = Size / 2

	self.CFrame = CoordinateFrame
	self.Size = Size
	self.Shape = "Cylinder"

	self.Set = {CoordinateFrame, HalfSize}
	self.Support = Supports.Cylinder
	self.Centroid = CoordinateFrame.Position

	self.AlignedRegion3 = Region3.new(WorldBoundingBox(GetCorners(CoordinateFrame, HalfSize)))

	return self
end

--[=[
	Creates a region from a CFrame which acts as the center of the region and size
	which extends to the corners like a ball part.

	@param CoordinateFrame CFrame -- The center of the region.
	@param Size Vector3 -- The size of the region.

	@return RotatedRegion3
]=]
function RotatedRegion3.Ball(CoordinateFrame: CFrame, Size: Vector3)
	local self = setmetatable({}, RotatedRegion3)

	local HalfSize = Size / 2

	self.CFrame = CoordinateFrame
	self.Size = Size
	self.Shape = "Ball"

	self.Set = {CoordinateFrame, HalfSize}
	self.Support = Supports.Ellipsoid
	self.Centroid = CoordinateFrame.Position

	self.AlignedRegion3 = Region3.new(WorldBoundingBox(GetCorners(CoordinateFrame, HalfSize)))

	return self
end

--[=[
	Creates a region from a part in the game. It can be used on any base part, but the region
	will treat unknown shapes (meshes, unions, etc) as block shapes.

	@param BasePart BasePart -- The part to create the region from.
	@return RotatedRegion3
]=]
function RotatedRegion3.FromPart(BasePart: BasePart): RotatedRegion3
	return RotatedRegion3[Vertices.Classify(BasePart)](BasePart.CFrame, BasePart.Size)
end

-- Public Constructors

--[=[
	Returns true or false if the point is within the RotatedRegion3 object.
	@param Point Vector3 -- The point to cast.
	@return boolean
]=]
function RotatedRegion3:CastPoint(Point: Vector3)
	return IsColliding(self.Set, {Point}, self.Centroid, Point, self.Support, Supports.PointCloud)
end

--[=[
	Returns true or false if the part is within the RotatedRegion3 object.
	@param BasePart BasePart -- The BasePart to cast.
	@return boolean
]=]
function RotatedRegion3:CastPart(BasePart: BasePart)
	local PartRegion = RotatedRegion3.FromPart(BasePart)
	return IsColliding(self.Set, PartRegion.Set, self.Centroid, PartRegion.Centroid, self.Support, PartRegion.Support)
end

--[=[
	Returns array of parts in the RotatedRegion3 object. Will return
	a maximum number of parts in the array. Parts that either are are
	descendants of or are the `IgnoreDescendantsInstance` will be ignored.

	:::info
	You should instead use [RotatedRegion3.GetPartsInRegion](/api/RotatedRegion3#GetPartsInRegion) instead.
	It's slower but it's using a newer API.
	:::

	@param IgnoreDescendantsInstance Instance? -- The instance to ignore descendants of.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:FindPartsInRegion3(IgnoreDescendantsInstance: Instance?, MaxParts: number?): {BasePart}
	local Parts = {}
	local Length = 0

	local SelfCentroid = self.Centroid
	local SelfSet = self.Set
	local SelfSupport = self.Support

	for _, Part in Workspace:FindPartsInRegion3(self.AlignedRegion3, IgnoreDescendantsInstance, MaxParts or 20) do
		local PartRegion = RotatedRegion3[Vertices.Classify(Part)](Part.CFrame, Part.Size)
		if IsColliding(SelfSet, PartRegion.Set, SelfCentroid, PartRegion.Centroid, SelfSupport, PartRegion.Support) then
			Length += 1
			Parts[Length] = Part
		end
	end

	return Parts
end

--[=[
	Returns array of parts in the RotatedRegion3 object. Will return
	a maximum number of parts in the array. Parts that either are descendants
	of the IgnoreList or are actually in the IgnoreList will be ignored.

	:::info
	You should instead use [RotatedRegion3.GetPartsInRegionWithIgnoreList](/api/RotatedRegion3#GetPartsInRegionWithIgnoreList) instead.
	It's slower but it's using a newer API.
	:::

	@param IgnoreList {Instance}? -- The instances to ignore.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:FindPartsInRegion3WithIgnoreList(IgnoreList: {Instance}?, MaxParts: number?): {BasePart}
	local TrueIgnoreList = if IgnoreList then IgnoreList else {}
	local Parts = {}
	local Length = 0

	local SelfCentroid = self.Centroid
	local SelfSet = self.Set
	local SelfSupport = self.Support

	for _, Part in Workspace:FindPartsInRegion3WithIgnoreList(self.AlignedRegion3, TrueIgnoreList, MaxParts or 20) do
		local PartRegion = RotatedRegion3[Vertices.Classify(Part)](Part.CFrame, Part.Size)
		if IsColliding(SelfSet, PartRegion.Set, SelfCentroid, PartRegion.Centroid, SelfSupport, PartRegion.Support) then
			Length += 1
			Parts[Length] = Part
		end
	end

	return Parts
end

--[=[
	Returns array of parts in the RotatedRegion3 object. Will return
	a maximum number of parts in the array. Parts that are not either descendants
	of the Whitelist or are actually in the Whitelist will be ignored.

	:::info
	You should instead use [RotatedRegion3.GetPartsInRegionWithWhitelist](/api/RotatedRegion3#GetPartsInRegionWithWhitelist) instead.
	It's slower but it's using a newer API.
	:::

	@param Whitelist {Instance}? -- The instances to allow.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:FindPartsInRegion3WithWhiteList(Whitelist: {Instance}?, MaxParts: number?)
	local TrueWhitelist = if Whitelist then Whitelist else {}
	local Parts = {}
	local Length = 0

	local SelfCentroid = self.Centroid
	local SelfSet = self.Set
	local SelfSupport = self.Support

	for _, Part in Workspace:FindPartsInRegion3WithWhiteList(self.AlignedRegion3, TrueWhitelist, MaxParts or 20) do
		local PartRegion = RotatedRegion3[Vertices.Classify(Part)](Part.CFrame, Part.Size)
		if IsColliding(SelfSet, PartRegion.Set, SelfCentroid, PartRegion.Centroid, SelfSupport, PartRegion.Support) then
			Length += 1
			Parts[Length] = Part
		end
	end

	return Parts
end

--[=[
	Returns array of parts in the RotatedRegion3 object. Will return
	a maximum number of parts in the array. Parts that either are are
	descendants of or are the `IgnoreDescendantsInstance` will be ignored.

	Uses [Workspace.GetPartBoundsInBox] instead of [Workspace.FindPartsInRegion3].

	@param IgnoreDescendantsInstance Instance? -- The instance to ignore descendants of.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:GetPartsInRegion(IgnoreDescendantsInstance: Instance?, MaxParts: number?): {BasePart}
	local Parameters = OverlapParams.new()
	Parameters.MaxParts = MaxParts or 20

	if IgnoreDescendantsInstance then
		local IgnoreList = IgnoreDescendantsInstance:GetDescendants()
		table.insert(IgnoreList, IgnoreDescendantsInstance)
		Parameters.FilterDescendantsInstances = IgnoreList
		Parameters.FilterType = Enum.RaycastFilterType.Blacklist
	end

	local Parts = {}
	local Length = 0
	local AlignedRegion3: Region3 = self.AlignedRegion3

	local SelfCentroid = self.Centroid
	local SelfSet = self.Set
	local SelfSupport = self.Support

	for _, Part in Workspace:GetPartBoundsInBox(AlignedRegion3.CFrame, AlignedRegion3.Size, Parameters) do
		local PartRegion = RotatedRegion3[Vertices.Classify(Part)](Part.CFrame, Part.Size)
		if IsColliding(SelfSet, PartRegion.Set, SelfCentroid, PartRegion.Centroid, SelfSupport, PartRegion.Support) then
			Length += 1
			Parts[Length] = Part
		end
	end

	return Parts
end

--[=[
	Returns array of parts in the RotatedRegion3 object. Will return
	a maximum number of parts in the array. Parts that either are descendants
	of the IgnoreList or are actually in the IgnoreList will be ignored.

	Uses [Workspace.GetPartBoundsInBox] instead of [Workspace.FindPartsInRegion3].

	@param IgnoreList {Instance}? -- The instances to ignore.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:GetPartsInRegionWithIgnoreList(IgnoreList: {Instance}?, MaxParts: number?): {BasePart}
	local Parameters = OverlapParams.new()
	Parameters.FilterDescendantsInstances = IgnoreList or {}
	Parameters.FilterType = Enum.RaycastFilterType.Blacklist
	Parameters.MaxParts = MaxParts or 20

	local Parts = {}
	local Length = 0
	local AlignedRegion3: Region3 = self.AlignedRegion3

	local SelfCentroid = self.Centroid
	local SelfSet = self.Set
	local SelfSupport = self.Support

	for _, Part in Workspace:GetPartBoundsInBox(AlignedRegion3.CFrame, AlignedRegion3.Size, Parameters) do
		local PartRegion = RotatedRegion3[Vertices.Classify(Part)](Part.CFrame, Part.Size)
		if IsColliding(SelfSet, PartRegion.Set, SelfCentroid, PartRegion.Centroid, SelfSupport, PartRegion.Support) then
			Length += 1
			Parts[Length] = Part
		end
	end

	return Parts
end

--[=[
	Returns array of parts in the RotatedRegion3 object. Will return
	a maximum number of parts in the array. Parts that are not either descendants
	of the Whitelist or are actually in the Whitelist will be ignored.

	Uses [Workspace.GetPartBoundsInBox] instead of [Workspace.FindPartsInRegion3].

	@param Whitelist {Instance}? -- The instances to allow.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:GetPartsInRegionWithWhiteList(Whitelist: {Instance}?, MaxParts: number?): {BasePart}
	local Parameters = OverlapParams.new()
	Parameters.FilterDescendantsInstances = Whitelist or {}
	Parameters.FilterType = Enum.RaycastFilterType.Whitelist
	Parameters.MaxParts = MaxParts or 20

	local Parts = {}
	local Length = 0
	local AlignedRegion3: Region3 = self.AlignedRegion3

	local SelfCentroid = self.Centroid
	local SelfSet = self.Set
	local SelfSupport = self.Support

	for _, Part in Workspace:GetPartBoundsInBox(AlignedRegion3.CFrame, AlignedRegion3.Size, Parameters) do
		local PartRegion = RotatedRegion3[Vertices.Classify(Part)](Part.CFrame, Part.Size)
		if IsColliding(SelfSet, PartRegion.Set, SelfCentroid, PartRegion.Centroid, SelfSupport, PartRegion.Support) then
			Length += 1
			Parts[Length] = Part
		end
	end

	return Parts
end

--[=[
	Same as the [RotatedRegion3.FindPartsInRegion3WithIgnoreList](/api/RotatedRegion3#FindPartsInRegion3WithIgnoreList)
	method, but will check if the ignore argument is an array or single instance.

	:::info
	You should instead use [RotatedRegion3.Cast](/api/RotatedRegion3#Cast) instead.
	It's slower but it's using a newer API.
	:::

	@param IgnoreList Instance | {Instance} -- The instance(s) to ignore.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:Cast(IgnoreList: Instance | {Instance}, MaxParts: number?): {BasePart}
	return self:FindPartsInRegion3WithIgnoreList(type(IgnoreList) == "table" and IgnoreList or {IgnoreList}, MaxParts)
end

--[=[
	Same as the [RotatedRegion3.GetPartsInRegionWithIgnoreList](/api/RotatedRegion3#GetPartsInRegionWithIgnoreList)
	method, but will check if the ignore argument is an array or single instance.

	@param IgnoreList Instance | {Instance} -- The instance(s) to ignore.
	@param MaxParts number? -- The maximum number of parts to return. Defaults to 20.

	@return {BasePart}
]=]
function RotatedRegion3:CastInBox(IgnoreList: Instance | {Instance}, MaxParts: number?): {BasePart}
	return self:GetPartsInRegionWithIgnoreList(type(IgnoreList) == "table" and IgnoreList or {IgnoreList}, MaxParts)
end

function RotatedRegion3:__tostring()
	return "RotatedRegion3"
end

export type RotatedRegion3 = typeof(RotatedRegion3.new(CFrame.identity, Vector3.one))
table.freeze(RotatedRegion3)
return RotatedRegion3

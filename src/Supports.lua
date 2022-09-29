--!optimize 2
local Supports = {}

local RIGHT = Vector3.xAxis
local ZERO = Vector3.zero

local function RayPlane(Position: Vector3, Vector: Vector3, Size: Vector3, Normal: Vector3)
	local Radius = Position - Size
	local ValueT = -Radius:Dot(Normal) / Vector:Dot(Normal)
	return Position + ValueT * Vector, ValueT
end

function Supports.PointCloud(Set: {Vector3}, Direction: Vector3)
	local Max = Set[1]
	local MaxDot = Max:Dot(Direction)

	for Index = 2, #Set do
		local Dot = Set[Index]:Dot(Direction)
		if Dot > MaxDot then
			Max = Set[Index]
			MaxDot = Dot
		end
	end

	return Max
end

function Supports.Cylinder(Set: {CFrame | Vector3}, Direction: Vector3)
	local CoordinateFrame: CFrame = Set[1] :: CFrame
	local SizeSquared: Vector3 = Set[2] :: Vector3
	Direction = CoordinateFrame:VectorToObjectSpace(Direction)

	local Radius = math.min(SizeSquared.Y, SizeSquared.Z)
	local DotT = Direction:Dot(RIGHT)
	local PointC = Vector3.xAxis * SizeSquared.X

	local ValueH: Vector3
	local Final: Vector3

	if DotT == 0 then
		Final = Direction.Unit * Radius
	else
		PointC = DotT > 0 and PointC or -PointC
		ValueH = RayPlane(ZERO, Direction, PointC, RIGHT)
		Final = PointC + (ValueH - PointC).Unit * Radius
	end

	return CoordinateFrame:PointToWorldSpace(Final)
end

function Supports.Ellipsoid(Set: {CFrame | Vector3}, Direction: Vector3)
	local CoordinateFrame: CFrame = Set[1] :: CFrame
	local SizeSquared: Vector3 = Set[2] :: Vector3
	return CoordinateFrame:PointToWorldSpace(
		SizeSquared * (SizeSquared * CoordinateFrame:VectorToObjectSpace(Direction)).Unit
	)
end

table.freeze(Supports)
return Supports

--!optimize 2
local MAX_TRIES = 20
local ZERO3 = Vector3.zero

local function TripleProduct(A: Vector3, B: Vector3, C: Vector3)
	return B * C:Dot(A) - A * C:Dot(B)
end

local function ContainsOrigin(Simplex: {Vector3}, Direction: Vector3): (boolean, Vector3?)
	local Length = #Simplex
	local A = Simplex[Length]
	local InverseA = -A

	if Length == 4 then
		local B, C, D = Simplex[3], Simplex[2], Simplex[1]
		local AB = B - A
		local AC = C - A
		local AD = D - A

		local ABC = AB:Cross(AC)
		local ACD = AC:Cross(AD)
		local ADB = AD:Cross(AB)

		ABC = ABC:Dot(AD) > 0 and -ABC or ABC
		ACD = ACD:Dot(AB) > 0 and -ACD or ACD
		ADB = ADB:Dot(AC) > 0 and -ADB or ADB

		if ABC:Dot(InverseA) > 0 then
			table.remove(Simplex, 1)
			Direction = ABC
		elseif ACD:Dot(InverseA) > 0 then
			table.remove(Simplex, 2)
			Direction = ACD
		elseif ADB:Dot(InverseA) > 0 then
			table.remove(Simplex, 3)
			Direction = ADB
		else
			return true
		end
	elseif Length == 3 then
		local B, C = Simplex[2], Simplex[1]
		local AB = B - A
		local AC = C - A

		local ABC = AB:Cross(AC)
		local ABPerp = TripleProduct(AC, AB, AB).Unit
		local ACPerp = TripleProduct(AB, AC, AC).Unit

		if ABPerp:Dot(InverseA) > 0 then
			table.remove(Simplex, 1)
			Direction = ABPerp
		elseif ACPerp:Dot(InverseA) > 0 then
			table.remove(Simplex, 2)
			Direction = ACPerp
		else
			if A - A ~= ZERO3 then
				return true
			else
				Direction = ABC:Dot(InverseA) > 0 and ABC or -ABC
			end
		end
	else
		local B = Simplex[1]
		local AB = B - A
		Direction = TripleProduct(AB, InverseA, AB).Unit
	end

	return false, Direction
end

type SupportFunction = (Set: {Vector3}, Direction: Vector3) -> Vector3

local function IsColliding(
	SetA: {Vector3},
	SetB: {Vector3},
	CentroidA: Vector3,
	CentroidB: Vector3,
	SupportA: SupportFunction,
	SupportB: SupportFunction
)
	local Direction = (CentroidA - CentroidB).Unit
	local Simplex = {SupportA(SetA, Direction) - SupportB(SetB, -Direction)}
	Direction = -Direction

	for _ = 1, MAX_TRIES do
		table.insert(Simplex, SupportA(SetA, Direction) - SupportB(SetB, -Direction))
		if Simplex[#Simplex]:Dot(Direction) <= 0 then
			return false
		else
			local Passed, NewDirection = ContainsOrigin(Simplex, Direction)
			if Passed then
				return true
			else
				Direction = NewDirection
			end
		end
	end

	return false
end

return IsColliding

--#######################################--
--   boxscript v1.1 by DrippingYellow    --
--                                       --
--  A hitbox viewer for Joy Mech Fight.  --
--#######################################--

local viewHitboxes = 0
local viewDistances = 0
local holdingMouse = false

-- Grab range addresses for all the characters in order of internal ID.
-- 0 means the character can't grab.
local grabRangeAddresses = { 
	0x9854, 0x9947, 0x9A7B, 0x9797, 0x99E3, 0x98A5, 0x9982, 0x97A9,
	     0, 0x97B2, 0x97BB, 0x97C4,      0, 0x9947, 0x97D6,      0,
	0x9A2A,      0, 0x9947,      0, 0x9854,      0, 0x9982,      0,
	0x97E8, 0x9ACC,      0, 0x97F1, 0x97FA,      0,      0,      0,
	0x9854, 0x9947, 0x9A7B, 0x9803, 0x99E3, 0x98A5, 0x9982, 0x980C
}

-- Gel and John's IDs are way later than the other characters' for some reason.
--local gelJohnGrabRanges = {47, 47}
local gelJohnGrabRangeAddresses = {0x99E3, 0x9815}

local airGrabRangeAddress = 0x859D

-- These addresses aren't used in this program - yet. I'm putting them here for posterity.
local kickThrowGrabRangeAddress = 0x9A03
-- Hover's address = high jump distance
local highJumpRangeAddress = 0x94B3
-- Hover's address - range to transition from high jump to meteor shot
local meteorShotRangeAddress = 0x9B6B

local hitboxSizeStrings = {"Off","16x16","10x10","6x6","4x4","1x1"}
local onOffStrings = {"Off","On"}

local fighterID = {0, 0}
local fighterXPos = {0, 0}
local fighterYPos = {0, 0}
local fighterInvincible = {0, 0}

local airGrabCharacters = {0x4, 0x24}
local isAirGrabCharacter = {false, false}

local kickGrabCharacters = {0x4, 0x24, 0x80}
local kickGrabCharacter = {false, false}


local function isInTable(ID, charTable)
	for i = 1, #charTable, 1 do
		if (ID == charTable[i]) then
			return true
		end
	end

	return false
end

local function checkCharGrab(player, distance)
	local oppInvincible = fighterInvincible[player ~ 3]
	
	if (oppInvincible == 1) then
		return false
	end
	
	local fighterStruct = ((player-1)*0x100) + 0x500
	local oppStruct = fighterStruct ~ 0x300 -- bitwise XOR that converts between P1 and P2 addresses
	
	local fighterState = emu.read(fighterStruct+0x1C, emu.memType.nesMemory, false)
	
	local fighterIsAirborne = emu.read(fighterStruct+0x1F, emu.memType.nesMemory, false) == 1
	local oppIsAirborne = emu.read(oppStruct+0x1F, emu.memType.nesMemory, false) == 1

	local grabRange

-- If both fighters aren't airborne and the user's state is a grounded, non-attacking one.
	if ((not fighterIsAirborne and not oppIsAirborne) and fighterState < 3) then
		if (fighterID[player] >= 0x80) then
			grabRange = gelJohnGrabRangeAddresses[(fighterID[player] % 0x80) + 1]
		else
			grabRange = grabRangeAddresses[fighterID[player] + 1]
		end
-- If playing as a ninja and both fighters are airborne and the user is in a jumping state.
	elseif (isAirGrabCharacter[player] == true) then
	
		if ((not fighterIsAirborne or not oppIsAirborne) or fighterState ~= 3) then
			return false
		end
		
		local oppXPos = fighterXPos[player ~ 3]
		local oppYPos = fighterYPos[player ~ 3]
			
		local fighterDirection = emu.read(fighterStruct+0x1E, emu.memType.nesMemory, false)
		
-- Opponent must be in front of the user.
		if (fighterDirection == 1) then
			if (oppXPos >= fighterXPos[player]) then
				return false
			end
		else
			if (oppXPos < fighterXPos[player]) then
				return false
			end
		end
-- Check for vertical distance.
		if (math.abs(fighterYPos[player] - oppYPos) >= 0x40) then
			return false
		end
-- User must be high up enough to use it.
		if (fighterYPos[player] >= 0x40) then
			return false
		end
		
		grabRange = airGrabRangeAddress
	else
		return false
	end
		
	if (grabRange == 0) then
		return false
	elseif (distance < emu.read(grabRange, emu.memType.nesPrgRom, false)) then
		return true
	end
	
	return false
end

local function checkBackBlock(distance, isProjectile)
	if (isProjectile) then
		if (distance < 0x60) then
			return true
		end
	else
		local p1State = emu.read(0x51C, emu.memType.nesMemory, false)
		local p2State = emu.read(0x61C, emu.memType.nesMemory, false)
		
		if (((p1State >= 4 and p1State < 14) or (p2State >= 4 and p2State < 14)) and distance < 0x80) then
			return true
		end
	end
	
	return false
end

local function displayHitboxes(player)
	local fighterStruct = ((player-1)*0x100) + 0x500
	
	local hitboxSizes = {8, 5, 3, 2, 0}
	local currentHitboxSize = hitboxSizes[viewHitboxes]
	
	for i = 0, 12, 1
	do
		local x = emu.read(fighterStruct+0xC0+(i*2), emu.memType.nesMemory, false)
		if x ~= 0 then 
			local y = emu.read(fighterStruct+0xC1+(i*2), emu.memType.nesMemory, false)
			if (currentHitboxSize == 0) then
				emu.drawRectangle(x-1, y-1, 3, 3, 0x3F7F0000, true)
				emu.drawRectangle(x, y, 1, 1, 0xFF0000, true)
			else
				emu.drawRectangle(x-currentHitboxSize, y-currentHitboxSize, currentHitboxSize*2, currentHitboxSize*2, 0x3FFF0000, true)
			end
		end
	end
	
end

local function displayCollisionBox(player)

	local collisionBoxSize = 24
	local bodyX = fighterXPos[player]
	local bodyY = fighterYPos[player]
	
	emu.drawRectangle(bodyX-(collisionBoxSize//2), bodyY-(collisionBoxSize//2), collisionBoxSize, collisionBoxSize, 0x3F3F3F3F, true)
end

local function displayHurtbox(player)
	local fighterStruct = ((player-1)*0x100) + 0x500
	
	local hurtboxHeights = {13, 8, 4, 2, 1}
	local hurtboxWidths = {22, 28, 32, 34, 37}
	
	local hurtboxColor = 0x3F0000FF

	local currentHurtboxWidth = hurtboxWidths[viewHitboxes]
	local currentHurtboxHeight = hurtboxHeights[viewHitboxes]
	
	local bodyPartsGone = emu.read(fighterStruct+0x25, emu.memType.nesMemory, false)
	
	if (fighterInvincible[player] == 1) then hurtboxColor = 0x3FFF00FF end
	
	local bodyX = fighterXPos[player]
	
	local headY = emu.read(fighterStruct+0x7, emu.memType.nesMemory, false)
	local bodyY = fighterYPos[player]
	local frontLegY = emu.read(fighterStruct+0x3, emu.memType.nesMemory, false)
	local backLegY = emu.read(fighterStruct+0xD, emu.memType.nesMemory, false)
	
	local topY = 0
	local bottomY = 0
	local bottomLegY = 0
	local yPositions = {}
	
	if frontLegY < backLegY then bottomLegY = backLegY
	else bottomLegY = frontLegY end
	
	if (bodyPartsGone & 0x10 ~= 0) then
		table.insert(yPositions, bodyY)
	else
		table.insert(yPositions, headY)
	end
	
	table.insert(yPositions, bodyY)
	
	if (bodyPartsGone & 0x42 ~= 0) then
		table.insert(yPositions, bodyY)
	else
		table.insert(yPositions, bottomLegY)
	end
	
	topY = yPositions[1]
	
	for i = 2, 3, 1
	do
		if yPositions[i] < topY then topY = yPositions[i] end
	end
	
	bottomY = yPositions[1]
	
	for i = 2, 3, 1
	do
		if yPositions[i] > bottomY then bottomY = yPositions[i] end
	end
	
	if bottomY < topY then
		local temp = bottomY
		bottomY = topY
		topY = temp
	end
	
	
	
	if (currentHurtboxHeight ~= 1) then
		local hitboxReduction = math.ceil(currentHurtboxHeight/2)
		topY = topY + hitboxReduction
		bottomY = (bottomY - 1) - hitboxReduction
		if (bottomY <= topY) then
			emu.drawString(bodyX-3, bodyY-4, "?", 0xFFFFFF, 0x3FFF0000)
			return
		end
	else
		if (bottomY < topY) then
			emu.drawString(bodyX-3, bodyY-4, "?", 0xFFFFFF, 0x3FFF0000)
			return
		end
	end
	
	emu.drawRectangle(bodyX-(currentHurtboxWidth//2), topY,
					  currentHurtboxWidth, bottomY - topY,
					  hurtboxColor, true)
end

local function displayFighterDistance()
	local function getTextWidth(distance)
		local width = 6
		if (distance >= 100) then 
			width = 18
		elseif (distance >= 10) then
			width = 12
		end
		
		return width
	end

	local function drawDistanceLine(x1, x2, y, dist, lineColor, textBackgroundColor)
		emu.drawLine(x1, y-2, x1, y+2, lineColor)
		emu.drawLine(x2, y-2, x2, y+2, lineColor)
		emu.drawLine(x1, y, x2, y, 0x3F000000+lineColor)
		emu.drawString((x1 + x2 - getTextWidth(dist))/2, y-0x10, ""..dist, 0x00FFFFFF, textBackgroundColor)
	end
	

	local fighterDistance = emu.read(0x74, emu.memType.nesMemory, false)
	
	local p1ProjectileX = emu.read(0x539, emu.memType.nesMemory, false)
	local p2ProjectileX = emu.read(0x639, emu.memType.nesMemory, false)
	
	local lineColor = 0x00BF00
	local textBackgroundColor = 0x7F000000
	
	p1CanGrab = checkCharGrab(1, fighterDistance)
	p2CanGrab = checkCharGrab(2, fighterDistance)
	
	if (p1CanGrab == true) then
		lineColor = (lineColor | 0xBF0000) & ~0x00FF00
	end
	
	if (p2CanGrab == true) then
		lineColor = (lineColor | 0x0000BF) & ~0x00FF00
	end
	
	if (checkBackBlock(fighterDistance, false)) then
		textBackgroundColor = textBackgroundColor | 0xFF0000
	end
	
	drawDistanceLine(fighterXPos[1], fighterXPos[2], 0x70, fighterDistance, lineColor, textBackgroundColor)
	
	if (p2ProjectileX ~= 0) then
		local p1ProjectileDistance = math.abs(p2ProjectileX - fighterXPos[1])
		
		if (checkBackBlock(p1ProjectileDistance, true)) then
			textBackgroundColor = 0x7FFF0000
		else
			textBackgroundColor = 0x7F000000
		end
		
		drawDistanceLine(fighterXPos[1], p2ProjectileX, 0x90, p1ProjectileDistance, 0x00BF00, textBackgroundColor)
	end
	
	if (p1ProjectileX ~= 0) then
		local p2ProjectileDistance = math.abs(p1ProjectileX - fighterXPos[2])
		
		if (checkBackBlock(p2ProjectileDistance, true)) then
			textBackgroundColor = 0x7FFF0000
		else
			textBackgroundColor = 0x7F000000
		end
		
		drawDistanceLine(fighterXPos[2], p1ProjectileX, 0xB0, p2ProjectileDistance, 0x00BF00, textBackgroundColor)
	end
		
end

function Main()

-- Pre-loading important variables so we don't have to keep reading them.
	for i = 1, 2, 1
	do
		local fighterStruct = ((i-1)*0x100) + 0x500
		fighterID[i] = emu.read(fighterStruct+0x3F, emu.memType.nesMemory, false)
		fighterXPos[i] = emu.read(fighterStruct+0x8, emu.memType.nesMemory, false)
		fighterYPos[i] = emu.read(fighterStruct+0x9, emu.memType.nesMemory, false)
		fighterInvincible[i] = emu.read(fighterStruct+0x27, emu.memType.nesMemory, false)
		isAirGrabCharacter[i] = isInTable(fighterID[i], airGrabCharacters)
	end
	
	local mouse = emu.getMouseState()
	
	if (mouse["left"] == true) then
		if not holdingMouse then	
			viewHitboxes = (viewHitboxes + 1) % 6
			holdingMouse = true
			emu.displayMessage("boxscript", "Hitbox Viewer: "..hitboxSizeStrings[viewHitboxes+1])
		end
	elseif (mouse["right"] == true) then
		if not holdingMouse then	
			viewDistances = (viewDistances + 1) % 2
			holdingMouse = true
			emu.displayMessage("boxscript", "Fighter Distance Viewer: "..onOffStrings[viewDistances+1])
		end
	else
		holdingMouse = false
	end

	--emu.clearScreen()
	
	if (viewHitboxes ~= 0) then
		displayHurtbox(1)
		displayHurtbox(2)
		displayCollisionBox(1)
		displayCollisionBox(2)
		displayHitboxes(1)
		displayHitboxes(2)
	end
	
	if (viewDistances ~= 0) then
		displayFighterDistance()
	end
end


emu.displayMessage("boxscript", "Press left click to toggle hitboxes. Press right click to toggle distance lines.")

emu.addEventCallback(Main, emu.eventType.endFrame)


local module = {}

local random = Random.new() --Might have to put this inside simulate projectile function for truly random
local Parabola = require(game.ReplicatedStorage:WaitForChild("Parabola"))
local Roblox = require(game.ReplicatedStorage:WaitForChild("Roblox"))
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")


local function weldGun(gun)
	local Main = gun.GunComponents.Handle

	for i, v in ipairs(gun:GetDescendants()) do
		if v:IsA("BasePart") and v ~= Main then
			local newMotor = Instance.new("Motor6D")
			newMotor.Name = v.Name
			newMotor.Part0 = Main
			newMotor.part1 = v
			newMotor.C0 = newMotor.Part0.CFrame:inverse() * newMotor.Part1.CFrame --This is part0 relative to part1's cframe
			newMotor.Parent = Main
		end
	end
end

function module.equip(viewmodel, gun)
	weldGun(gun)
	
	local gunHandle = gun.GunComponents.Handle
	local HRP_Motor6D = viewmodel:WaitForChild("HumanoidRootPart").Handle

	gun.Parent = viewmodel
	HRP_Motor6D.Part1 = gunHandle
	
	local player = game.Players.LocalPlayer
	
	local currentAmmo = gun.Configuration.CurrentAmmo.Value
	local maxAmmo = gun.Configuration.MAX_AMMO.Value
	
	player.PlayerGui:WaitForChild("GunGui"):WaitForChild("AmmoFrame"):WaitForChild("AmmoLabel").Text = currentAmmo.. "/" ..maxAmmo
	player.PlayerGui:WaitForChild("GunGui"):WaitForChild("AmmoFrame"):WaitForChild("GunName").Text = gun.GunName.Value
	
	local character = player.Character or player.CharacterAdded:Wait()
	
	local equip = viewmodel.AnimationController:LoadAnimation(gun.GunAnims.Equip)
	equip:Play()
	
	task.wait(gun.Configuration.EQUIP_TIME.Value)

	local hold = viewmodel.AnimationController:LoadAnimation(gun.GunAnims.Hold)
	hold:Play(0.2)
end

local function unweldGun(gun)
	
	for i, v in pairs(gun.GunComponents.Handle:GetDescendants()) do
		if v:IsA("Motor6D") then
			v:Destroy()
		end
	end
end

function module.unequip(viewmodel, gun)
	
	local unequip = viewmodel.AnimationController:LoadAnimation(gun.GunAnims.Stowe)
	unequip:Play(0.3)
	task.wait(gun.Configuration.STOWE_TIME.Value)
	
	unweldGun(gun)
	
	local HRP_Motor6D = viewmodel:WaitForChild("HumanoidRootPart").Handle
	HRP_Motor6D.Part1 = nil
	
	gun.Parent = game.ReplicatedStorage
end


function module.simulateProjectile(player, gunModel, dmg)
	
	local body = gunModel.Body
	local config = gunModel.Configuration
	
	local damage = game.ReplicatedStorage.Damage
	
	local origin
	local dir
	
	local bulletSpeed = config.BulletSpeed.Value
	local maxDistance = config.MaxDistance.Value
	local minSpread = config.MinSpread.Value
	local maxSpread = config.MaxSpread.Value
	local trailLengthFactor = config.TrailLengthFactor.Value
	local gravityFactor = config.GravityFactor.Value
	local muzzleFlashSize0 = config.MuzzleFlashSize0.Value
	local muzzleFlashSize1 = config.MuzzleFlashSize1.Value
	local showEntireTrailUntilHit = false
	local trailLength = nil
	
	local MAX_BULLET_TIME = 10
	
	local tipCFrame = body.TipAttachment.WorldCFrame
	local tipPos = tipCFrame.Position
	local tipDir = tipCFrame.LookVector
	local amountToCheatBack = math.abs((body.Position - tipPos):Dot(tipDir)) + 1
	local gunRay = Ray.new(tipPos - tipDir.Unit * amountToCheatBack, tipDir.Unit * amountToCheatBack)
	local hitPart, hitPoint = Roblox.penetrateCast(gunRay, {player.Character}) --Ignore local player
	origin = hitPoint - tipDir.Unit * 0.1
	dir = tipDir.Unit
	
	local hitMarker = player.PlayerGui.WeaponsSystemGui.HitMarker.HitMarkerImage
	
	-- Initialize variables for visuals/particle effects
	local bullet = game.ReplicatedStorage.Bullet:Clone()
	bullet.CFrame = CFrame.new(origin, origin + dir)
	bullet.Parent = workspace.CurrentCamera

	local attachment0 = bullet:FindFirstChild("Attachment0")
	local trailParticles = nil
	if attachment0 then
		trailParticles = attachment0:FindFirstChild("TrailParticles")
	end

	local hitAttach = bullet:FindFirstChild("HitEffect")
	local hitParticles = bullet:FindFirstChild("HitParticles", true)
	local numHitParticles = 3
	local hitSound = bullet:FindFirstChild("HitSound", true)

	local muzzleFlashTime = 0.03
	local muzzleFlashShown = false

	local beamThickness0 = 1.5
	local beamThickness1 = 1.8

	-- Enable beam trails for projectile
	local beam0 = bullet:FindFirstChild("Beam0")
	if beam0 then
		beam0.Enabled = true
	end
	local beam1 = bullet:FindFirstChild("Beam1")
	if beam1 then
		beam1.Enabled = true
	end
	
	-- Play shoot sound
	coroutine.wrap(function()
		local fireSound = gunModel.Body.Fired:Clone()
		fireSound.Parent = workspace
		fireSound:Play()
		task.wait(1)
		fireSound:Destroy()
	end)()

	-- Show muzzle flash
	local minFlashRotation, maxFlashRotation = -math.pi, math.pi
	local minFlashSize, maxFlashSize = muzzleFlashSize0, muzzleFlashSize1
	local flashRotation = random:NextNumber(minFlashRotation, maxFlashRotation)
	local flashSize = random:NextNumber(minFlashSize, maxFlashSize)
	local baseCFrame = body.TipAttachment.CFrame * CFrame.Angles(0, 0, flashRotation)
	body.MuzzleFlash0.CFrame = baseCFrame * CFrame.new(flashSize * -0.5, 0, 0) * CFrame.Angles(0, math.pi, 0)
	body.MuzzleFlash1.CFrame = baseCFrame * CFrame.new(flashSize * 0.5, 0, 0) * CFrame.Angles(0, math.pi, 0)

	body.MuzzleFlash.Enabled = true
	body.MuzzleFlash.Width0 = flashSize
	body.MuzzleFlash.Width1 = flashSize
	muzzleFlashShown = true

	-- Enable trail particles
	if trailParticles then
		trailParticles.Enabled = true
	end

	-- Set up parabola for projectile path
	local parabola = Parabola.new()
	parabola:setPhysicsLaunch(origin, dir * bulletSpeed, nil, 35 * -gravityFactor)
	-- More samples for higher gravity since path will be more curved but raycasts can only be straight lines
	if gravityFactor > 0.66 then
		parabola:setNumSamples(3)
	elseif gravityFactor > 0.33 then
		parabola:setNumSamples(2)
	else
		parabola:setNumSamples(1)
	end

	-- Set up/initialize variables used in steppedCallback
	local stepConn = nil
	local pTravelDistance = 0 -- projected travel distance so far if projectile never stops
	local startTime = tick()
	local didHit = false
	local stoppedMotion = false
	local stoppedMotionAt = 0
	local timeSinceStart = 0
	local flyingVisualEffectsFinished = false -- true if all particle effects shown while projectile is flying are done
	local visualEffectsFinishTime = math.huge
	local visualEffectsLingerTime = 0 -- max time any visual effect needs to finish
	
	
	local hitInfo = {
		maxDist = maxDistance,
		part = nil,
		p = nil,
		n = nil,
		m = Enum.Material.Air,
		d = 1e9,
	}
	

	local steppedCallback = function(dt)
		local now = tick()
		timeSinceStart = now - startTime

		local travelDist = bulletSpeed * dt -- distance projectile has travelled since last frame
		trailLength = trailLength or travelDist * trailLengthFactor

		-- Note: the next three variables are all in terms of distance from starting point (which should be tip of current weapon)
		local projBack = pTravelDistance - trailLength -- furthest back part of projectile (including the trail effect, so will be the start of the trail effect if any)
		local projFront = pTravelDistance -- most forward part of projectile
		local maxDist = maxDistance or 0 -- before it collides, this is the max distance the projectile can travel. After it collides, this is the hit point

		-- This will make trailing beams render from tip of gun to wherever projectile is until projectile is destroyed
		if showEntireTrailUntilHit then
			projBack = 0
		end

		-- Validate projBack and projFront
		projBack = math.clamp(projBack, 0, maxDist)
		projFront = math.clamp(projFront, 0, maxDist)

		if not didHit then
			-- Check if bullet hit since last frame
			local castProjBack, castProjFront = projFront, projFront + travelDist
			parabola:setDomain(castProjBack, castProjFront)
			local hitPart, hitPoint, hitNormal, hitMaterial, hitT = parabola:findPart({player.Character})

			if hitPart then
				didHit = true
				projFront = castProjBack + hitT * (castProjFront - castProjBack) -- set projFront to point along projectile arc where an object was hit
				parabola:setDomain(projBack, projFront) -- update parabola domain to match new projFront

				-- Update hitInfo
				hitInfo.part = hitPart
				hitInfo.p = hitPoint
				hitInfo.n = hitNormal
				hitInfo.m = hitMaterial
				hitInfo.d = (hitPoint - origin).Magnitude
				hitInfo.t = hitT
				hitInfo.maxDist = projFront -- since the projectile hit, maxDist is now the hitPoint instead of maxDistance

				-- Deal with all effects that start/stop/change on hit
				-- Disable trail particles
				if trailParticles then
					trailParticles.Enabled = false
				end

				-- Hide the actual projectile model
				if bullet then
					bullet.Transparency = 1
				end
				
				-- Make sure hitAttach is in correct position before showing hit effects
				if hitAttach and beam0 and beam0.Attachment1 then
					parabola:renderToBeam(beam0)
					hitAttach.CFrame = beam0.Attachment1.CFrame * CFrame.Angles(0, math.rad(90), 0)
				end

				-- Show hit particle effect
				local hitPartColor = hitPart and hitPart.Color or Color3.fromRGB(255, 255, 255)
				if hitPart and hitPart:IsA("Terrain") then
					hitPartColor = workspace.Terrain:GetMaterialColor(hitMaterial or Enum.Material.Sand)
				end
				
				if hitPart.Parent:FindFirstChildOfClass("Humanoid") and hitParticles and numHitParticles > 0 and hitPart then
					-- Show particle effect for hitting a player/humanoid
					hitParticles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
					hitParticles:Emit(numHitParticles)
					visualEffectsLingerTime = math.max(visualEffectsLingerTime, hitParticles.Lifetime.Max)
					
					if damage ~= nil then
						damage:FireServer(hitPart.Parent:FindFirstChildOfClass("Humanoid"), dmg)
						hitMarker.ImageTransparency = 0 
						
						coroutine.wrap(function()
							task.wait(0.3)
							hitMarker.ImageTransparency = 1
						end)()
					end
					
				elseif (not hitPart.Parent:FindFirstChildOfClass("Humanoid")) and hitParticles and numHitParticles > 0 then
					-- Show particle effect for hitting anything else
					if hitPart then
						local existingSeq = hitParticles.Color
						local newKeypoints = {}

						for i, keypoint in pairs(existingSeq.Keypoints) do
							local newColor = keypoint.Value
							if newColor == Color3.fromRGB(255, 0, 255) then
								newColor = hitPartColor
							end
							newKeypoints[i] = ColorSequenceKeypoint.new(keypoint.Time, newColor)
						end

						hitParticles.Color = ColorSequence.new(newKeypoints)
					end

					hitParticles:Emit(numHitParticles)
					visualEffectsLingerTime = math.max(visualEffectsLingerTime, hitParticles.Lifetime.Max)
				end

				-- Play hit sound
				if hitSound then
					hitSound:Play()
					visualEffectsLingerTime = math.max(visualEffectsLingerTime, hitSound.TimeLength)
				end

				-- Manage/show decals, billboards, and models (such as an arrow) that appear where the projectile hit (only if the hit object was not a humanoid/player)
				local hitPointObjectSpace = hitPart.CFrame:pointToObjectSpace(hitPoint)
				local hitNormalObjectSpace = hitPart.CFrame:vectorToObjectSpace(hitNormal)
				if hitPart and
					not hitPart.Parent or not hitPart.Parent:FindFirstChildOfClass("Humanoid") and
					hitPointObjectSpace and
					hitNormalObjectSpace and
					game.ReplicatedStorage.BulletHole
				then
					-- Clone hitMark (this contains all the decals/billboards/models to show on the hit surface)
					local hitMark = game.ReplicatedStorage.BulletHole:Clone()
					hitMark.Parent = hitPart

					-- Move/align hitMark to the hit surface
					local incomingVec = parabola:sampleVelocity(1).Unit

					-- Make hitMark face straight out from surface where projectile hit (good for decals)
					local forward = hitNormalObjectSpace
					local up = incomingVec
					local right = -forward:Cross(up).Unit
					up = forward:Cross(right)
					local orientationCFrame = CFrame.fromMatrix(hitPointObjectSpace + hitNormalObjectSpace * 0.05, right, up, -forward)
					hitMark.CFrame = hitPart.CFrame:toWorldSpace(orientationCFrame)

					-- Weld hitMark to the hitPart
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = hitMark
					weld.Part1 = hitPart
					weld.Parent = hitMark

					-- Set bullethole decal color and fade over time
					local bulletHole = hitMark:FindFirstChild("BulletHole")
					if bulletHole then
						bulletHole.Color3 = hitPartColor
						TweenService:Create(
							bulletHole,
							TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 4),
							{ Transparency = 1 }
						):Play()
					end

					-- Fade impact billboard's size and transparency over time
					local impactBillboard = hitMark:FindFirstChild("ImpactBillboard")
					if impactBillboard then
						local impact = impactBillboard:FindFirstChild("Impact")
						local impactTween = TweenService:Create(
							impact,
							TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0),
							{ Size = UDim2.new(1, 0, 1, 0) }
						)
						impactTween.Completed:Connect(function()
							TweenService:Create(
								impact,
								TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0),
								{ Size = UDim2.new(0.5, 0, 0.5, 0), ImageTransparency = 1 }
							):Play()
						end)
						impactTween:Play()
					end

					-- Destroy hitMark in 5 seconds
					Debris:AddItem(hitMark, 5)
				end

				flyingVisualEffectsFinished = true
				visualEffectsFinishTime = now + visualEffectsLingerTime
			end
		end

		-- Will enter this if-statement if projectile hit something or maxDistance has been reached
		if projFront >= maxDist then
			if not stoppedMotion then
				stoppedMotion = true
				stoppedMotionAt = now
			end

			-- Stop particle effects if projectile didn't hit anything and projBack has reached the end
			if projBack >= maxDist and not flyingVisualEffectsFinished then
				flyingVisualEffectsFinished = true
				visualEffectsFinishTime = now + visualEffectsLingerTime
			end
		end

		-- Update parabola domain
		parabola:setDomain(projBack, projFront)

		-- Continue updating pTravelDistance until projBack has reached maxDist (this helps with some visual effects)
		if projBack < maxDist then
			pTravelDistance = math.max(0, timeSinceStart * bulletSpeed)
		end


		-- Update visual effects each frame
		-- Update thickness and render trailing beams
		local thickness0 = beamThickness0
		local thickness1 = beamThickness1
		
		if beam0 then
			beam0.Width0 = thickness0
			beam0.Width1 = thickness1
			parabola:renderToBeam(beam0)
		end
		if beam1 then
			beam1.Width0 = thickness0
			beam1.Width1 = thickness1
			parabola:renderToBeam(beam1)
		end

		-- Disable muzzle flash after muzzleFlashTime seconds have passed
		if muzzleFlashShown and timeSinceStart > muzzleFlashTime and body.MuzzleFlash then
			body.MuzzleFlash.Enabled = false
			muzzleFlashShown = false
		end

		-- Destroy projectile and attached visual effects when visual effects are done showing or max bullet time has been reached
		local timeSinceParticleEffectsFinished = now - visualEffectsFinishTime
		if (flyingVisualEffectsFinished and timeSinceParticleEffectsFinished > 0) or timeSinceStart > MAX_BULLET_TIME then
			if bullet then
				bullet:Destroy()
				bullet = nil
			end

			stepConn:Disconnect()
		end
	end

	stepConn = RunService.Heartbeat:Connect(steppedCallback)
end



local function getBobbing(addition)
	return math.sin(tick() * addition * 1.3) * 0.5
end

function module.update(viewmodel, dt, recoilSpring, bobbleSpring, swayingSpring, gun, isAiming, isCrouching)
	viewmodel.HumanoidRootPart.CFrame = workspace.Camera.CFrame

	local bobble = Vector3.new(getBobbing(10), getBobbing(5), getBobbing(5))
	local mouseDelta = game:GetService("UserInputService"):GetMouseDelta()

	local character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()

	bobbleSpring:shove(bobble / 10 * (character:WaitForChild("HumanoidRootPart").Velocity.Magnitude) / 10)
	swayingSpring:shove(Vector3.new(-mouseDelta.X / 500, mouseDelta.Y / 200, 0))

	local updatedRecoilSpring = recoilSpring:update(dt)
	local updatedBobbleSpring = bobbleSpring:update(dt)
	local updatedSwayingSpring = swayingSpring:update(dt)
	
	gun.GunComponents.Sight.CFrame = gun.GunComponents.Sight.CFrame:Lerp(viewmodel.HumanoidRootPart.CFrame, gun.Configuration.AimAlpha.Value)
	
	-- Make bobble and recoil smaller if aiming or crouching
	if isAiming then
		viewmodel.HumanoidRootPart.CFrame = viewmodel.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(updatedBobbleSpring.Y / 10, updatedBobbleSpring.X / 10, 0))

		viewmodel.HumanoidRootPart.CFrame *= CFrame.Angles(math.rad(updatedRecoilSpring.X) * 1.4, 0, 0)
		game.Workspace.Camera.CFrame *= CFrame.Angles(math.rad(updatedRecoilSpring.X / 2), math.rad(updatedRecoilSpring.Y / 2), math.rad(updatedRecoilSpring.Z / 2))
		
	elseif isCrouching then
		viewmodel.HumanoidRootPart.CFrame = viewmodel.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(updatedBobbleSpring.Y / 5, updatedBobbleSpring.X / 5, 0))

		viewmodel.HumanoidRootPart.CFrame *= CFrame.Angles(math.rad(updatedRecoilSpring.X) * 1.75, 0, 0)
		game.Workspace.Camera.CFrame *= CFrame.Angles(math.rad(updatedRecoilSpring.X/ 1.6), math.rad(updatedRecoilSpring.Y / 1.6), math.rad(updatedRecoilSpring.Z / 1.6))
		
	else
		viewmodel.HumanoidRootPart.CFrame = viewmodel.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(updatedBobbleSpring.Y, updatedBobbleSpring.X, 0))

		viewmodel.HumanoidRootPart.CFrame *= CFrame.Angles(math.rad(updatedRecoilSpring.X) * 2, 0, 0)
		game.Workspace.Camera.CFrame *= CFrame.Angles(math.rad(updatedRecoilSpring.X), math.rad(updatedRecoilSpring.Y), math.rad(updatedRecoilSpring.Z))
	end
	
	viewmodel.HumanoidRootPart.CFrame *= CFrame.new(updatedSwayingSpring.X, updatedSwayingSpring.Y, 0)
end

function module.aim(toaim, isReloading, isCrouching, viewmodel, gun)
	if toaim and not isReloading then
		TweenService:Create(gun.Configuration.AimAlpha, TweenInfo.new(gun.Configuration.ADS_TIME.Value, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Value = 1}):Play()
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = gun.Configuration.NORMAL_WALKSPEED.Value / 2
		
	else
		TweenService:Create(gun.Configuration.AimAlpha, TweenInfo.new(gun.Configuration.ADS_TIME.Value, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Value = 0}):Play()
		
		if not isCrouching then
			game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = gun.Configuration.NORMAL_WALKSPEED.Value
		end
	end
end

function module.reload(viewmodel, gun, reloadAnim, holdAnim)
	local reload = viewmodel.AnimationController:LoadAnimation(reloadAnim)
	reload:Play()
	gun.Body.Reload:Play()

	task.wait(gun.Configuration.RELOAD_TIME.Value)

	gun.Configuration.CurrentAmmo.Value = gun.Configuration.MAX_AMMO.Value

	local hold = viewmodel.AnimationController:LoadAnimation(holdAnim)
	hold:Play()
end

function module.toggleAimGui(crosshair, toAim, toCrouch)
	
	local bottom = crosshair.Bottom
	local left = crosshair.Left
	local right = crosshair.Right
	local top = crosshair.Top
	
	local guiNormal = {
		[bottom] = UDim2.new(0.5, 0, 1, 0),
		[left] = UDim2.new(0, 0, 0.5, 0),
		[right] = UDim2.new(1, 0, 0.5, 0),
		[top] = UDim2.new(0.5, 0, 0, 0)
	}
	
	local guiAim = {
		[bottom] = UDim2.new(0.5, 0, 0.9, 0),
		[left] = UDim2.new(0.1, 0, 0.5, 0),
		[right] = UDim2.new(0.9, 0, 0.5, 0),
		[top] = UDim2.new(0.5, 0, 0.1, 0)
	}
	
	if toAim or toCrouch then
		for gui, goal in pairs(guiAim) do
			TweenService:Create(gui, TweenInfo.new(0.3), {Position = goal}):Play()
		end
	elseif not (toAim and toCrouch) then
		for gui, goal in pairs(guiNormal) do
			TweenService:Create(gui, TweenInfo.new(0.3), {Position = goal}):Play()
		end
	end
end

function module.toggleReloadGui(crosshair, isReloading)

	local bottom = crosshair.Bottom
	local left = crosshair.Left
	local right = crosshair.Right
	local top = crosshair.Top
	
	local guiTable = {
		bottom,
		left,
		right,
		top
	}

	if isReloading then
		for _, gui in ipairs(guiTable) do
			game:GetService("TweenService"):Create(gui, TweenInfo.new(0), {ImageTransparency = 0.7}):Play()
		end
	elseif not isReloading then
		for _, gui in ipairs(guiTable) do
			game:GetService("TweenService"):Create(gui, TweenInfo.new(0), {ImageTransparency = 0}):Play()
		end
	end
end

function module.toggleSprint(viewmodel, gunModel, toSprint, sprintAnim, holdAnim)
	
	if toSprint then
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = gunModel.Configuration.SPRINT_SPEED.Value
		TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.6), {FieldOfView = 85}):Play()
		local sprint = viewmodel.AnimationController:LoadAnimation(sprintAnim)
		sprint:Play(0.2)
	else
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = gunModel.Configuration.NORMAL_WALKSPEED.Value
		TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.6), {FieldOfView = 70}):Play()
		local hold = viewmodel.AnimationController:LoadAnimation(holdAnim)
		hold:Play(0.2)
	end
end

return module

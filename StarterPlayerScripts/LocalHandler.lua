local gunModel
local viewmodel = game.ReplicatedStorage:WaitForChild("Viewmodel")
local player = game.Players.LocalPlayer

local inventory = {game.ReplicatedStorage:WaitForChild("AR"), game.ReplicatedStorage:WaitForChild("SMG")}
gunModel = inventory[1]

local damage = game.ReplicatedStorage:WaitForChild("Damage")
local fire = game.ReplicatedStorage:WaitForChild("Fire")
local spawnEvent = game.ReplicatedStorage:WaitForChild('Spawn')

local gunModule = require(game.ReplicatedStorage.GunModule)
local movementModule = require(game.ReplicatedStorage.MovementModule)
local springModule = require(game.ReplicatedStorage.SpringModule)

local recoilSpring = springModule.new()
local bobbleSpring = springModule.new()
local swayingSpring = springModule.new()

local IsPlayerHoldingMouse
local CanFire = true
local isAiming = false
local isReloading = false
local isSprinting = false
local isSwitching = false
local isCrouching = false

local weaponsSystemGui = player.PlayerGui:WaitForChild('WeaponsSystemGui')
local crosshair

-- Set up cam
local cam = workspace.Camera
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = workspace.Cams.Cam1.CFrame

spawnEvent.OnClientEvent:Connect(function()
	viewmodel.Parent = workspace.Camera

	gunModule.equip(viewmodel, gunModel)

	--Set up ui
	weaponsSystemGui.Enabled = true
	crosshair = weaponsSystemGui:WaitForChild("Crosshair")
	player:GetMouse().Icon = "http://www.roblox.com/asset/?id=3079694876"

	game:GetService("RunService").RenderStepped:Connect(function(dt)
		gunModule.update(viewmodel, dt, recoilSpring, bobbleSpring, swayingSpring, gunModel, isAiming, isCrouching)
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end)
	
	-- Input events
	game:GetService("UserInputService").InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			IsPlayerHoldingMouse = true

		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not isReloading and not isSprinting and not isSwitching then
			gunModule.aim(true, isReloading, isCrouching, viewmodel, gunModel)
			isAiming = true
			gunModule.toggleAimGui(crosshair, isAiming, isCrouching)

		elseif input.KeyCode == Enum.KeyCode.R and not isReloading and not isSprinting and not isSwitching then
			isReloading = true
			gunModule.toggleReloadGui(crosshair, isReloading)
			gunModule.reload(viewmodel, gunModel, gunModel.GunAnims.Reload, gunModel.GunAnims.Hold)
			isReloading = false
			gunModule.toggleReloadGui(crosshair, isReloading)

		elseif input.KeyCode == Enum.KeyCode.LeftShift and not isReloading and not isAiming and not isSwitching and not isCrouching then
			isSprinting = true
			gunModule.toggleSprint(viewmodel, gunModel, isSprinting, gunModel.GunAnims.Sprint, gunModel.GunAnims.Hold)
		end
	end)

	game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			IsPlayerHoldingMouse = false

		elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not isReloading and not isSwitching then
			gunModule.aim(false, isReloading, isCrouching, viewmodel, gunModel)
			isAiming = false
			gunModule.toggleAimGui(crosshair, isAiming, isCrouching)

		elseif input.KeyCode == Enum.KeyCode.LeftShift and not isReloading and not isSwitching and not isCrouching then
			isSprinting = false
			gunModule.toggleSprint(viewmodel, gunModel, isSprinting, gunModel.GunAnims.Sprint, gunModel.GunAnims.Hold)

		elseif input.KeyCode == Enum.KeyCode.LeftAlt then
			isCrouching = not isCrouching
			gunModule.toggleAimGui(crosshair, isAiming, isCrouching)
			movementModule.crouch(viewmodel, gunModel, isCrouching, isSprinting)
			isSprinting = false
		end
	end)
	
	-- CLEAN UP THIS CODE
	player:GetMouse().WheelForward:Connect(function()
		if not isSwitching and not isReloading and not isSprinting and not isAiming then
			isSwitching = true
			if gunModel == inventory[1] then
				gunModule.unequip(viewmodel, gunModel)
				gunModule.equip(viewmodel, inventory[2])
				gunModel = inventory[2]
			else
				gunModule.unequip(viewmodel, gunModel)
				gunModule.equip(viewmodel, inventory[1])
				gunModel = inventory[1]
			end
			isSwitching = false
		end
	end)

	player:GetMouse().WheelBackward:Connect(function()
		if not isSwitching and not isReloading and not isSprinting and not isAiming then
			isSwitching = true
			if gunModel == inventory[1] then
				gunModule.unequip(viewmodel, gunModel)
				gunModule.equip(viewmodel, inventory[2])
				gunModel = inventory[2]
			else
				gunModule.unequip(viewmodel, gunModel)
				gunModule.equip(viewmodel, inventory[1])
				gunModel = inventory[1]
			end
			isSwitching = false
		end
	end)
end)

game:GetService("RunService").Heartbeat:Connect(function(dt)
	if IsPlayerHoldingMouse and CanFire and gunModel.Configuration.CurrentAmmo.Value > 0 and (not isReloading) and (not isSprinting) and not (isSwitching) then
		CanFire = false

		recoilSpring:shove(Vector3.new(1.8, math.random(-1, 1), 7) * gunModel.Configuration.RECOIL_FACTOR.Value)

		coroutine.wrap(function()

			task.wait(0.2)

			recoilSpring:shove(Vector3.new(-1.6, math.random(-1, 1), -7) * gunModel.Configuration.RECOIL_FACTOR.Value)
		end)()

		gunModule.simulateProjectile(player, gunModel, gunModel.Configuration.Damage.Value)
		fire:FireServer(gunModel)

		gunModel.Configuration.CurrentAmmo.Value -= 1

		task.wait(gunModel.Configuration.DELAY_TIME.Value)
		CanFire = true
	end
end)

fire.OnClientEvent:Connect(function(client, gunModel)
	if client ~= player then
		gunModule.simulateProjectile(player, gunModel, nil)
	end
end)

for i, gun in pairs(inventory) do
	gun.Configuration.CurrentAmmo.Changed:Connect(function()
		game.Players.LocalPlayer.PlayerGui.GunGui.AmmoFrame.AmmoLabel.Text = gun.Configuration.CurrentAmmo.Value.. "/" ..gun.Configuration.MAX_AMMO.Value
	end)
end

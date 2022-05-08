local module = {}

local TweenService = game:GetService("TweenService")
local springModule = require(game.ReplicatedStorage.SpringModule)

function module.spawn(player)
	
	local humanoid = player.Character.Humanoid
	
	local description = humanoid:GetAppliedDescription()
	description.HeightScale = 2
	humanoid:ApplyDescription(description)
	
	local randNum = math.random(1, #workspace.GameSpawns:GetChildren())
	player.Character.HumanoidRootPart.CFrame = workspace.GameSpawns:GetChildren()[randNum].CFrame
end


function module.crouch(viewmodel, gun, isCrouching, isSprinting)
	
	local slide = viewmodel.AnimationController:LoadAnimation(gun.GunAnims.Slide)
	local hold = viewmodel.AnimationController:LoadAnimation(gun.GunAnims.Hold)
	
	if isCrouching and not isSprinting then
		TweenService:Create(workspace.Camera, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {CFrame = workspace.Camera.CFrame * CFrame.new(0, -2, 0)}):Play()
		TweenService:Create(viewmodel.HumanoidRootPart, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {CFrame = workspace.Camera.CFrame * CFrame.new(0, -2, 0)}):Play()
		task.wait(0.5)
		game:GetService('RunService'):BindToRenderStep("CrouchCamera",
			Enum.RenderPriority.Camera.Value + 1, -- Priority is set right after the camera updates by the CameraScript
			function()
				workspace.Camera.CFrame -= Vector3.new(0, 2, 0)
			end
		)
		
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = gun.Configuration.CROUCH_SPEED.Value
		
	elseif not isCrouching then
		TweenService:Create(workspace.Camera, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {CFrame = workspace.Camera.CFrame * CFrame.new(0, 2, 0)}):Play()
		TweenService:Create(viewmodel.HumanoidRootPart, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {CFrame = workspace.Camera.CFrame * CFrame.new(0, 2, 0)}):Play()
		
		task.wait(0.5)
		game:GetService('RunService'):UnbindFromRenderStep('CrouchCamera')
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = gun.Configuration.NORMAL_WALKSPEED.Value
		
	elseif isCrouching and isSprinting then
		TweenService:Create(workspace.Camera, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {CFrame = workspace.Camera.CFrame * CFrame.new(0, -2, 0)}):Play()
		TweenService:Create(viewmodel.HumanoidRootPart, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {CFrame = workspace.Camera.CFrame * CFrame.new(0, -2, 0)}):Play()
		
		slide:Play(0.3)
		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 30
		
		task.wait(0.3)
		game:GetService('RunService'):BindToRenderStep("CrouchCamera",
			Enum.RenderPriority.Camera.Value + 1, -- Priority is set right after the camera updates by the CameraScript
			function()
				workspace.Camera.CFrame -= Vector3.new(0, 2, 0)
			end
		)
		
		local shake = springModule.new()

		shake:shove(Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3)))

		local shakeLoop = game:GetService('RunService').RenderStepped:Connect(function(dt)
			local updatedShake = shake:update(dt)
			viewmodel.HumanoidRootPart.CFrame = viewmodel.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(updatedShake.Y, updatedShake.X, 0))
		end)
		
		task.wait(1.5) --Slide time
		shakeLoop:Disconnect()
		hold:Play(0.2)

		game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = gun.Configuration.CROUCH_SPEED.Value
	end
end

return module

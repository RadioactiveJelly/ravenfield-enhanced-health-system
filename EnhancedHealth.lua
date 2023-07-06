-- Register the behaviour
behaviour("EnhancedHealth")

enhancedHealthInstance = nil

function EnhancedHealth:Awake()
	self.gameObject.name = "EnhancedHealth"
end

function EnhancedHealth:Start()
	-- Run when behaviour is created
	Player.actor.onTakeDamage.AddListener(self,"onTakeDamage")
	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")
	GameEvents.onActorDied.AddListener(self,"onActorDied")

	self.healDelay = self.script.mutator.GetConfigurationFloat("healDelay")
	self.healInterval = self.script.mutator.GetConfigurationFloat("healInterval")
	self.healValue = self.script.mutator.GetConfigurationFloat("healValue")
	self.maxHP = self.script.mutator.GetConfigurationInt("maxHP")
	self.doRegen = self.script.mutator.GetConfigurationBool("doRegen")
	self.isPercent = self.script.mutator.GetConfigurationBool("isPercent")
	self.doQuickAnim = self.script.mutator.GetConfigurationBool("doQuickAnim")
	self.stimHeal = self.script.mutator.GetConfigurationFloat("stimHeal")
	self.stimDuration = self.script.mutator.GetConfigurationFloat("stimDuration")
	self.stimOverheal = self.script.mutator.GetConfigurationInt("stimOverheal")
	self.speedBoost = self.script.mutator.GetConfigurationFloat("speedBoost")
	self.doSpeedBoost = self.script.mutator.GetConfigurationBool("doStimSpeedBoost")
	self.speedBoostDuration = self.script.mutator.GetConfigurationFloat("speedBoostDuration")
	self.doVignette = self.script.mutator.GetConfigurationBool("doVignette")
	self.doFadeToBlack = self.script.mutator.GetConfigurationBool("doFadeToBlack")
	self.doStimFlash = self.script.mutator.GetConfigurationBool("doStimFlash")
	self.vignetteStyle = self.script.mutator.GetConfigurationDropdown("vignetteStyle")

	self.bandageDoOverHeal = self.script.mutator.GetConfigurationBool("bandageDoOverHeal")
	self.bandageDoSpeedBoost = self.script.mutator.GetConfigurationBool("bandageDoSpeedBoost")

	self.dataContainer = self.gameObject.GetComponent(DataContainer)

	self.healTimer = 0

	self.image = self.targets.Flash

	self.healIntervalTimer = 0
	self.playerActor = Player.actor
	self.playerActor.maxHealth = self.maxHP

	if self.isPercent then
		self.healValue = (self.healValue/100) * self.maxHP
	end

	self.isStimmed = false
	self.stimTimer = 0

	
	self.speedBoostTimer = 0
	self.isSpeedBoosted = false

	self.overHealMax = self.maxHP + self.stimOverheal
	self.overHealCap = self.overHealMax
	self.stimHealAmount = self.stimHeal * self.stimDuration * 10
	self.stimHealPerSecond = self.stimHeal * 10

	print("<color=green>[Enhanced Health] Stims will heal " .. self.stimHealAmount .. " health points</color>")
	print("<color=green>[Enhanced Health] Set player max health to " .. self.maxHP .. " HP</color>")
	
	self.targets.AudioSource.SetOutputAudioMixer(AudioMixer.FirstPerson)
	self.targets.Heartbeat.SetOutputAudioMixer(AudioMixer.FirstPerson)

	self.fadeAlpha = 0
	self.hasSpawned = false

	if(self.doVignette) then
		if(self.vignetteStyle == 0) then
			self.targets.Vignette.sprite = self.dataContainer.GetSprite("LowIntensityVignette")
		elseif(self.vignetteStyle == 1) then
			self.targets.Vignette.sprite = self.dataContainer.GetSprite("MediumIntensityVignette")
		elseif(self.vignetteStyle == 2) then
			self.targets.Vignette.sprite = self.dataContainer.GetSprite("HighIntensityVignette")
		end
	end

	self.targets.FadeToBlack.gameObject.SetActive(self.doFadeToBlack)
	self.targets.Vignette.gameObject.SetActive(self.doVignette)
	self.image.gameObject.SetActive(self.doStimFlash)

	self.startFade = false

	self.isSpawnUiOpen = false

	self.heartBeatTimer = 0

	enhancedHealthInstance = self
	self.script.AddValueMonitor("monitorHUDVisibility", "onHUDVisibilityChange")
end



function EnhancedHealth:Update()
	-- Run every frame
	if self.playerActor and self.playerActor.isDead == false then

		--[[if(Input.GetKeyDown(KeyCode.T)) then
			Player.actor.damage(Player.actor,50,0, false ,false)
		end]]--

		if SpawnUi.isOpen and not self.isSpawnUiOpen then
			self.isSpawnUiOpen = true
		elseif not SpawnUi.isOpen and self.isSpawnUiOpen then
			self.isSpawnUiOpen = false
			self:EvaluateLoadout()
		end

		if self.playerActor.health/self.maxHP <= 0.35 and self.heartBeatTimer <= 0 then
			self.heartBeatTimer = 1
			self.targets.Heartbeat.Play()
		else
			self.heartBeatTimer = self.heartBeatTimer - Time.deltaTime
		end


		if self.doRegen then
			if(self.healTimer > self.healDelay and self.playerActor.health < self.maxHP) then
				if(self.healIntervalTimer < self.healInterval) then
					self.healIntervalTimer = self.healIntervalTimer + Time.deltaTime
				else
					if(self.healInterval > 0) then
						self.playerActor.health = self.playerActor.health + self.healValue
					elseif(self.healInterval <= 0) then
						self.playerActor.health = self.playerActor.health + (10 * self.healValue * Time.deltaTime)
					end
					self.playerActor.health = Mathf.Clamp(self.playerActor.health,0, self.maxHP)
					self.healIntervalTimer = 0
				end
			elseif self.healTimer <= self.healDelay and self.playerActor.health < self.maxHP then
				self.healTimer = self.healTimer + (1 * Time.deltaTime)
			end
		end
	
		if self.isStimmed and self.stimTimer <= self.stimDuration then
			self.stimTimer = self.stimTimer + Time.deltaTime
			if self.playerActor.health < self.overHealMax then
				self.playerActor.health = self.playerActor.health + (self.stimHealPerSecond * Time.deltaTime)
				self.playerActor.health = Mathf.Clamp(self.playerActor.health,0, self.overHealMax)
			end
			if(self.stimTimer > self.stimDuration) then
				print("<color=yellow>[Enhanced Health] Stim regen done!</color>")
				self.stimTimer = 0
				self.isStimmed = false
			end
		end

		if self.isSpeedBoosted and self.speedBoostTimer <= self.speedBoostTimer then
			self.speedBoostTimer = self.speedBoostTimer + Time.deltaTime
			self.playerActor.speedMultiplier = self.speedBoost
			if(self.speedBoostTimer > self.speedBoostDuration) then
				print("<color=yellow>[Enhanced Health] Speed boost over!</color>")
				self.playerActor.speedMultiplier = 1
				self.isSpeedBoosted = false
			end
		end

		if(self.playerActor.maxHealth > self.maxHP and self.isStimmed == false) then
			self.playerActor.maxHealth = self.playerActor.health
			self.playerActor.maxHealth = Mathf.Clamp(self.playerActor.maxHealth, self.maxHP , self.overHealCap)
		end
		if(self.doVignette) then
			local scale = 1 - (self.playerActor.health/self.maxHP)
			scale = Mathf.Clamp(scale,0,1);
			self:updateVignette(scale)
		end
	elseif self.doFadeToBlack and self.playerActor and self.playerActor.isDead and self.hasSpawned and self.startFade then
		self:FadeToBlack(0.30)
	end
end

function EnhancedHealth:OnDisable()
	enhancedHealthInstance = nil
end

function EnhancedHealth:updateVignette(scale)
	local color = self.targets.Vignette.color
	color.a = scale
	self.targets.Vignette.color = color
end

function EnhancedHealth:onTakeDamage(actor,source,info)
	if(CurrentEvent.isConsumed) then
		return
	end
	
	self.healTimer = 0
	self.healIntervalTimer = 0

	local healthAfterEvent = self.playerActor.health - info.healthDamage
	local balanceAfterEvent = self.playerActor.balance - info.balanceDamage
	
	if(self.doVignette) then
		local scale = 1 - (healthAfterEvent/self.maxHP)
		scale = Mathf.Clamp(scale,0,1);
		self:updateVignette(scale)
	end

	--If health after this event is lower than true max HP, set current max HP to true max HP
	if(healthAfterEvent <= self.maxHP and self.playerActor.maxHealth > self.maxHP) then
		self.playerActor.maxHealth = self.maxHP
	end

	if(balanceAfterEvent <= 100 and self.playerActor.maxBalance == 200) then
		self.playerActor.maxBalance = 100
	end
end

function EnhancedHealth:onActorSpawn(actor)
	if(actor == self.playerActor) then
		self.healTimer = 0
		self.healIntervalTimer = 0
		self.playerActor.health = self.maxHP
		self.playerActor.maxBalance = 100
		if(self.doVignette) then
			self:updateVignette(0)
		end

		if(self.doFadeToBlack) then
			local color = self.targets.FadeToBlack.color
			color.a = 0
			self.targets.FadeToBlack.color = color
			self.fadeAlpha = 0
		end

		self:EvaluateLoadout()

		self.hasSpawned = true
		self.startFade = false
	end
end

function EnhancedHealth:EvaluateLoadout()
	for i, weapon in ipairs(Player.actor.weaponSlots) do
		if(weapon.weaponEntry.name == "Bandage") then
			weapon.onFire.AddListener(self,"onBandage",weapon)
		end
	end
end

function EnhancedHealth:addBandageListener(bandage)
	bandage.onFire.AddListener(self,"onBandage", bandage)
end

function EnhancedHealth:onBandage()
	CurrentEvent.Consume()
	local bandage = CurrentEvent.listenerData
	bandage.ammo = bandage.ammo - 1
	self:onStim(false, self.bandageDoOverHeal, self.bandageDoSpeedBoost)
end

function EnhancedHealth:onActorDied(actor,source,isSilent)
	if(actor.isPlayer) then
		self.playerActor.speedMultiplier = 1
		self.isStimmed = false
		if(self.doVignette) then
			self:updateVignette(1)
		end

		local color = self.image.color
		color.a = 0
		self.image.color = color

		if(self.doFadeToBlack) then
			self.startFade = false
			local color = self.targets.FadeToBlack.color
			color.a = 0
			self.targets.FadeToBlack.color = color
			self.fadeAlpha = 0
			self.script.StartCoroutine(self:fadeDelay(3.5))
		end
	end
end

function EnhancedHealth:fadeDelay(delay)
	return function()
        coroutine.yield(WaitForSeconds(delay))
		if(self.playerActor.isDead) then
			self.startFade = true
		end
    end
end

function EnhancedHealth:addListener(weapon)
	weapon.onFire.AddListener(self,"onStim")
end

function EnhancedHealth:FadeToBlack(fadeSpeed)
	if self.playerActor.isDead and self.fadeAlpha <= 1.0 then
		self.fadeAlpha = self.fadeAlpha + (fadeSpeed * Time.deltaTime)
		local color = self.targets.FadeToBlack.color
		color.a = self.fadeAlpha
		self.targets.FadeToBlack.color = color
	end
end

function EnhancedHealth:onStim(doSound, doOverheal, doSpeedBoost)

	self.isStimmed = true
	self.stimTimer = 0

	self.playerActor.maxBalance = 200
	self.playerActor.balance = 200

	if doOverheal then
		local healthAfterStim = self.playerActor.health + self.stimHealAmount
		--if health after stim > current maxHP then we do overheal behavior
		if healthAfterStim > self.playerActor.maxHealth then
			self.overHealMax = healthAfterStim
			self.overHealMax = Mathf.Clamp(self.overHealMax, 0, self.overHealCap)
			self.playerActor.maxHealth = self.overHealMax
		end
	else
		self.overHealMax = self.playerActor.maxHealth
	end
	

	if doSpeedBoost then
		self.speedBoostTimer = 0
		self.playerActor.speedMultiplier = self.speedBoost
		self.isSpeedBoosted = true
	end
	
	if doSound then
		self.targets.AudioSource.Play()
	end

	if(self.doStimFlash) then
		self.image.CrossFadeAlpha(1,0,false)
		local color = self.image.color
		color.a = 0.19
		self.image.color = color
		self.image.CrossFadeAlpha(0,1,false)
	end
end

function EnhancedHealth:monitorHUDVisibility()
	return GameManager.hudPlayerEnabled
end

function EnhancedHealth:onHUDVisibilityChange()
	self.targets.Canvas.SetActive(GameManager.hudPlayerEnabled)
end
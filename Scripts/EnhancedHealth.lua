-- Register the behaviour
behaviour("EnhancedHealth")

enhancedHealthInstance = nil

function EnhancedHealth:Awake()
	self.gameObject.name = "EnhancedHealth"
end

function EnhancedHealth:Init(config, visualConfigs)
	self:SetConfig(config)
	self:SetVisualConfigs(visualConfigs)

	local damageSystemObj = self.gameObject.Find("DamageCore")
	if damageSystemObj then
		self.damageSystem = damageSystemObj.GetComponent(ScriptedBehaviour)
		self.damageSystem.self:AddListener("PostCalculation", Player.actor, self,self:OnPostDamageCalculation())
	else
		Player.actor.onTakeDamage.AddListener(self,"onTakeDamage")
	end
	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")
	GameEvents.onActorDied.AddListener(self,"onActorDied")


	self.dataContainer = self.gameObject.GetComponent(DataContainer)

	local movementCoreObj = self.gameObject.Find("MovementCore")
	if movementCoreObj then
		self.movementCore = movementCoreObj.GetComponent(ScriptedBehaviour)
	end

	self.healTimer = 0

	self.image = self.targets.Flash
	
	self.isStimmed = false
	self.stimTimer = 0

	self.speedBoostTimer = 0
	self.isSpeedBoosted = false

	self:InitStats()
	
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

	self.colorGradeCurve = self.dataContainer.GetAnimationCurve("ColorGradingCurve")

	self.targets.LowHealthEffect.gameObject.SetActive(self.doColorGrading)

	self.startFade = false

	self.isSpawnUiOpen = false

	self.heartBeatTimer = 0

	enhancedHealthInstance = self
	self.script.AddValueMonitor("monitorHUDVisibility", "onHUDVisibilityChange")

	self.allowRegen = true
	self.bandageHealPercent = 1

	self.version = 5
end

function EnhancedHealth:InitStats()
	self.playerActor = Player.actor
	self.playerActor.maxHealth = self.maxHP
	self.HPT = self.maxHP * self.percentHpPerTick

	self.overHealMax = self.maxHP + self.stimOverheal
	self.overHealCap = self.overHealMax
	self.stimHealAmount = self.stimHeal * self.stimDuration * 10
	self.stimHealPerSecond = self.stimHeal * 10

	self.heartBeatThreshold = self.maxHP * 0.5
end

function EnhancedHealth:SetConfig(config)
	self.healDelay = config.healDelay
	self.percentHpPerTick = config.percentHpPerTick/100
	self.maxHP = config.maxHP
	self.doRegen = config.doRegen
	self.doQuickAnim = false
	self.stimHeal = config.stimHeal
	self.stimDuration = config.stimDuration
	self.stimOverheal = config.stimOverheal
	self.speedBoost = config.speedBoost
	self.doSpeedBoost = config.doSpeedBoost
	self.speedBoostDuration = config.speedBoostDuration
	self.regenCap = config.regenCap * self.maxHP
	self.bandageDoOverHeal = config.bandageDoOverHeal
	self.bandageDoSpeedBoost = config.bandageDoSpeedBoost
	self.maxBalance = config.maxBalance
	
	self:InitStats()
end

function EnhancedHealth:SetVisualConfigs(config)
	if config == nil then
		self.doVignette = true
		self.doFadeToBlack = true
		self.doStimFlash = true
		self.vignetteStyle = 1
		self.doColorGrading = true
		self.colorGradingIntensity = 1

		print("Visual configs are nil!")
		return
	end

	if config.doVignette ~= nil then
		self.doVignette = config.doVignette
	else
		self.doVignette = true
	end
	
	if config.doFadeToBlack ~= nil then
		self.doFadeToBlack = config.doFadeToBlack
	else
		self.doFadeToBlack = true
	end

	if config.doStimFlash ~= nil then
		self.doStimFlash = config.doStimFlash
	else
		self.doStimFlash = true
	end

	if config.doColorGrading ~= nil then
		self.doColorGrading = config.doColorGrading
	else
		self.doColorGrading = true
	end

	self.vignetteStyle = config.vignetteStyle or 1
	self.colorGradingIntensity = config.colorGradingIntensity or 1
end

function EnhancedHealth:Update()
	-- Run every frame
	if self.playerActor and self.playerActor.isDead == false then

		--[[if(Input.GetKeyDown(KeyCode.T)) then
			Player.actor.damage(Player.actor,5,0, false ,false)
		end]]--

		if SpawnUi.isOpen and not self.isSpawnUiOpen then
			self.isSpawnUiOpen = true
		elseif not SpawnUi.isOpen and self.isSpawnUiOpen then
			self.isSpawnUiOpen = false
			self:EvaluateLoadout()
		end

		self:HealthRegen()
		self:SpeedBoost()
		self:Heartbeat()

		if(self.playerActor.maxHealth > self.maxHP and self.isStimmed == false) then
			self.playerActor.maxHealth = self.playerActor.health
			self.playerActor.maxHealth = Mathf.Clamp(self.playerActor.maxHealth, self.maxHP , self.overHealCap)
		end
		if self.doVignette then
			local scale = self.playerActor.health/self.maxHP
			scale = Mathf.Clamp(scale,0,1);
			if scale < 1 then
				local pingPong = Mathf.PingPong(Time.time * 0.25,0.25)
				scale = scale + pingPong
			end
			self:updateVignette(scale)
		end
	elseif self.doFadeToBlack and self.playerActor and self.playerActor.isDead and self.hasSpawned and self.startFade then
		self:FadeToBlack(0.3)
	end

	if Player.actor and self.doColorGrading and not Player.actor.isDead then
		local intensity = self.colorGradeCurve.Evaluate(1 - Player.actor.health/self.maxHP) * self.colorGradingIntensity
		self.targets.LowHealthEffect.SetFloat("HealthScale", intensity)
	end
end

function EnhancedHealth:OnDisable()
	enhancedHealthInstance = nil
end

function EnhancedHealth:updateVignette(scale)
	local color = self.targets.Vignette.color
	color.a = 1 - scale
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
		local scale = healthAfterEvent/self.maxHP
		scale = Mathf.Clamp(scale,0,1);
		self:updateVignette(scale)
	end

	--If health after this event is lower than true max HP, set current max HP to true max HP
	if(healthAfterEvent <= self.maxHP and self.playerActor.maxHealth > self.maxHP) then
		self.playerActor.maxHealth = self.maxHP
	end

	if(balanceAfterEvent <= self.maxBalance and self.playerActor.maxBalance == self.maxBalance * 2) then
		self.playerActor.maxBalance = self.maxBalance
	end

	self.targets.DamageEffect.SetTrigger("Damage")
end

function EnhancedHealth:OnPostDamageCalculation()
	return function(actor,source,info)
		self.healTimer = 0
		self.healIntervalTimer = 0
	
		local healthAfterEvent = self.playerActor.health - info.healthDamage
		local balanceAfterEvent = self.playerActor.balance - info.balanceDamage
		
		if(self.doVignette) then
			local scale = healthAfterEvent/self.maxHP
			scale = Mathf.Clamp(scale,0,1);
			self:updateVignette(scale)
		end
	
		--If health after this event is lower than true max HP, set current max HP to true max HP
		if(healthAfterEvent <= self.maxHP and self.playerActor.maxHealth > self.maxHP) then
			self.playerActor.maxHealth = self.maxHP
		end
	
		if(balanceAfterEvent <= self.maxBalance and self.playerActor.maxBalance == self.maxBalance * 2) then
			self.playerActor.maxBalance = self.maxBalance
		end
	
		self.targets.DamageEffect.SetTrigger("Damage")
	end
end

function EnhancedHealth:HealthRegen()
	if Player.actor.isFallenOver then return end

	if self.doRegen and self.allowRegen then
		if(self.healTimer > self.healDelay and self.playerActor.health < self.regenCap) then
			self.playerActor.health = self.playerActor.health + (self.HPT * Time.deltaTime)
			self.playerActor.health = Mathf.Clamp(self.playerActor.health,0, self.regenCap)
		elseif self.healTimer <= self.healDelay and self.playerActor.health < self.regenCap then
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
end

function EnhancedHealth:SpeedBoost()
	if self.isSpeedBoosted and self.speedBoostTimer <= self.speedBoostTimer then
		self.speedBoostTimer = self.speedBoostTimer + Time.deltaTime
		--self.playerActor.speedMultiplier = self.speedBoost
		if(self.speedBoostTimer > self.speedBoostDuration) then
			print("<color=yellow>[Enhanced Health] Speed boost over!</color>")
			if self.movementCore then
				self.movementCore.self:RemoveModifier(Player.actor, "StimShot")
			else
				self.playerActor.speedMultiplier = 1
			end
			self.isSpeedBoosted = false
		end
	end
end

function EnhancedHealth:onActorSpawn(actor)
	if(actor == self.playerActor) then
		self.healTimer = 0
		self.healIntervalTimer = 0
		self.playerActor.health = self.maxHP
		self.playerActor.maxBalance = self.maxBalance

		self:ClearScreenEffects()

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
	self:InstantHeal(self.bandageHealPercent)
end

function EnhancedHealth:InstantHeal(percentRestored)
	local healAmount = self.maxHP * percentRestored

	Player.actor.health = Player.actor.health + healAmount
	if Player.actor.health > Player.actor.maxHealth then
		Player.actor.health = Player.actor.maxHealth
	end

	if(self.doStimFlash) then
		self.targets.StimEffect.SetTrigger("Stim")
	end
end

function EnhancedHealth:onActorDied(actor,source,isSilent)
	if(actor.isPlayer) then
		self.playerActor.speedMultiplier = 1
		self.isStimmed = false
		if(self.doVignette) then
			self:updateVignette(0)
		end

		if self.doColorGrading then
			self.targets.LowHealthEffect.SetFloat("HealthScale", 1)
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

	self.playerActor.maxBalance = self.maxBalance * 2
	self.playerActor.balance = self.maxBalance * 2

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
		if self.movementCore then
			self.movementCore.self:AddModifier(Player.actor, "StimShot", self.speedBoost)
		else
			self.playerActor.speedMultiplier = self.speedBoost
		end
		
		
		self.isSpeedBoosted = true
	end
	
	if doSound then
		self.targets.AudioSource.Play()
	end

	if(self.doStimFlash) then
		self.targets.StimEffect.SetTrigger("Stim")
	end
end

function EnhancedHealth:monitorHUDVisibility()
	return GameManager.hudPlayerEnabled
end

function EnhancedHealth:onHUDVisibilityChange()
	self.targets.Canvas.SetActive(GameManager.hudPlayerEnabled)
end

function EnhancedHealth:Heartbeat()
	if self.playerActor.health <= self.heartBeatThreshold and self.heartBeatTimer <= 0 then
		self.heartBeatTimer = 1
		local t = self.playerActor.health / self.heartBeatThreshold
		self.targets.Heartbeat.volume = 1 - t
		self.targets.Heartbeat.Play()
	else
		self.heartBeatTimer = self.heartBeatTimer - Time.deltaTime
	end
end

function EnhancedHealth:ClearScreenEffects()
	self.startFade = false
	local color = self.targets.FadeToBlack.color
	color.a = 0
	self.targets.FadeToBlack.color = color
	self:updateVignette(1)
	self.targets.LowHealthEffect.SetFloat("HealthScale", 0)
end
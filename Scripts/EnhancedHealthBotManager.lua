-- Register the behaviour
behaviour("EnhancedHealthBotManager")

EHSBehaviour = {actor = nil, maxHp = 0, healDelay = 0, percentHpPerTick = 0, regenCap = 0, HPT = 0}

function EHSBehaviour:new(actor, maxHP, maxBalance, healDelay, percentHpPerTick, regenCap)
	local instance = {actor = actor}
	instance.maxHP = maxHP or 100
	instance.healTimer = 0
	instance.healDelay = healDelay or 2
	instance.HPT = instance.maxHP * percentHpPerTick
	instance.regenCap = regenCap or instance.maxHP
	actor.maxHealth = maxHP
	actor.maxBalance = maxBalance
	return setmetatable(instance, {__index = EHSBehaviour})
end

function EHSBehaviour:update()
	if self.actor.isDead then return end

	if(self.healTimer > self.healDelay and self.actor.health < self.regenCap) then
		self.actor.health = self.actor.health + (self.HPT * Time.deltaTime)
		self.actor.health = Mathf.Clamp(self.actor.health,0, self.regenCap)
	elseif self.healTimer <= self.healDelay and self.actor.health < self.regenCap then
		self.healTimer = self.healTimer + Time.deltaTime
	end
end

function EHSBehaviour:onDamage()
	self:resetTimer()
end

function EHSBehaviour:resetTimer()
	self.healTimer = 0
end

function EnhancedHealthBotManager:Init(config)
	self:SetConfig(config)

	local damageSystemObj = self.gameObject.Find("DamageCore")
	if damageSystemObj then
		self.damageSystem = damageSystemObj.GetComponent(ScriptedBehaviour)
		for i = 1, #ActorManager.actors, 1 do
			local actor = ActorManager.actors[i]
			if not actor.isPlayer then
				self.damageSystem.self:AddListener("PostCalculation", actor, self,self:OnPostDamageCalculation())
			end
		end
	else
		for i = 1, #ActorManager.actors, 1 do
			local actor = ActorManager.actors[i]
			if not actor.isPlayer then
				actor.onTakeDamage.AddListener(self,"onTakeDamage")
			end	
		end
	end
	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")

	self.botBehaviours = {}
	self.botDictionary = {}

	self.version = 1

	self.init = true
end

function EnhancedHealthBotManager:SetConfig(config)
	self.affectsBots = config.affectsBots or false
	self.botMaxHealth = config.botMaxHealth or 100
	self.botMaxBalance = config.botMaxBalance or 100
	self.botHealDelay = config.botHealDelay or 2
	self.botPercentHpPerTick = (config.botPercentHpPerTick/100) or 10
	self.botRegenCap = (config.botRegenCap * self.botMaxHealth) or 100
end

function EnhancedHealthBotManager:Update()
	if not self.init then return end

	for i = 1, #self.botBehaviours, 1 do
		local botBehaviour = self.botBehaviours[i]
		if botBehaviour then
			botBehaviour:update()
		end
	end
end

function EnhancedHealthBotManager:OnPostDamageCalculation()
	return function(actor,source,info)
		if not actor.isPlayer then
			local botBehaviour = self.botDictionary[actor.actorIndex]
			if botBehaviour then
				botBehaviour:onDamage()
			end
			return
		end
	end
end

function EnhancedHealthBotManager:onTakeDamage(actor,source,info)
	if(CurrentEvent.isConsumed) then
		return
	end

	if not actor.isPlayer then
		local botBehaviour = self.botDictionary[actor.actorIndex]
		if botBehaviour then
			botBehaviour:onDamage()
		end
		return
	end
end

function EnhancedHealthBotManager:onActorSpawn(actor)
	if not actor.isPlayer then
		local behaviour = self.botDictionary[actor.actorIndex]
		if behaviour == nil then 
			behaviour = EHSBehaviour:new(actor, self.botMaxHealth, self.botMaxBalance, self.botHealDelay, self.botPercentHpPerTick,self.botRegenCap)
			table.insert(self.botBehaviours, 1, behaviour)
			self.botDictionary[actor.actorIndex] = behaviour
		else
			behaviour:resetTimer()
		end
	end
end
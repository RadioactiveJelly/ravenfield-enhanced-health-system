-- Register the behaviour
behaviour("EnhancedHealthDeployer")

function EnhancedHealthDeployer:Start()
	local mainObject = GameObject.Instantiate(self.targets.MainBehaviour)
	local dataContainer = self.targets.DataContainer

	local mainConfig =
	{
		healDelay = self.script.mutator.GetConfigurationFloat("healDelay"),
		percentHpPerTick = self.script.mutator.GetConfigurationFloat("percentHpPerTick"),
		maxHP = self.script.mutator.GetConfigurationInt("maxHP"),
		doRegen = self.script.mutator.GetConfigurationBool("doRegen"),
		stimHeal = self.script.mutator.GetConfigurationFloat("stimHeal"),
		stimDuration = self.script.mutator.GetConfigurationFloat("stimDuration"),
		stimOverheal = self.script.mutator.GetConfigurationInt("stimOverheal"),
		speedBoost = self.script.mutator.GetConfigurationFloat("speedBoost"),
		doSpeedBoost = self.script.mutator.GetConfigurationBool("doStimSpeedBoost"),
		speedBoostDuration = self.script.mutator.GetConfigurationFloat("speedBoostDuration"),
		regenCap = self.script.mutator.GetConfigurationRange("regenCapPercent"),
		bandageDoOverHeal = self.script.mutator.GetConfigurationBool("bandageDoOverHeal"),
		bandageDoSpeedBoost = self.script.mutator.GetConfigurationBool("bandageDoSpeedBoost"),
		maxBalance = self.script.mutator.GetConfigurationInt("maxBalance")
	}
	
	local visualConfigs =
	{
		doVignette = self.script.mutator.GetConfigurationBool("doVignette"),
		doFadeToBlack = self.script.mutator.GetConfigurationBool("doFadeToBlack"),
		doStimFlash = self.script.mutator.GetConfigurationBool("doStimFlash"),
		vignetteStyle = self.script.mutator.GetConfigurationDropdown("vignetteStyle"),
		doColorGrading = self.script.mutator.GetConfigurationBool("doColorGrading"),
		colorGradingIntensity = self.script.mutator.GetConfigurationRange("colorGradingIntensity"),
	}
	
	local mainBehaviour = mainObject.GetComponent(EnhancedHealth)
	mainBehaviour:Init(mainConfig, visualConfigs)
end
package main

import (
	"eyelevel-setup-cli/config"
	"eyelevel-setup-cli/messages"
	"eyelevel-setup-cli/prepareLocalEnvironment"
	"eyelevel-setup-cli/terraform"
	"os"
)

func main() {
	messages.WelcomeMessage()

	cliConfig := config.NewCLIConfig()
	err := cliConfig.Run()

	if err != nil {
		os.Exit(1)
	}

	localEnv := prepareLocalEnvironment.NewPrepareLocalEnvironment()
	exitProgram := localEnv.Run()

	if exitProgram {
		return
	}

	t := terraform.NewTerraform()
	t.Run()
}

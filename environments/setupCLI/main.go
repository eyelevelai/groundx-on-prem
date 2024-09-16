package main

import (
	"eyelevel-setup-cli/messages"
	"eyelevel-setup-cli/prepareLocalEnvironment"
	"eyelevel-setup-cli/terraform"
)

func main() {
	messages.WelcomeMessage()

	localEnv := prepareLocalEnvironment.NewPrepareLocalEnvironment()
	exitProgram := localEnv.Run()

	if exitProgram {
		return
	}

	t := terraform.NewTerraform()
	t.Run()
}

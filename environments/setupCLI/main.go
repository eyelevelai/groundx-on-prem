package main

import (
	"eyelevel-setup-cli/config"
	"eyelevel-setup-cli/messages"
	"eyelevel-setup-cli/prepareLocalEnvironment"
	"eyelevel-setup-cli/terraform"
	"fmt"
	"os"
)

func main() {
	messages.WelcomeMessage()

	config, err := config.NewConfig()
	if err != nil {
		messages.ErrorMessage("Config", err.Error())
		os.Exit(1)
	}

	fmt.Println(config)

	localEnv := prepareLocalEnvironment.NewPrepareLocalEnvironment()
	exitProgram := localEnv.Run()

	if exitProgram {
		return
	}

	t := terraform.NewTerraform()
	t.Run()
}

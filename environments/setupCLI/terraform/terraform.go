package terraform

import (
	"fmt"

	"eyelevel-setup-cli/terraform/deployToAWS"

	"github.com/manifoldco/promptui"
)

type Terraform struct {
	platform string
}

func NewTerraform() Terraform {
	return Terraform{
		platform: "",
	}
}

func (t *Terraform) Run() {
	t.selectPlatform()
	t.deploy()
}

func (t *Terraform) selectPlatform() error {
	prompt := promptui.Select{
		Label: "Which platform would you like to deploy to?",
		Items: []string{"AWS", "Azure", "Google Cloud Platform", "OpenShift"},
	}

	_, result, err := prompt.Run()

	if err != nil {
		fmt.Printf("Prompt failed %v\n", err)
		return err
	}

	t.platform = result

	return nil
}

func (t *Terraform) deploy() error {
	switch t.platform {
	case "AWS":
		fmt.Println("Deploying to AWS")
		deplyToAws := deployToAWS.NewDeployToAWS()
		deplyToAws.Run()
	case "Azure":
		fmt.Println("Deploying to Azure")
	case "Google Cloud Platform":
		fmt.Println("Deploying to Google Cloud Platform")
	case "OpenShift":
		fmt.Println("Deploying to OpenShift")
	default:
		fmt.Println("Unknown platform")
	}
	return nil
}

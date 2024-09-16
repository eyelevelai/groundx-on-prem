package prepareLocalEnvironment

import (
	"fmt"

	"github.com/manifoldco/promptui"
)

func (p *PrepareLocalEnvironment) askToInstallTerraform() error {
	prompt := promptui.Select{
		Label: "Do I have your premission to install Terraform?",
		Items: []string{"Yes", "No"},
	}

	_, result, err := prompt.Run()

	if err != nil {
		fmt.Printf("Prompt failed %v\n", err)
		return err
	}

	if result == "Yes" {
		p.premissionToInstallTerraform = true
	} else {
		p.premissionToInstallTerraform = false
	}

	return nil
}

func (p *PrepareLocalEnvironment) askToInstallKubectl() error {
	prompt := promptui.Select{
		Label: "Do I have your premission to install Kubectl?",
		Items: []string{"Yes", "No"},
	}

	_, result, err := prompt.Run()

	if err != nil {
		fmt.Printf("Prompt failed %v\n", err)
		return err
	}

	if result == "Yes" {
		p.premissionToInstallKubectl = true
	} else {
		p.premissionToInstallKubectl = false
	}

	return nil
}

func (p *PrepareLocalEnvironment) askToInstallHelm() error {
	prompt := promptui.Select{
		Label: "Do I have your premission to install Helm?",
		Items: []string{"Yes", "No"},
	}

	_, result, err := prompt.Run()

	if err != nil {
		fmt.Printf("Prompt failed %v\n", err)
		return err
	}

	if result == "Yes" {
		p.premissionToInstallHelm = true
	} else {
		p.premissionToInstallHelm = false
	}

	return nil
}

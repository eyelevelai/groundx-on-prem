package deployToAWS

import (
	"github.com/manifoldco/promptui"
)

type awsConfig struct {
	accessKeyId     string
	secretAccessKey string
	region          string
	newVPC          bool
	internetAccess  bool
}

func NewAWSConfig() awsConfig {
	return awsConfig{}
}

func (a *awsConfig) Run() error {
	err := a.setAccessKeyId()

	if err != nil {
		return err
	}

	err = a.setSecretAccessKey()

	if err != nil {
		return err
	}

	err = a.setRegion()

	if err != nil {
		return err
	}

	err = a.setCreateNewVPC()

	if err != nil {
		return err
	}

	err = a.setInternetAccessible()

	if err != nil {
		return err
	}

	return nil
}

func (a *awsConfig) setAccessKeyId() error {
	validate := func(input string) error {
		return nil
	}

	prompt := promptui.Prompt{
		Label:    "AWS Access Key ID",
		Validate: validate,
	}

	result, err := prompt.Run()

	if err != nil {
		return err
	}

	a.accessKeyId = result

	return nil
}

func (a *awsConfig) setSecretAccessKey() error {
	validate := func(input string) error {
		return nil
	}

	prompt := promptui.Prompt{
		Label:    "AWS Secret Access Key",
		Validate: validate,
	}

	result, err := prompt.Run()

	if err != nil {
		return err
	}

	a.secretAccessKey = result

	return nil
}

func (a *awsConfig) setRegion() error {
	validReagion := []string{
		"us-east-2",
		"us-east-1",
		"us-west-1",
		"us-west-2",
		"af-south-1",
		"ap-east-1",
		"ap-south-2",
		"ap-southeast-3",
		"ap-southeast-5",
		"ap-southeast-4",
		"ap-south-1",
		"ap-northeast-3",
		"ap-northeast-2",
		"ap-southeast-1",
		"ap-southeast-2",
		"ap-northeast-1",
		"ca-central-1",
		"ca-west-1",
		"eu-central-1",
		"eu-west-1",
		"eu-west-2",
		"eu-south-1",
		"eu-west-3",
		"eu-south-2",
		"eu-north-1",
		"eu-central-2",
		"il-central-1",
		"me-south-1",
		"me-central-1",
		"sa-east-1",
		"us-gov-east-1",
		"us-gov-west-1",
	}

	prompt := promptui.Select{
		Label: "Select Region",
		Items: validReagion,
	}

	_, result, err := prompt.Run()

	if err != nil {
		return err
	}

	a.region = result

	return nil
}

func (a *awsConfig) setCreateNewVPC() error {
	prompt := promptui.Prompt{
		Label: "Create New VPC? (y/n)",
	}

	result, err := prompt.Run()

	if err != nil {
		return err
	}

	a.newVPC = result == "y"

	return nil
}

func (a *awsConfig) setInternetAccessible() error {
	prompt := promptui.Prompt{
		Label: "Do you want this deployment accessible via internet? (y/n)",
	}

	result, err := prompt.Run()

	if err != nil {
		return err
	}

	a.internetAccess = result == "y"

	return nil
}

package deployToAWS

import (
	"errors"
	"fmt"
	"os"

	"github.com/manifoldco/promptui"
)

type awsConfig struct {
	accessKeyId     string
	secretAccessKey string
	region          string
	newVPC          bool
	internetAccess  bool
	keyPairValid    bool
}

func NewAWSConfig() awsConfig {
	return awsConfig{}
}

func (a *awsConfig) Run() error {
	for {
		err := a.collectCredentials()
		if err != nil {
			fmt.Println("Error collecting credentials:", err)
			continue
		}

		err = a.verifyAccessKeyPair()
		if err != nil {
			continue
		}

		if a.keyPairValid {
			fmt.Println("Key pair is valid.")
			break
		}
	}

	err := a.collectRegion()
	if err != nil {
		fmt.Println("Error selecting region:", err)
	}

	err = a.collectVPCConfig()
	if err != nil {
		fmt.Println("Error configuring VPC:", err)
	}

	err = a.collectInternetAccess()
	if err != nil {
		fmt.Println("Error configuring internet access:", err)
	}

	return nil
}

func (a *awsConfig) collectCredentials() error {
	if err := a.promptInput("AWS Access Key ID", &a.accessKeyId); err != nil {
		return err
	}

	if err := a.promptInput("AWS Secret Access Key", &a.secretAccessKey); err != nil {
		return err
	}

	return nil
}

func (a *awsConfig) collectRegion() error {
	validRegion := []string{
		"us-east-2", "us-east-1", "us-west-1", "us-west-2",
	}

	prompt := promptui.Select{
		Label: "Select AWS Region",
		Items: validRegion,
	}

	_, result, err := prompt.Run()
	if err != nil {
		return err
	}

	a.region = result
	return nil
}

func (a *awsConfig) collectVPCConfig() error {
	return a.promptYesNo("Create New VPC?", &a.newVPC)
}

func (a *awsConfig) collectInternetAccess() error {
	return a.promptYesNo("Do you want this deployment accessible via internet?", &a.internetAccess)
}

func (a *awsConfig) verifyAccessKeyPair() error {
	verificationClient := newVerifyAccessKeyPair(a.accessKeyId, a.secretAccessKey, a.region)
	keyPairIsValid, err := verificationClient.Run()
	if err != nil {

		return fmt.Errorf("access key pair verification failed")
	}
	a.keyPairValid = keyPairIsValid

	fmt.Println("The key pair provided is lacking the necessary permissions:")
	for _, accessLacking := range verificationClient.lackingPermissions {
		fmt.Println("  -", accessLacking)
	}

	return nil
}

func (a *awsConfig) promptInput(label string, result *string) error {
	validate := func(input string) error {
		if input == "" {
			return errors.New("input cannot be empty")
		}
		return nil
	}

	prompt := promptui.Prompt{
		Label:    label,
		Validate: validate,
	}

	input, err := prompt.Run()
	if err != nil {
		return err
	}

	if input == "exit" {
		os.Exit(0)
	}

	*result = input
	return nil
}

func (a *awsConfig) promptYesNo(label string, result *bool) error {
	prompt := promptui.Prompt{
		Label: label + " (y/n)",
	}

	input, err := prompt.Run()
	if err != nil {
		return err
	}

	*result = input == "y"
	return nil
}

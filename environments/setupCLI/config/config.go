package config

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/manifoldco/promptui"
	"gopkg.in/yaml.v2"
)

type CLIConfig struct {
	DeployPlatform       string `yaml:"deployPlatform"`
	ResetExistingProject bool   `yaml:"resetExistingProject"`
	ProjectConfiguration struct {
		CreateEverything bool `yaml:"createEverything"`
	} `yaml:"projectConfiguration"`
	AwsDeploymentConfiguration struct {
		Region      string `yaml:"region"`
		Credentials struct {
			AccessKeyID     string `yaml:"accessKeyID"`
			SecretAccessKey string `yaml:"secretAccessKey"`
		} `yaml:"credentials"`
	} `yaml:"awsDeploymentConfiguration"`
	TerraformConfiguration struct {
		Backend struct {
			Path string `yaml:"path"`
		} `yaml:"backend"`
		Project struct {
			ProjectPath struct {
				Path        string `yaml:"path"`
				FromScratch string `yaml:"fromScratch"`
				EksOnly     string `yaml:"eksOnly"`
			} `yaml:"projectPath"`
		} `yaml:"project"`
	} `yaml:"terraformConfiguration"`
}

func NewCLIConfig() CLIConfig {
	return CLIConfig{}
}

func (c *CLIConfig) Run() error {
	err := c.readFileContent()
	if err != nil {
		return errors.New("Error reading config file")
	}

	c.PrintCLIConfig()

	proceed := c.askToConfirmConfig()

	if !proceed {
		return errors.New("User did not confirm configuration")
	}

	return nil
}

func (c *CLIConfig) readFileContent() error {
	var config CLIConfig
	fileContent, err := os.Open("./config/config.yaml")
	if err != nil {
		return errors.New("Config file not found")
	}

	defer fileContent.Close()

	decoder := yaml.NewDecoder(fileContent)
	err = decoder.Decode(&config)
	if err != nil {
		return errors.New("Error decoding config file")
	}

	*c = config

	return nil
}

func (c *CLIConfig) askToConfirmConfig() bool {
	prompt := promptui.Prompt{
		Label:     "Do you want to proceed with this configuration?",
		IsConfirm: true,
	}

	_, err := prompt.Run()
	if err != nil {
		return false
	}

	return true
}

func (c *CLIConfig) PrintCLIConfig() {
	prettyConfig, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		fmt.Println("Error formatting config:", err)
		return
	}
	fmt.Println(string(prettyConfig))
}

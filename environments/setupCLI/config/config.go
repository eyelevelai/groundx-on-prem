package config

import (
	"errors"
	"os"

	"gopkg.in/yaml.v2"
)

type Config struct {
	DeployPlatform        string `yaml:"deployPlatform"`
	DeployRegion          string `yaml:"deployRegion"`
	DeploymentCredentials struct {
		AccessKeyID     string `yaml:"accessKeyID"`
		SecretAccessKey string `yaml:"secretAccessKey"`
	} `yaml:"deploymentCredentials"`
}

func NewConfig() (Config, error) {
	var config Config
	fileContent, err := os.Open("./config/config.yaml")
	if err != nil {
		return Config{}, errors.New("Config file not found")
	}

	defer fileContent.Close()

	decoder := yaml.NewDecoder(fileContent)
	err = decoder.Decode(&config)
	if err != nil {
		return Config{}, errors.New("Error decoding config file")
	}

	return config, nil
}

package deployToAWS

import (
	"fmt"
	"os"
)

type createVariableFile struct {
	awsConfig          awsConfig
	terraformDirectory string
}

func NewCreateVariableFile(awsConfig awsConfig) createVariableFile {
	terraformPath := ""
	if awsConfig.newVPC {
		terraformPath = "./terraform/deployToAWS/from-scratch"
	} else {
		terraformPath = "./terraform/deployToAWS/eks-only"
	}
	return createVariableFile{
		awsConfig:          awsConfig,
		terraformDirectory: terraformPath,
	}
}

func (c *createVariableFile) Run() {
	fileExist := c.checkIfFileExist()
	if fileExist {
		c.deleteFile()
	}

	c.createFile()

	fmt.Println("File written successfully", c.terraformDirectory+"/terraform.tfvars")
}

func (c *createVariableFile) checkIfFileExist() bool {
	_, err := os.Stat(c.terraformDirectory + "/terraform.tfvars")
	return !os.IsNotExist(err)
}

func (c *createVariableFile) deleteFile() {
	err := os.Remove(c.terraformDirectory + "/terraform.tfvars")
	if err != nil {
		fmt.Println("Error deleting file", err)
	}
}

func (c *createVariableFile) createFile() {
	content := fmt.Sprintf("region = \"%s\"\nvpc_cidr_block = \"10.0.0.0/16\"\npublic_subnet_cidr = \"10.0.1.0/24\"\nprivate_subnet_cidr = \"10.0.2.0/24\"\ninternet_accessible = %t\naws_access_key = \"%s\"\naws_secret_key = \"%s\"\n",
		c.awsConfig.region,
		c.awsConfig.internetAccess,
		c.awsConfig.accessKeyId,
		c.awsConfig.secretAccessKey)

	data := []byte(content)
	fileName := c.terraformDirectory + "/terraform.tfvars"

	file, err := os.Create(fileName)
	if err != nil {
		fmt.Println("Error creating file", err)
		return
	}

	defer file.Close()

	_, err = file.Write(data)
	if err != nil {
		fmt.Println("Error writing to file", err)
		return
	}
}

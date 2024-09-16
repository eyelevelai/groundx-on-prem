package deployToAWS

import (
	"fmt"
)

type deployToAWS struct {
	awsConfig awsConfig
}

func NewDeployToAWS() deployToAWS {
	return deployToAWS{
		awsConfig: NewAWSConfig(),
	}
}

func (d *deployToAWS) Run() {
	err := d.awsConfig.Run()

	if err != nil {
		fmt.Println("Error setting up AWS config")
		fmt.Println(err)
		return
	}

	createVariableFile := NewCreateVariableFile(d.awsConfig)
	createVariableFile.Run()

	terraformWorkflow := newTerraformWorkflow(createVariableFile.terraformDirectory)
	terraformWorkflow.Run()
}

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

	checkForExistingProjects := newCheckForExistingProject(d.awsConfig)
	resultStatus, err := checkForExistingProjects.Run()

	if err != nil {
		fmt.Println("Error checking for existing project")
		fmt.Println(err)
		return
	}

	if resultStatus == abort {
		fmt.Println("Aborting")
		return
	}

	if resultStatus == reset {
		resetTerrafromProject := newResetTerrafromProject(d.awsConfig)
		resultStatus, err = resetTerrafromProject.Run()
		if resultStatus == abort {
			return
		}

		if err != nil {
			fmt.Println("Error resetting project")
			fmt.Println(err)
		}
		return
	}

	// createVariableFile := NewCreateVariableFile(d.awsConfig)
	// createVariableFile.Run()

	// terraformWorkflow := newTerraformWorkflow(createVariableFile.terraformDirectory)
	// terraformWorkflow.Run()
}

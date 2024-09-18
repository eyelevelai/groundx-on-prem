package deployToAWS

import (
	"os"
	"path/filepath"

	"github.com/manifoldco/promptui"
)

type checkForExistingProject struct {
	terraformDirectory     string
	filesAndSubdirectories []string
	projectExist           bool
	resultStatus           projectProceedState
}

func newCheckForExistingProject(awsConfig awsConfig) checkForExistingProject {
	terraformPath := ""
	if awsConfig.newVPC {
		terraformPath = "./terraform/deployToAWS/from-scratch"
	} else {
		terraformPath = "./terraform/deployToAWS/eks-only"
	}
	return checkForExistingProject{
		terraformDirectory:     terraformPath,
		filesAndSubdirectories: []string{},
		projectExist:           false,
	}
}

func (c *checkForExistingProject) Run() (resultStatus projectProceedState, errorMessage error) {
	err := c.listFilesAndDirectories()
	if err != nil {
		return abort, err
	}

	err = c.checkIfProjectInit()
	if err != nil {
		return abort, err
	}

	if !c.projectExist {
		return proceed, nil
	}

	err = c.askToRestart()
	if err != nil {
		return abort, err
	}

	return c.resultStatus, nil
}

func (c *checkForExistingProject) listFilesAndDirectories() error {
	var fileList []string
	err := filepath.Walk(c.terraformDirectory, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if path == c.terraformDirectory {
			return nil
		}
		fileList = append(fileList, path)
		return nil
	})

	if err != nil {
		return err
	}

	c.filesAndSubdirectories = fileList
	return nil
}

func (c *checkForExistingProject) checkIfProjectInit() error {
	tfFileCount := 0

	for _, file := range c.filesAndSubdirectories {
		if filepath.Ext(file) == ".tf" {
			tfFileCount++
		}
	}

	c.projectExist = tfFileCount < len(c.filesAndSubdirectories)

	return nil
}

func (c *checkForExistingProject) askToRestart() error {
	prompt := promptui.Select{
		Label: "Project already exists. Do you want to restart the project?",
		Items: []string{"Resrart Project", "Abort Process"},
	}

	_, result, err := prompt.Run()

	if err != nil {
		return err
	}

	if result == "Abort Process" {
		c.resultStatus = abort
	} else {
		c.resultStatus = reset
	}
	return nil
}

package deployToAWS

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/manifoldco/promptui"
)

type resetTerrafromProject struct {
	terrafromDirectory string
	fileToDelete       []string
	directoryToDelete  []string
	confirmDelete      bool
}

func newResetTerrafromProject(awsConfig awsConfig) resetTerrafromProject {
	terraformDirectory := ""
	if awsConfig.newVPC {
		terraformDirectory = "./terraform/deployToAWS/from-scratch"
	} else {
		terraformDirectory = "./terraform/deployToAWS/eks-only"
	}
	return resetTerrafromProject{
		terrafromDirectory: terraformDirectory,
		fileToDelete:       []string{},
		directoryToDelete:  []string{},
		confirmDelete:      false,
	}
}

func (r *resetTerrafromProject) Run() (resultStatus projectProceedState, errorMessage error) {
	err := r.listFilesAndDirectories()
	if err != nil {
		return abort, err
	}

	err = r.askForConfirmation()

	if err != nil {
		return abort, err
	}

	if !r.confirmDelete {
		return abort, nil
	}

	err = r.deleteFiles()
	if err != nil {
		return abort, err
	}

	err = r.deleteDirectories()
	if err != nil {
		return abort, err
	}

	return proceed, nil
}

func (r *resetTerrafromProject) listFilesAndDirectories() error {
	err := filepath.Walk(r.terrafromDirectory, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			r.directoryToDelete = append(r.directoryToDelete, path)
		} else {
			if !strings.HasSuffix(path, ".tf") {
				r.fileToDelete = append(r.fileToDelete, path)
			}
		}
		return nil
	})

	if err != nil {
		return err
	}

	return nil
}

func (r *resetTerrafromProject) askForConfirmation() error {
	prompt := promptui.Select{
		Label: fmt.Sprintf("Please confirm to delete %d files and %d directories from %s", len(r.fileToDelete), len(r.directoryToDelete), r.terrafromDirectory),
		Items: []string{"Yes", "No"},
	}

	_, result, err := prompt.Run()
	if err != nil {
		return err
	}

	if result == "Yes" {
		r.confirmDelete = true
	} else {
		r.confirmDelete = false
	}

	return nil
}

func (r *resetTerrafromProject) deleteDirectories() error {
	for _, targetDirectory := range r.directoryToDelete {
		err := os.RemoveAll(targetDirectory)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *resetTerrafromProject) deleteFiles() error {
	for _, targetFile := range r.fileToDelete {
		err := os.Remove(targetFile)
		if err != nil {
			return err
		}
	}
	return nil
}

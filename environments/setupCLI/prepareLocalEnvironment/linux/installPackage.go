package linux

import (
	"fmt"
	"os/exec"
	"strings"
)

func (l *LinuxInstall) installPackage(packageName string, packageManager string) error {
	fmt.Printf("Installing %s\n", packageName)
	if packageManager == "snap" {
		command := exec.Command("sudo", "snap", "install", strings.ToLower(packageName), "--classic")
		err := command.Run()
		if err != nil {
			return err
		}
	} else {
		command := exec.Command("sudo", packageManager, "install", "-y", strings.ToLower(packageName))
		err := command.Run()
		if err != nil {
			return err
		}
	}
	return nil
}

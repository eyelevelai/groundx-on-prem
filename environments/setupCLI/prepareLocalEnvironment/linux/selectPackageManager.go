package linux

import (
	"fmt"

	"github.com/manifoldco/promptui"
)

func (l *LinuxInstall) selectPackageManager() error {
	availablePackageManager := []string{}
	if checkForSnap() {
		availablePackageManager = append(availablePackageManager, "snap")
	}
	if checkForApt() {
		availablePackageManager = append(availablePackageManager, "apt")
	}
	if checkForYum() {
		availablePackageManager = append(availablePackageManager, "yum")
	}
	if checkForDnf() {
		availablePackageManager = append(availablePackageManager, "dnf")
	}
	if checkForPacman() {
		availablePackageManager = append(availablePackageManager, "pacman")
	}
	if checkForZypper() {
		availablePackageManager = append(availablePackageManager, "zypper")
	}
	if checkForAptGet() {
		availablePackageManager = append(availablePackageManager, "apt-get")
	}
	if checkForDpkg() {
		availablePackageManager = append(availablePackageManager, "dpkg")
	}

	prompt := promptui.Select{
		Label: "Please select a package manager: ",
		Items: availablePackageManager,
	}

	_, result, err := prompt.Run()

	if err != nil {
		fmt.Printf("Prompt failed %v\n", err)
		return err
	}

	l.packageManager = result

	return nil
}

package linux

import (
	"fmt"
)

type LinuxInstall struct {
	packageManager string
	packageMeeded  []string
}

func NewLinuxInstall(packageNeeded []string) LinuxInstall {

	return LinuxInstall{
		packageManager: "apt-get",
		packageMeeded:  packageNeeded,
	}
}

func (l *LinuxInstall) Run() {
	err := l.selectPackageManager()
	if err != nil {
		fmt.Println(err)
		return
	}
	err = l.updatePackageManager()
	if err != nil {
		fmt.Println("error in update package")
		fmt.Println(err)
		return
	}

	for _, packageNeeded := range l.packageMeeded {
		err = l.installPackage(packageNeeded, l.packageManager)
		if err != nil {
			fmt.Println("error in install package", packageNeeded)
			fmt.Println(err)
			return
		}
	}

	fmt.Println("All packages installed successfully")
}

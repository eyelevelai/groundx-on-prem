package prepareLocalEnvironment

import (
	"eyelevel-setup-cli/prepareLocalEnvironment/linux"
	"runtime"
)

type InstallDependencies struct {
	operatingSystem   string
	packagesToInstall []string
}

func NewInstallDependencies(packagesToInstall []string) InstallDependencies {
	return InstallDependencies{
		operatingSystem:   runtime.GOOS,
		packagesToInstall: packagesToInstall,
	}
}

func (i *InstallDependencies) Run() {
	if i.operatingSystem == "linux" {
		l := linux.NewLinuxInstall(i.packagesToInstall)
		l.Run()
	}
}

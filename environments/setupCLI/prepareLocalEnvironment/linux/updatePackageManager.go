package linux

import (
	"os/exec"
)

func (l *LinuxInstall) updatePackageManager() error {
	switch l.packageManager {
	case "apt":
		command := exec.Command("sudo", "apt", "update")
		_, err := command.Output()
		if err != nil {
			return err
		}
	case "yum":
		command := exec.Command("sudo", "yum", "update")
		_, err := command.Output()
		if err != nil {
			return err
		}
	case "dnf":
		command := exec.Command("sudo", "dnf", "update")
		_, err := command.Output()
		if err != nil {
			return err
		}
	case "pacman":
		command := exec.Command("sudo", "pacman", "-Syu")
		_, err := command.Output()
		if err != nil {
			return err
		}
	case "zypper":
		command := exec.Command("sudo", "zypper", "update")
		_, err := command.Output()
		if err != nil {
			return err
		}
	case "apt-get":
		command := exec.Command("sudo", "apt-get", "update")
		_, err := command.Output()
		if err != nil {
			return err
		}
	case "dpkg":
		command := exec.Command("sudo", "dpkg", "--configure", "-a")
		_, err := command.Output()
		if err != nil {
			return err
		}
	case "snap":
		command := exec.Command("sudo", "snap", "refresh")
		_, err := command.Output()
		if err != nil {
			return err
		}
	}
	return nil
}

package linux

import (
	"os/exec"
)

func checkForSnap() bool {
	cmd := exec.Command("snap", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForApt() bool {
	cmd := exec.Command("apt-get", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForYum() bool {
	cmd := exec.Command("yum", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForDnf() bool {
	cmd := exec.Command("dnf", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForPacman() bool {
	cmd := exec.Command("pacman", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForZypper() bool {
	cmd := exec.Command("zypper", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForAptGet() bool {
	cmd := exec.Command("apt-get", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForDpkg() bool {
	cmd := exec.Command("dpkg", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func checkForRpm() bool {
	cmd := exec.Command("rpm", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

package prepareLocalEnvironment

import (
	"os/exec"
)

type VerifyInstalls struct {
	terrafrom bool
	kubectl   bool
	helm      bool
}

func NewVerifyInstalls() VerifyInstalls {
	return VerifyInstalls{
		terrafrom: false,
		kubectl:   false,
		helm:      false,
	}
}

func (v *VerifyInstalls) Run() (terrafromPresent bool, kubectlPresent bool, helmPresent bool) {
	v.terrafrom = v.verifyTerrafrom()
	v.kubectl = v.verifyKubectl()
	v.helm = v.verifyHelm()

	return v.terrafrom, v.kubectl, v.helm
}

func (v *VerifyInstalls) verifyTerrafrom() bool {
	cmd := exec.Command("terraform", "--version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func (v *VerifyInstalls) verifyKubectl() bool {
	cmd := exec.Command("kubectl", "version", "--client")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

func (v *VerifyInstalls) verifyHelm() bool {
	cmd := exec.Command("helm", "version")
	_, err := cmd.Output()
	if err != nil {
		return false
	}
	return true
}

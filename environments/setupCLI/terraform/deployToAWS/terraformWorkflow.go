package deployToAWS

import (
	"os"
	"os/exec"
)

type terraformWorkflow struct {
	terraformDirectory string
}

func newTerraformWorkflow(terraformDirectory string) terraformWorkflow {
	return terraformWorkflow{
		terraformDirectory: terraformDirectory,
	}
}

func (t *terraformWorkflow) Run() {
	err := t.init()
	if err != nil {
		return
	}
	err = t.apply()
	if err != nil {
		return
	}
}

func (t *terraformWorkflow) init() error {
	if err := t.terraformCommand("init"); err != nil {
		return err
	}
	return nil
}

func (t *terraformWorkflow) apply() error {
	if err := t.terraformCommand("apply", "-auto-approve"); err != nil {
		return err
	}
	return nil
}

func (t *terraformWorkflow) terraformCommand(command string, args ...string) error {
	cmd := exec.Command("terraform", append([]string{command}, args...)...)
	cmd.Dir = t.terraformDirectory
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

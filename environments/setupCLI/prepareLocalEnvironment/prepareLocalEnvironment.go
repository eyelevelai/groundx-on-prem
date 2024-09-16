package prepareLocalEnvironment

import (
	"eyelevel-setup-cli/messages"

	"os"

	"github.com/jedib0t/go-pretty/v6/table"
)

type PrepareLocalEnvironment struct {
	terrafromPresent             bool
	kubectlPresent               bool
	helmPresent                  bool
	premissionToInstallTerraform bool
	premissionToInstallKubectl   bool
	premissionToInstallHelm      bool
	canPreceed                   bool
	exitProgram                  bool
}

func NewPrepareLocalEnvironment() PrepareLocalEnvironment {
	return PrepareLocalEnvironment{
		terrafromPresent:             false,
		kubectlPresent:               false,
		helmPresent:                  false,
		premissionToInstallTerraform: false,
		premissionToInstallKubectl:   false,
		premissionToInstallHelm:      false,
		canPreceed:                   false,
	}
}

func (p *PrepareLocalEnvironment) Run() (exitProgram bool) {
	p.verifyInstalls()
	if p.canPreceed && !p.exitProgram {
		return false
	}
	p.askToInstallDependencies()
	if p.canPreceed && !p.exitProgram {
		return false
	}
	if p.exitProgram {
		return true
	}

	p.installDependencies()
	return false
}

func (p *PrepareLocalEnvironment) verifyInstalls() {
	v := NewVerifyInstalls()
	terrafromPresent, kubectlPresent, helmPresent := v.Run()
	p.terrafromPresent = terrafromPresent
	p.kubectlPresent = kubectlPresent
	p.helmPresent = helmPresent

	t := table.NewWriter()
	t.SetOutputMirror(os.Stdout)
	t.AppendHeader(table.Row{"Dependency Name", "Present"})
	t.AppendRows([]table.Row{
		{"Terrafrom", terrafromPresent},
		{"Kubectl", kubectlPresent},
		{"Helm", helmPresent},
	})
	if terrafromPresent && kubectlPresent && helmPresent {
		p.canPreceed = true
		t.AppendFooter(table.Row{"Can proceed", "Yes"})
	} else {
		p.canPreceed = false
		t.AppendFooter(table.Row{"Can proceed", "No"})
	}
	t.Render()
}

func (p *PrepareLocalEnvironment) askToInstallDependencies() {
	if !p.terrafromPresent {
		p.askToInstallTerraform()
	}
	if !p.kubectlPresent {
		p.askToInstallKubectl()
	}
	if !p.helmPresent {
		p.askToInstallHelm()
	}

	if !p.premissionToInstallTerraform && !p.terrafromPresent {
		p.exitProgram = true
		messages.LackDependencyMessage("Terraform")
	}
	if !p.premissionToInstallKubectl && !p.kubectlPresent {
		p.exitProgram = true
		messages.LackDependencyMessage("Kubectl")
	}
	if !p.premissionToInstallHelm && !p.helmPresent {
		p.exitProgram = true
		messages.LackDependencyMessage("Helm")
	}
}

func (p *PrepareLocalEnvironment) installDependencies() {
	requirePackage := []string{}
	if !p.terrafromPresent {
		requirePackage = append(requirePackage, "Terraform")
	}
	if !p.kubectlPresent {
		requirePackage = append(requirePackage, "Kubectl")
	}
	if !p.helmPresent {
		requirePackage = append(requirePackage, "Helm")
	}

	installPackage := NewInstallDependencies(requirePackage)
	installPackage.Run()
}

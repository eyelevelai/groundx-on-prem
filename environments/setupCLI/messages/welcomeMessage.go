package messages

import "fmt"

func WelcomeMessage() {
	message := `
███████╗██╗   ██╗███████╗██╗     ███████╗██╗   ██╗███████╗██╗          █████╗ ██╗
██╔════╝╚██╗ ██╔╝██╔════╝██║     ██╔════╝██║   ██║██╔════╝██║         ██╔══██╗██║
█████╗   ╚████╔╝ █████╗  ██║     █████╗  ██║   ██║█████╗  ██║         ███████║██║
██╔══╝    ╚██╔╝  ██╔══╝  ██║     ██╔══╝  ╚██╗ ██╔╝██╔══╝  ██║         ██╔══██║██║
███████╗   ██║   ███████╗███████╗███████╗ ╚████╔╝ ███████╗███████╗    ██║  ██║██║
╚══════╝   ╚═╝   ╚══════╝╚══════╝╚══════╝  ╚═══╝  ╚══════╝╚══════╝    ╚═╝  ╚═╝╚═╝

Welcome to the setup CLI, here are some important notes:
- This CLI can be used to deploy EyeLevel AI's GoundX platform to AWS, Azure, GCP, and OpenShift.
- The CLI will require premission to access Terrafrom from you local machine.
- If Terrafrom is not present on your local machine, the CLI will install it for you.
- The CLI will require premission to access your cloud provider account.
- For more information, please visit https://eyelevel.ai
`
	fmt.Println(message)
}

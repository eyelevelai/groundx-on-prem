package messages

import "fmt"

func LackDependencyMessage(dependency string) {
	message := fmt.Sprintf("The %s is missing, please install or grant premission for the CLI to install %s",
		dependency,
		dependency)
	fmt.Println(message)
}

package messages

import "fmt"

func ErrorMessage(stage, message string) {
	red := "\033[31m"
	reset := "\033[0m"

	fmt.Println(string(red), fmt.Sprintf("Error: \n Stage: %s \n Message: %s", stage, message), string(reset))
}

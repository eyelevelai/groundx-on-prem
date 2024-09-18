package deployToAWS

type projectProceedState int

const (
	abort projectProceedState = iota
	proceed
	reset
)

func (p projectProceedState) String() string {
	return [...]string{"abort", "proceed", "reset"}[p]
}

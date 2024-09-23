package deployToAWS

import (
	"context"
	"log"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/iam/types"
)

type verifyAccessKeyPair struct {
	valid               bool
	requiredPermissions []string
	presentPermissions  []string
	lackingPermissions  []string
	iamClient           *iam.Client
}

func newVerifyAccessKeyPair(accessKeyId string, secretAccessKey string, region string) verifyAccessKeyPair {
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(region),
		config.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(accessKeyId, secretAccessKey, ""),
		),
	)
	if err != nil {
		log.Fatalf("Unable to load SDK config, %v", err)
	}

	client := iam.NewFromConfig(cfg)

	return verifyAccessKeyPair{
		valid:               false,
		requiredPermissions: requiredAWSPermissions,
		presentPermissions:  []string{},
		lackingPermissions:  []string{},
		iamClient:           client,
	}
}

func (v *verifyAccessKeyPair) Run() (keyPairValid bool, errorMessage error) {
	err := v.verifyPremissions()
	if err != nil {
		return false, err
	}

	if len(v.lackingPermissions) == 0 {
		v.valid = true
	} else {
		v.valid = false
	}

	return v.valid, nil
}

func (v *verifyAccessKeyPair) verifyPremissions() error {
	for _, perm := range v.requiredPermissions {
		success := v.simulatePermission(perm)

		if success {
			v.presentPermissions = append(v.presentPermissions, perm)
		} else {
			v.lackingPermissions = append(v.lackingPermissions, perm)
		}
	}
	return nil
}

func (v *verifyAccessKeyPair) simulatePermission(targetPermission string) bool {
	callerIdentity, err := v.iamClient.GetUser(context.TODO(), &iam.GetUserInput{})
	if err != nil {
		log.Printf("Unable to retrieve user identity: %v", err)
		return false
	}

	result, err := v.iamClient.SimulatePrincipalPolicy(context.TODO(), &iam.SimulatePrincipalPolicyInput{
		PolicySourceArn: callerIdentity.User.Arn,
		ActionNames:     []string{targetPermission},
	})

	if err != nil {
		log.Printf("Error simulating permission for %s: %v", targetPermission, err)
		return false
	}

	for _, eval := range result.EvaluationResults {
		if eval.EvalDecision == types.PolicyEvaluationDecisionTypeAllowed {
			return true
		}
	}

	return false
}

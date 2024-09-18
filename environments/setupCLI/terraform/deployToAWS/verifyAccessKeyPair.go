package deployToAWS

import (
	"context"
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go-v2/aws"
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
		success, err := v.simulatePermission(perm)
		if err != nil {
			fmt.Printf("Error checking permission %s: %v\n", perm, err)
			return err
		}

		if success {
			v.presentPermissions = append(v.presentPermissions, perm)
		} else {
			v.lackingPermissions = append(v.lackingPermissions, perm)
		}
	}
	return nil
}

func (v *verifyAccessKeyPair) simulatePermission(targetPermission string) (bool, error) {
	result, err := v.iamClient.SimulatePrincipalPolicy(context.TODO(), &iam.SimulatePrincipalPolicyInput{
		PolicySourceArn: aws.String("arn:aws:iam::aws:policy/AdministratorAccess"),
		ActionNames:     []string{targetPermission},
	})

	if err != nil {
		return false, fmt.Errorf("Error simulating permission %s: %v", targetPermission, err)
	}

	for _, eval := range result.EvaluationResults {
		if eval.EvalDecision == types.PolicyEvaluationDecisionTypeAllowed {
			fmt.Printf("Permission: %s is allowed\n", targetPermission)
			return true, nil
		}
		fmt.Printf("Permission: %s is denied\n", targetPermission)
	}

	return false, nil
}

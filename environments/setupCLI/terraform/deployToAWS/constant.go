package deployToAWS

var requiredAWSPermissions = []string{
	"ec2:CreateVpc",
	"ec2:DescribeVpcs",
	"ec2:CreateSubnet",
	"ec2:DescribeSubnets",
	"ec2:CreateInternetGateway",
	"eks:CreateCluster",
	"eks:DescribeCluster",
	"eks:CreateNodegroup",
	"iam:CreateRole",
	"iam:AttachRolePolicy",
	"ec2:RunInstances",
	"s3:ListBucket",
}

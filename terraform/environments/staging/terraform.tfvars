aws_region           = "us-east-1"
environment          = "staging"

# Staging VPC gets the 10.3.x.x space
vpc_cidr             = "10.3.0.0/16"
public_subnet_cidrs  = ["10.3.1.0/24", "10.3.2.0/24"]
private_subnet_cidrs = ["10.3.10.0/24", "10.3.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

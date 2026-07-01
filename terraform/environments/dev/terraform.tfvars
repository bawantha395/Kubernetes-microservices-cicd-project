aws_region           = "us-east-1"
environment          = "dev"

# Dev VPC gets the 10.1.x.x space (Prod could be 10.2.x.x)
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

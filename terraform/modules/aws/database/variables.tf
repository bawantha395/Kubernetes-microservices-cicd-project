variable "environment" {
  type        = string
  description = "The environment name (e.g., dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where the RDS instance will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the DB subnet group"
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "The security group ID of the EKS cluster to allow traffic from"
}

variable "db_instance_class" {
  type        = string
  description = "The instance type of the RDS instance"
  default     = "db.t3.micro"
}

variable "db_username" {
  type        = string
  description = "The master username for the database"

  validation {
    condition     = !contains(["admin", "root", "mysql.sys", "rdsadmin"], var.db_username)
    error_message = "The username provided is a reserved word in RDS MySQL (admin, root, mysql.sys, rdsadmin) and cannot be used."
  }
}

variable "db_password" {
  type        = string
  description = "The master password for the database"
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to all resources"
  default     = {}
}

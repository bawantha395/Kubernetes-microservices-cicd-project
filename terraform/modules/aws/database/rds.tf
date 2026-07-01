resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-rds-sg-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_cluster_security_group_id]
  }
}

resource "aws_db_instance" "main" {
  identifier           = "${var.environment}-issue-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "game_db"

  # 1. FIXED: Hardcoded clean username to bypass the broken pipeline variable
  username             = "game_admin"
  password             = var.db_password
  skip_final_snapshot  = true

  apply_immediately    = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
}

# ==============================================================================
# AUTOMATED SECRETS MANAGER PROVISIONING
# ==============================================================================

# Automatically builds the secure cloud vault inside AWS
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${var.environment}/issue/db"
  recovery_window_in_days = 0
}

# Automatically encodes both pieces of credentials using the hardcoded username
resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "game_admin"
    password = var.db_password
  })
}
provider "aws" {
  region  = "ap-southeast-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-09964535fc01efa5f"
  instance_type = "t2.micro"
  subnet_id = "subnet-0d532cff718432c72"

  tags = {
    Name = "${terraform.workspace}-${var.instance_name}-${var.STAGE}"
  }
}

resource "aws_db_instance" "education" {
  identifier             = "education"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14.1"
  username               = "edu"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.education.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}
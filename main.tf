provider "aws" {
  region  = "ap-southeast-1"
}

resource "aws_instance" "app_server" {
  ami           = "ami-09964535fc01efa5f"
  instance_type = "t2.micro"
  subnet_id = "subnet-0d532cff718432c72"

  tags = {
    Name = "${var.instance_name}-${terraform.workspace}"
  }
}

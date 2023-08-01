resource "aws_security_group" "public_alb_sg" {
  lifecycle {
    ignore_changes = [
      description
    ]
  }

  name   = var.configs.public_alb_security_group_name
  description = var.configs.public_alb_security_group_name
  egress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    },
  ]
  ingress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 443
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 443
    },
  ]
  tags   = var.tags
  vpc_id = var.vpc_id

  timeouts {}
}

resource "aws_security_group" "app_sg" {
  depends_on = [ aws_security_group.public_alb_sg ]

  name   = var.configs.app_security_group_name
  description = var.configs.app_security_group_name
  egress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    },
  ]
  ingress = [
    {
      cidr_blocks      = []
      description      = ""
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups = [
        aws_security_group.public_alb_sg.id
      ]
      self    = false
      to_port = 80
    },
  ]

  tags   = var.tags
  vpc_id = var.vpc_id

  timeouts {}
}

resource "aws_security_group" "secure_sg" {
  depends_on = [ aws_security_group.app_sg ]

  lifecycle {
    ignore_changes = [
      ingress
    ]
  }

  name   = var.configs.secure_security_group_name
  description = var.configs.secure_security_group_name
  egress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    },
  ]
  ingress = [
    {
      cidr_blocks = [
        "172.28.1.0/25",
        "172.28.1.128/25",
      ]
      description      = "from vpn"
      from_port        = var.configs.db_port
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = var.configs.db_port
    },
    {
      cidr_blocks      = []
      description      = ""
      from_port        = var.configs.db_port
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups = [
        aws_security_group.app_sg.id
      ]
      self    = false
      to_port = var.configs.db_port
    },
  ]
  tags   = var.tags
  vpc_id = var.vpc_id

  timeouts {}
}

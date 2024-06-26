resource "aws_security_group" "external_alb_sg" {
  provider = aws.network
  lifecycle {
    ignore_changes = [
      description
    ]
  }
  name        = var.configs.external_alb_security_group_name
  description = "Allow HTTP/S from anywhere"
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
  tags   = merge(var.tags, { Name = var.configs.external_alb_security_group_name })
  vpc_id = var.network_vpc_id

  timeouts {}
}

resource "aws_security_group" "public_alb_sg" {
  provider = aws.workload
  lifecycle {
    ignore_changes = [
      description
    ]
  }

  name        = var.configs.public_alb_security_group_name
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
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    },
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
  tags   = merge(var.tags, { Name = var.configs.public_alb_security_group_name })
  vpc_id = var.workload_vpc_id

  timeouts {}
}

resource "aws_security_group" "private_alb_sg" {
  provider    = aws.workload
  name        = var.configs.private_alb_security_group_name
  description = var.configs.private_alb_security_group_name
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

  tags   = merge(var.tags, { Name = var.configs.private_alb_security_group_name })
  vpc_id = var.workload_vpc_id

  timeouts {}
}

resource "aws_security_group" "app_sg" {
  provider = aws.workload

  name        = var.configs.app_security_group_name
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
        aws_security_group.private_alb_sg.id
      ]
      self    = false
      to_port = 80
    },
  ]

  tags   = merge(var.tags, { Name = var.configs.app_security_group_name })
  vpc_id = var.workload_vpc_id

  timeouts {}
}

resource "aws_security_group" "secure_sg" {
  provider = aws.workload

  lifecycle {
    ignore_changes = [
      ingress
    ]
  }

  name        = var.configs.secure_security_group_name
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

  dynamic "ingress" {
    for_each = var.configs.db_ports
    content {
      cidr_blocks = [
        "172.28.1.0/25",
        "172.28.1.128/25",
      ]
      description      = "from vpn"
      from_port        = ingress.value
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = ingress.value
    }
  }

  dynamic "ingress" {
    for_each = var.configs.db_ports
    content {
      cidr_blocks      = []
      description      = ""
      from_port        = ingress.value
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups = [
        aws_security_group.app_sg.id
      ]
      self    = false
      to_port = ingress.value
    }
  }

  tags   = merge(var.tags, { Name = var.configs.secure_security_group_name })
  vpc_id = var.workload_vpc_id

  timeouts {}
}

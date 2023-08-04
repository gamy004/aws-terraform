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
        aws_security_group.public_alb_sg.id
      ]
      self    = false
      to_port = 80
    },
  ]

  tags   = merge(var.tags, { Name = var.configs.app_security_group_name })
  vpc_id = var.workload_vpc_id

  timeouts {}
}

module "secure_sg" {
  source = "terraform-aws-modules/security-group/aws"
  providers = {
    aws = aws.workload
  }

  vpc_id             = var.workload_vpc_id
  create_sg          = var.configs.create
  name               = var.configs.secure_security_group_name
  description        = var.configs.secure_security_group_name
  tags               = merge(var.tags, { Name = var.configs.secure_security_group_name })
  egress_cidr_blocks = ["0.0.0.0/0"]
  computed_ingress_with_cidr_blocks = flatten([
    for db_port in var.configs.db_ports :
    [
      {
        cidr_blocks = "172.28.1.0/25"
        description = "from vpn"
        from_port   = db_port
        protocol    = "tcp"
        self        = false
        to_port     = db_port
      },
      {
        cidr_blocks = "172.28.1.128/25"
        description = "from vpn"
        from_port   = db_port
        protocol    = "tcp"
        self        = false
        to_port     = db_port
      },
    ]
  ])

  computed_ingress_with_source_security_group_id = [
    for db_port in var.configs.db_ports :
    {
      from_port                = db_port
      protocol                 = "tcp"
      self                     = false
      to_port                  = db_port
      source_security_group_id = aws_security_group.app_sg.id
    }
  ]
}

# resource "aws_security_group" "secure_sg" {
#   provider = aws.workload

#   lifecycle {
#     ignore_changes = [
#       ingress
#     ]
#   }

#   name        = var.configs.secure_security_group_name
#   description = var.configs.secure_security_group_name
#   egress = [
#     {
#       cidr_blocks = [
#         "0.0.0.0/0",
#       ]
#       description      = ""
#       from_port        = 0
#       ipv6_cidr_blocks = []
#       prefix_list_ids  = []
#       protocol         = "-1"
#       security_groups  = []
#       self             = false
#       to_port          = 0
#     },
#   ]

#   dynamic "ingress" {
#     for_each = var.configs.db_ports
#     content {
#       cidr_blocks = [
#         "172.28.1.0/25",
#         "172.28.1.128/25",
#       ]
#       description      = "from vpn"
#       from_port        = ingress.value
#       ipv6_cidr_blocks = []
#       prefix_list_ids  = []
#       protocol         = "tcp"
#       security_groups  = []
#       self             = false
#       to_port          = ingress.value
#     }
#   }

#   dynamic "ingress" {
#     for_each = var.configs.db_ports
#     content {
#       cidr_blocks      = []
#       description      = ""
#       from_port        = ingress.value
#       ipv6_cidr_blocks = []
#       prefix_list_ids  = []
#       protocol         = "tcp"
#       security_groups = [
#         aws_security_group.app_sg.id
#       ]
#       self    = false
#       to_port = ingress.value
#     }
#   }

#   # ingress = [
#   #   {
#   #     cidr_blocks = [
#   #       "172.28.1.0/25",
#   #       "172.28.1.128/25",
#   #     ]
#   #     description      = "from vpn"
#   #     from_port        = var.configs.db_port
#   #     ipv6_cidr_blocks = []
#   #     prefix_list_ids  = []
#   #     protocol         = "tcp"
#   #     security_groups  = []
#   #     self             = false
#   #     to_port          = var.configs.db_port
#   #   },
#   #   {
#   #     cidr_blocks      = []
#   #     description      = ""
#   #     from_port        = var.configs.db_port
#   #     ipv6_cidr_blocks = []
#   #     prefix_list_ids  = []
#   #     protocol         = "tcp"
#   #     security_groups = [
#   #       aws_security_group.app_sg.id
#   #     ]
#   #     self    = false
#   #     to_port = var.configs.db_port
#   #   },
#   # ]

#   tags   = merge(var.tags, { Name = var.configs.secure_security_group_name })
#   vpc_id = var.workload_vpc_id

#   timeouts {}
# }

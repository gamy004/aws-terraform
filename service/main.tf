locals {
  iam_users = {
    for config in lookup(var.configs, "service_configs", []) : config.service_name => config
  }
}

data "aws_iam_policy" "cognito_access" {
  arn = "arn:aws:iam::aws:policy/AmazonESCognitoAccess"
}

data "aws_iam_policy_document" "dynamodb_access" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user" "service" {
  for_each = local.iam_users
  name     = each.value.service_name
  tags     = merge(var.tags, { Name : "${each.value.service_name}" })
}

resource "aws_iam_user_policy_attachment" "cognito_access" {
  for_each = aws_iam_user.service

  user       = each.value.name
  policy_arn = data.aws_iam_policy.cognito_access.arn
}

resource "aws_iam_user_policy" "dynamodb_access" {
  for_each = aws_iam_user.service

  name   = "${each.value.name}-policy"
  user   = each.value.name
  policy = data.aws_iam_policy_document.dynamodb_access.json
}

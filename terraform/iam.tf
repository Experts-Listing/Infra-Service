resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# CI: one role per application repo, assumable only from pushes to dev/stage/prod, push rights on its own ECR repo only.
data "aws_iam_policy_document" "ci_trust" {
  for_each = var.services

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for env in var.environments : "repo:${var.github_org}/${each.value}:ref:refs/heads/${env}"]
    }
  }
}

resource "aws_iam_role" "ci" {
  for_each = var.services

  name               = "${var.project}-ci-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.ci_trust[each.key].json
}

data "aws_iam_policy_document" "ci_ecr_push" {
  for_each = var.services

  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.service[each.key].arn]
  }
}

resource "aws_iam_role_policy" "ci_ecr_push" {
  for_each = var.services

  name   = "ecr-push"
  role   = aws_iam_role.ci[each.key].id
  policy = data.aws_iam_policy_document.ci_ecr_push[each.key].json
}

# CD: Infra-Service jobs running in a dev/stage/prod GitHub Environment. Kubernetes rights come from the EKS access entry in main.tf.
data "aws_iam_policy_document" "cd_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for env in var.environments : "repo:${var.github_org}/${var.infra_repository}:environment:${env}"]
    }
  }
}

resource "aws_iam_role" "cd" {
  name               = "${var.project}-cd"
  assume_role_policy = data.aws_iam_policy_document.cd_trust.json
}

data "aws_iam_policy_document" "cd" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }

  statement {
    actions   = ["ecr:DescribeImages"]
    resources = [for repo in aws_ecr_repository.service : repo.arn]
  }
}

resource "aws_iam_role_policy" "cd" {
  name   = "deploy"
  role   = aws_iam_role.cd.id
  policy = data.aws_iam_policy_document.cd.json
}

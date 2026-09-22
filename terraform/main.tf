data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.project
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, 48 + i)]

  enable_nat_gateway = true
  single_nat_gateway = true # cost trade-off; one NAT per AZ for full HA in prod

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.25"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  enabled_log_types                        = ["api", "audit", "authenticator"]
  enable_cluster_creator_admin_permissions = true

  addons = {
    vpc-cni = {
      before_compute = true
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy     = {}
    coredns        = {}
    metrics-server = {}
    amazon-cloudwatch-observability = {
      pod_identity_association = [{
        role_arn        = module.cloudwatch_pod_identity.iam_role_arn
        service_account = "cloudwatch-agent"
      }]
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }

  access_entries = {
    cd = {
      principal_arn = aws_iam_role.cd.arn
      policy_associations = {
        edit = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = var.environments
          }
        }
      }
    }
  }
}

module "cloudwatch_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.9"

  name                                       = "${local.name}-cloudwatch-agent"
  attach_aws_cloudwatch_observability_policy = true
}

module "lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 2.9"

  name                            = "${local.name}-aws-lb-controller"
  attach_aws_lb_controller_policy = true

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.5.0"

  set = [
    { name = "clusterName", value = module.eks.cluster_name },
    { name = "region", value = var.aws_region },
    { name = "vpcId", value = module.vpc.vpc_id },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
  ]

  depends_on = [module.lb_controller_pod_identity]
}

resource "kubernetes_namespace_v1" "env" {
  for_each = toset(var.environments)

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/part-of" = local.name
      environment                 = each.key
    }
  }

  depends_on = [module.eks]
}

resource "aws_sns_topic" "alarms" {
  name = "${local.name}-alarms"
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  cluster_alarms = {
    node-cpu-high    = { metric = "node_cpu_utilization", threshold = 80 }
    node-memory-high = { metric = "node_memory_utilization", threshold = 80 }
    failed-nodes     = { metric = "cluster_failed_node_count", threshold = 0 }
  }
}

resource "aws_cloudwatch_metric_alarm" "cluster" {
  for_each = local.cluster_alarms

  alarm_name          = "${local.name}-${each.key}"
  namespace           = "ContainerInsights"
  metric_name         = each.value.metric
  dimensions          = { ClusterName = module.eks.cluster_name }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value.threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

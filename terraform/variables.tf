variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "expert-listing"
}

variable "github_org" {
  type    = string
  default = "Experts-Listing"
}

variable "github_org_id" {
  description = "Numeric org ID; GitHub OIDC subjects use the immutable form repo:<org>@<org-id>/<repo>@<repo-id>"
  type        = number
  default     = 332406938
}

variable "github_repository_ids" {
  type = map(number)
  default = {
    Expert-Listing-Frontend-Service       = 1381165194
    Expert-Listing-Backend-Server-Service = 1381166435
    Expert-Listing-Geo-Bucket             = 1381206904
    Infra-Service                         = 1381167448
  }
}

variable "infra_repository" {
  type    = string
  default = "Infra-Service"
}

variable "services" {
  description = "Service name => application repository that builds its image"
  type        = map(string)
  default = {
    frontend   = "Expert-Listing-Frontend-Service"
    backend    = "Expert-Listing-Backend-Server-Service"
    geo-bucket = "Expert-Listing-Geo-Bucket"
  }
}

variable "environments" {
  type    = list(string)
  default = ["dev", "stage", "prod"]
}

variable "kubernetes_version" {
  type    = string
  default = "1.35"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["c7i-flex.large"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint (GitHub-hosted runners need it public)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alarm_email" {
  description = "Optional email subscribed to the CloudWatch alarm topic"
  type        = string
  default     = ""
}

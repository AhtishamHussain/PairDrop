variable "aws_region" {
  type    = string
  default = "eu-north-1"
}

variable "github_org" {
  type    = string
  default = "AhtishamHussain"
}

variable "github_repo" {
  type    = string
  default = "PairDrop"
}

variable "alert_email" {
  type        = string
  default     = ""
  description = "Optional email for the $8 monthly budget alarm. Leave empty to skip email."
}

variable "domain" {
  type        = string
  default     = ""
  description = "Optional hostname (example: drop.example.com). Leave empty for HTTP on the Elastic IP."
}

variable "acme_email" {
  type    = string
  default = ""
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 1
}

variable "budget_limit" {
  type    = string
  default = "8"
}

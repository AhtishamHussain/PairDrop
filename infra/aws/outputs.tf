output "ecr_repository_url" {
  value     = aws_ecr_repository.app.repository_url
  sensitive = false
}

output "github_actions_role_arn" {
  value = aws_iam_role.github.arn
}

output "elastic_ip" {
  value = aws_eip.app.public_ip
}

output "region" {
  value = var.aws_region
}

output "notes" {
  value = "Public inbound is 80/443 only. SSH is closed; use AWS Systems Manager Session Manager. TURN secrets belong in SSM /pairdrop/rtc_config, never in git. GPU, ALB canary, and NAT gateways are omitted to stay on the free-trial budget."
}

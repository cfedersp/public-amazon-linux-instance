output "Region" {
  description = "AWS region"
  value       = var.aws_region
}
output "InstancePublicIp" {
  description = "instance ip address"
  value	= resource.aws_instance.public_linux.public_ip
}
output "InstancePublicDns" {
  description = "instance ip address"
  value	= resource.aws_instance.public_linux.public_dns
}
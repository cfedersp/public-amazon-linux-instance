variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}
variable "AWS_ACCESS_KEY_ID" {
  description = "AWS Key from TF Cloud Workspace Env"
  type        = string
}
variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS Secret from TF Cloud Workspace Env"
  type        = string
}
variable "ec2_key_pair" {
  description = "SSH Key"
  type = string
}
variable "instance_ami" {
  description = "AMI"
  type = string
}
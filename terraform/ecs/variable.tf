variable "vpc_id" {
  description = "The ID of the VPC where ECS services will run"
  type        = string
}

variable "subnets" {
  description = "The list of subnet IDs where ECS services will be deployed"
  type        = list(string)
}

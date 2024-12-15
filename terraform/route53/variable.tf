variable "domain_name" {
  description = "Domain name for Route 53 zone"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  type        = string
}

variable "cloudfront_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  type        = string
}
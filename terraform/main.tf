# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67.0"
     
    }
  }
}
provider "aws" {
   region = "ap-south-1"
}


# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Main VPC"
  }

  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main Internet Gateway"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Public Subnet 2"
  }
}

# SSL Certificate for Domain
resource "aws_acm_certificate" "domain_cert" {
  domain_name       = "avy1013.online"
  validation_method = "DNS"

  subject_alternative_names = ["www.avy1013.online"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "avy1013.online SSL Certificate"
  }
}

# S3 Bucket for Static Website
resource "aws_s3_bucket" "website_bucket" {
  bucket = "avy1013-website-bucket"
  force_destroy = true
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "website_bucket_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket Policy to make it publicly accessible
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          "${aws_s3_bucket.website_bucket.arn}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_bucket_access]
}

# S3 Object (Index HTML)
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  content      = <<-EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Hello, DevOps!</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #f0f0f0;
        }
        .container {
            text-align: center;
            padding: 20px;
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello, DevOps!</h1>
        <p>Welcome to the DevOps Infrastructure Project</p>
        <p>Deployed on AWS using Terraform</p>
    </div>
</body>
</html>
EOF
  content_type = "text/html"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.website_bucket.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.id}"

    forwarded_values {
      query_string = false
      headers      = []
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "avy1013-website-distribution"
  }
}
module "route53" {
  source = "./route53"
  
  domain_name             = "avy1013.online"
  cloudfront_domain_name  = aws_cloudfront_distribution.s3_distribution.domain_name
  cloudfront_zone_id      = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
}
module "ecs" {
  source = "./ecs"

  vpc_id              = aws_vpc.main.id  # Reference the VPC resource from main.tf
  subnets             = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}
# Outputs
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "s3_bucket_website_url" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "s3_bucket_name" {
  value = aws_s3_bucket.website_bucket.id
}
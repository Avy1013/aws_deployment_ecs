provider "aws" {
  region = "ap-south-1"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "simple-ecs-cluster"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach the Amazon ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "simple-task-family"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"   # 0.25 vCPU
  memory                   = "512"   # 512 MB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "simple-container"
    image = "avy1013/node-backend"
    portMappings = [{
      containerPort = 3000   # Map container's internal port 80
      hostPort      = 3000    # Host will expose port 80
      protocol      = "tcp"
    }]
  }])
}

# Security Group
resource "aws_security_group" "ecs_service_sg" {
  name_prefix = "ecs-service-sg-"
  description = "Allow traffic for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = "simple-ecs-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = var.subnets
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
}

# Output the Service URL
output "ecs_service" {
  value = "Your service is running on port 80. Use /status to check the health."
}

##############################################
# AWS Provider
##############################################
provider "aws" {
  region = "us-east-1"
}

##############################################
# Random ID for S3 Bucket
##############################################
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

##############################################
# VPC + Networking
##############################################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Internet Gateway for Public Subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

##############################################
# DynamoDB VPC Endpoint (no NAT required)
##############################################
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_rt.id
  ]
}

##############################################
# S3 Static Website Hosting
##############################################
resource "aws_s3_bucket" "frontend" {
  bucket = "frontend-logistics-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_policy     = false
  block_public_acls       = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = "*",
      Action = "s3:GetObject",
      Resource = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

##############################################
# DynamoDB Table
##############################################
resource "aws_dynamodb_table" "shipments" {
  name         = "Shipments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

##############################################
# IAM for Lambda
##############################################
resource "aws_iam_role" "lambda_role" {
  name = "logistics-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Least privilege DynamoDB access
resource "aws_iam_policy" "ddb_policy" {
  name = "LambdaDynamoDBAccess"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Scan"],
      Resource = aws_dynamodb_table.shipments.arn
    }]
  })
}

# Attach policies
resource "aws_iam_role_policy_attachment" "ddb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ddb_policy.arn
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

##############################################
# Security Group for Lambda
##############################################
resource "aws_security_group" "lambda_sg" {
  vpc_id = aws_vpc.main.id
}

##############################################
# Lambda Functions (inside Private Subnet)
##############################################
resource "aws_lambda_function" "get_shipments" {
  function_name = "GetShipments"
  runtime       = "nodejs18.x"
  handler       = "index.handler"
  filename         = "getShipments.zip"
  source_code_hash = filebase64sha256("getShipments.zip")
  role          = aws_iam_role.lambda_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

resource "aws_lambda_function" "create_shipments" {
  function_name = "CreateShipments"
  runtime       = "nodejs18.x"
  handler       = "index.handler"
  filename         = "createShipments.zip"
  source_code_hash = filebase64sha256("createShipments.zip")
  role          = aws_iam_role.lambda_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

##############################################
# API Gateway HTTP API (cheapest)
##############################################
resource "aws_apigatewayv2_api" "api" {
  name          = "LogisticsHTTPAPI"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

# Lambda Integrations
resource "aws_apigatewayv2_integration" "get_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_shipments.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "post_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_shipments.invoke_arn
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "get_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /shipments"
  target    = "integrations/${aws_apigatewayv2_integration.get_integration.id}"
}

resource "aws_apigatewayv2_route" "post_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /shipments"
  target    = "integrations/${aws_apigatewayv2_integration.post_integration.id}"
}

# Stage (auto-deploy enabled)
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "prod"
  auto_deploy = true
}

##############################################
# Permissions for API to invoke Lambda
##############################################
resource "aws_lambda_permission" "get_permission" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_shipments.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*"
}

resource "aws_lambda_permission" "post_permission" {
  statement_id  = "AllowAPIGatewayInvokePost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_shipments.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*"
}

##############################################
# Outputs
##############################################
output "api_url" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/prod"
}

output "s3_website_url" {
  value = aws_s3_bucket.frontend.website_endpoint
}

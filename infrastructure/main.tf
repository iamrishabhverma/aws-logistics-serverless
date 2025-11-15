provider "aws" { region = "us-east-1" }

resource "aws_s3_bucket" "frontend" { bucket = "your-unique-logistics-frontend" }
resource "aws_s3_bucket_public_access_block" "frontend" { bucket = aws_s3_bucket.frontend.id; block_public_acls = false; block_public_policy = false; ignore_public_acls = false; restrict_public_buckets = false; }
resource "aws_s3_bucket_policy" "frontend_policy" { bucket = aws_s3_bucket.frontend.id; policy = jsonencode({ Version = "2012-10-17"; Statement = [{ Sid = "PublicRead"; Effect = "Allow"; Principal = "*"; Action = "s3:GetObject"; Resource = "${aws_s3_bucket.frontend.arn}/*" }] }) }

resource "aws_dynamodb_table" "shipments" { name = "Shipments"; billing_mode = "PAY_PER_REQUEST"; hash_key = "id"; attribute { name = "id"; type = "S" }; server_side_encryption { enabled = true } }

resource "aws_iam_role" "lambda_role" { name = "lambda_role"; assume_role_policy = jsonencode({ Version = "2012-10-17"; Statement = [{ Action = "sts:AssumeRole"; Effect = "Allow"; Principal = { Service = "lambda.amazonaws.com" } }] }) }
resource "aws_iam_role_policy_attachment" "dynamodb" { role = aws_iam_role.lambda_role.name; policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" }
resource "aws_iam_role_policy_attachment" "comprehend" { role = aws_iam_role.lambda_role.name; policy_arn = "arn:aws:iam::aws:policy/ComprehendReadOnly" }

resource "aws_vpc" "vpc" { cidr_block = "10.0.0.0/16" }
resource "aws_subnet" "subnet" { vpc_id = aws_vpc.vpc.id; cidr_block = "10.0.1.0/24" }
resource "aws_security_group" "sg" { vpc_id = aws_vpc.vpc.id }

resource "aws_lambda_function" "get_shipments" { function_name = "GetShipments"; runtime = "nodejs18.x"; handler = "index.handler"; code = filebase64("lambda_get.zip"); role = aws_iam_role.lambda_role.arn; vpc_config { subnet_ids = [aws_subnet.subnet.id]; security_group_ids = [aws_security_group.sg.id] } }

resource "aws_api_gateway_rest_api" "api" { name = "LogisticsAPI" }
resource "aws_api_gateway_resource" "resource" { rest_api_id = aws_api_gateway_rest_api.api.id; parent_id = aws_api_gateway_rest_api.api.root_resource_id; path_part = "shipments" }
resource "aws_api_gateway_method" "get" { rest_api_id = aws_api_gateway_rest_api.api.id; resource_id = aws_api_gateway_resource.resource.id; http_method = "GET"; authorization = "NONE" }
resource "aws_api_gateway_integration" "get_integration" { rest_api_id = aws_api_gateway_rest_api.api.id; resource_id = aws_api_gateway_resource.resource.id; http_method = aws_api_gateway_method.get.http_method; integration_http_method = "POST"; type = "AWS_PROXY"; uri = aws_lambda_function.get_shipments.invoke_arn }
resource "aws_api_gateway_deployment" "deployment" { depends_on = [aws_api_gateway_integration.get_integration]; rest_api_id = aws_api_gateway_rest_api.api.id; stage_name = "prod" }
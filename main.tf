terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
}

variable "profile" {
  default = "dev-01"
}

######### ZIP SOURCE CODE ##############

data "archive_file" "get_file" {
  type        = "zip"
  source_file = "${path.module}/target/lambdagetbin"
  output_path = "${path.module}/target/lambdagetbin.zip"
}

data "archive_file" "post_file" {
  type        = "zip"
  source_file = "${path.module}/target/lambdapostbin"
  output_path = "${path.module}/target/lambdapostbin.zip"
}

data "archive_file" "auth_file" {
  type        = "zip"
  source_file = "${path.module}/target/lambdaauthbin"
  output_path = "${path.module}/target/lambdaauthbin.zip"
}

############## S3 BUCKET ###################

resource "random_pet" "lambda_bucket_name" {
  prefix = "rnd-bkt"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id

  acl           = "private"
  force_destroy = true
}



resource "aws_s3_bucket_object" "auth_s3bo" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "auth.zip"
  source = data.archive_file.auth_file.output_path

  etag = filemd5(data.archive_file.auth_file.output_path)
}

resource "aws_s3_bucket_object" "post_task_s3bo" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "post-task.zip"
  source = data.archive_file.post_file.output_path

  etag = filemd5(data.archive_file.post_file.output_path)
}

resource "aws_s3_bucket_object" "get_tasks_s3bo" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "get-task.zip"
  source = data.archive_file.get_file.output_path

  etag = filemd5(data.archive_file.get_file.output_path)
}


################ LAMBDA FUNCTIONS ################

resource "aws_lambda_function" "get_tasks" {
  function_name    = "getTasks"
  handler          = "lambdagetbin"
  runtime          = "go1.x"
  role             = aws_iam_role.invocation_role.arn
  filename         = data.archive_file.get_file.output_path
  source_code_hash = data.archive_file.get_file.output_base64sha256
  memory_size      = 128
  timeout          = 10
}

resource "aws_lambda_function" "post_task" {
  function_name    = "postTask"
  handler          = "lambdapostbin"
  runtime          = "go1.x"
  role             = aws_iam_role.invocation_role.arn
  filename         = data.archive_file.post_file.output_path
  source_code_hash = data.archive_file.post_file.output_base64sha256
  memory_size      = 128
  timeout          = 10
}

resource "aws_lambda_function" "auth" {
  function_name    = "auth"
  handler          = "lambdaauthbin"
  runtime          = "go1.x"
  role             = aws_iam_role.invocation_role.arn
  filename         = data.archive_file.auth_file.output_path
  source_code_hash = data.archive_file.auth_file.output_base64sha256
  memory_size      = 128
  timeout          = 10

}

resource "aws_lambda_permission" "allow_auth" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gw.execution_arn}/*/*/*"
}


resource "aws_lambda_permission" "allow_get" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_tasks.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gw.execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "allow_post" {
  statement_id  = "AllowAPIgatewayInvokation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gw.execution_arn}/*/*/*"
}


################ API GATEWAY ################

resource "aws_api_gateway_rest_api" "api_gw" {
  name = "api_gw"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "task" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "task"
}

resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  parent_id   = aws_api_gateway_rest_api.api_gw.root_resource_id
  path_part   = "tasks"
}

// GET
resource "aws_api_gateway_method" "get" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.tasks.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gw.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_tasks.invoke_arn
}


resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.get.http_method
  status_code = "200"
}

// POST
resource "aws_api_gateway_method" "post" {
  rest_api_id      = aws_api_gateway_rest_api.api_gw.id
  resource_id      = aws_api_gateway_resource.task.id
  http_method      = "POST"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.auth.id
  api_key_required = false
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gw.id
  resource_id             = aws_api_gateway_resource.task.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.post_task.invoke_arn
}

resource "aws_api_gateway_authorizer" "auth" {
  name                   = "gw-auth0"
  rest_api_id            = aws_api_gateway_rest_api.api_gw.id
  authorizer_uri         = aws_lambda_function.auth.invoke_arn
  authorizer_credentials = aws_iam_role.invocation_role.arn
}


########### IAM #############

resource "aws_iam_role" "invocation_role" {
  name = "api_gateway_auth_invocation"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "apigateway.amazonaws.com",
          "lambda.amazonaws.com",
          "events.amazonaws.com"
        ] 
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "test-policy"
  description = "A test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.invocation_role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_role_policy" "invocation_policy" {
  name = "default"
  role = aws_iam_role.invocation_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "lambda:InvokeFunction",
        "execute-api:Invoke",
        "dynamodb:Scan",
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_lambda_function.get_tasks.arn}",
        "${aws_dynamodb_table.tasks.arn}"
      ]
    },
    {
      "Action": [
        "lambda:InvokeFunction",
        "execute-api:Invoke",
        "dynamodb:PutItem",
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_lambda_function.post_task.arn}",
        "${aws_dynamodb_table.tasks.arn}"
      ]
    },
    {
      "Action": [
        "lambda:InvokeFunction",
        "execute-api:Invoke",
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.auth.arn}"
    }
  ]
}
EOF
}


################ DEPLOYMENT OF API GATEWAY ################

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gw.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api_gw.body))
  }

  depends_on = [
    aws_api_gateway_integration.get_integration,
    aws_api_gateway_integration.post_integration
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "gw_stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_gw.id
  stage_name    = var.profile
}

########### DYANMO DB ############

resource "aws_dynamodb_table" "tasks" {
  name           = "Tasks"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "TaskId"
  range_key      = "Task"

  attribute {
    name = "TaskId"
    type = "S"
  }

  attribute {
    name = "Task"
    type = "S"
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = false
  }

  tags = {
    Name        = "dynamodb-table-1"
  }
}


########### ELASTIC SEARCH ############


resource "aws_cloudwatch_log_group" "logs" {
  name = "log_group"
}


resource "aws_cloudwatch_log_stream" "log_stream" {
  name           = "LogStream"
  log_group_name = aws_cloudwatch_log_group.logs.name
}


resource "aws_cloudwatch_log_resource_policy" "log_policy" {
  policy_name = "log_policy"

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
CONFIG
}

resource "aws_lambda_permission" "cloudwatch-lambda-permission" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.get_tasks.arn}"
  principal = "logs.${var.aws_region}.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.logs.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "log_sbscr" {
  depends_on      = [aws_lambda_permission.cloudwatch-lambda-permission]
  destination_arn = aws_lambda_function.get_tasks.arn
  filter_pattern  = ""
  log_group_name  = aws_cloudwatch_log_group.logs.name
  name            = "logging_default"
}


variable "domain" {
  default = "policy_domain"
}
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_elasticsearch_domain" "elastic_search" {
  domain_name           = "serverless-log"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type = "t2.small.elasticsearch"
  }

  ebs_options{
      ebs_enabled = true
      volume_size = 10
  }

  access_policies = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "es:*",
      "Principal": {
        "AWS": "*"
      },
      "Effect": "Allow",
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.domain}/*",
      "Condition": {
        "IpAddress": {"aws:SourceIp": ["66.193.100.22/32"]}
      }
    }
  ]
}
POLICY

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.logs.arn
    log_type                 = "INDEX_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.logs.arn
    log_type                 = "SEARCH_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.logs.arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }
}

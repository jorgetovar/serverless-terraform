provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      created-by = "terraform"
    }
  }

}

resource "random_pet" "lambda_bucket_name" {
  prefix = "aws-community-builder"
  length = 2
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket     = aws_s3_bucket.lambda_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]

}

data "archive_file" "lambda_hello_world" {
  type        = "zip"
  source_dir  = "${path.module}/hello_world"
  output_path = "${path.module}/hello_world.zip"
}

resource "aws_s3_object" "lambda_hello_world" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "hello_world.zip"
  source = data.archive_file.lambda_hello_world.output_path
  etag   = filemd5(data.archive_file.lambda_hello_world.output_path)
}

resource "aws_lambda_function" "hello_world" {
  function_name    = "HelloCommunityBuilders"
  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key           = aws_s3_object.lambda_hello_world.key
  runtime          = "python3.9"
  handler          = "app.lambda_handler"
  source_code_hash = data.archive_file.lambda_hello_world.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
}

resource "aws_cloudwatch_log_group" "hello_world" {
  name              = "/aws/lambda/${aws_lambda_function.hello_world.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_api"
  protocol_type = "HTTP"
}


resource "aws_apigatewayv2_stage" "lambda" {
  api_id      = aws_apigatewayv2_api.lambda.id
  name        = "stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_log_group.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    }
    )
  }
}

resource "aws_apigatewayv2_integration" "hello_world" {
  api_id             = aws_apigatewayv2_api.lambda.id
  integration_uri    = aws_lambda_function.hello_world.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_world" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_world.id}"
}

resource "aws_cloudwatch_log_group" "api_log_group" {
  name              = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"
  retention_in_days = 14
}

resource "aws_lambda_permission" "api_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}


data "archive_file" "layer" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/layer.zip"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename                 = data.archive_file.layer.output_path
  layer_name               = "community-layer"
  source_code_hash         = data.archive_file.layer.output_base64sha256
  compatible_runtimes      = ["python3.9"]
  compatible_architectures = ["x86_64"]
}

resource "null_resource" "pip_install" {
  triggers = {
    shell_hash = sha256(file("${path.module}/hello_world/requirements.txt"))
  }

  provisioner "local-exec" {
    command = "python3 -m pip install -r ${path.module}/hello_world/requirements.txt -t ${path.module}/layer/python"
  }

  depends_on = [data.archive_file.layer]
}



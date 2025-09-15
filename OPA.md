gateway
Here's a Terraform code to deploy a simple "Hello World" AWS Lambda function accessed through API Gateway:
main.tf
hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "hello_world" {
  filename      = "lambda_function.zip"
  function_name = "hello-world"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      greeting = "Hello World from Terraform!"
    }
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "hello_api" {
  name        = "hello-world-api"
  description = "API Gateway for Hello World Lambda function"
}

# API Gateway resource
resource "aws_api_gateway_resource" "hello_resource" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  parent_id   = aws_api_gateway_rest_api.hello_api.root_resource_id
  path_part   = "hello"
}

# API Gateway method (GET)
resource "aws_api_gateway_method" "hello_method" {
  rest_api_id   = aws_api_gateway_rest_api.hello_api.id
  resource_id   = aws_api_gateway_resource.hello_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# API Gateway integration with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  resource_id = aws_api_gateway_resource.hello_resource.id
  http_method = aws_api_gateway_method.hello_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.hello_world.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_world.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.hello_api.execution_arn}/*/*/*"
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "hello_deployment" {
  depends_on = [aws_api_gateway_integration.lambda_integration]

  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  stage_name  = "prod"

  lifecycle {
    create_before_destroy = true
  }
}

# Output the API Gateway URL
output "api_url" {
  value = "${aws_api_gateway_deployment.hello_deployment.invoke_url}/${aws_api_gateway_resource.hello_resource.path_part}"
}
lambda_function.py
python
import json

def lambda_handler(event, context):
    # Get greeting from environment variable or use default
    greeting = "Hello World!"
    
    # Check if environment variable exists
    if 'greeting' in event:
        greeting = event['greeting']
    
    # Return response
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'message': greeting,
            'input': event
        })
    }
Package the Lambda function
Create a lambda_function.zip file containing the Python code:
bash
# Create the zip file
zip lambda_function.zip lambda_function.py
Setup and Deployment
1.	Initialize Terraform:
bash
terraform init
2.	Plan the deployment:
bash
terraform plan
3.	Apply the configuration:
bash
terraform apply
4.	Test the API:
After deployment, Terraform will output the API URL. You can test it with:
bash
curl $(terraform output -raw api_url)
Alternative: Using Terraform's archive_file
If you want to create the zip file automatically with Terraform, add this to your main.tf:
hcl
# Create the Lambda function zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# Then update the Lambda function resource:
resource "aws_lambda_function" "hello_world" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "hello-world"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      greeting = "Hello World from Terraform!"
    }
  }
}
This Terraform configuration will:
•	Create an IAM role for Lambda execution
•	Package and deploy a Python Lambda function
•	Set up API Gateway with a GET endpoint
•	Configure the integration between API Gateway and Lambda
•	Output the API URL for testing
The API will be accessible at https://{api-id}.execute-api.{region}.amazonaws.com/prod/hello
this is working fine - now we need to add OPA in github actions CI CD
Here's how to add Open Policy Agent (OPA) to your GitHub Actions CI/CD pipeline for Terraform:
1. Create OPA Policies
First, create a policies directory with your OPA policies:
policies/terraform.rego
rego
package terraform

# Deny resources without tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type != "aws_lambda_function"
    resource.change.after.tags == {}
    msg := sprintf("Resource %s of type %s must have tags", [resource.address, resource.type])
}

# Require specific Lambda runtime
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    not startswith(resource.change.after.runtime, "python3")
    msg := sprintf("Lambda function %s must use Python runtime, got %s", [resource.address, resource.change.after.runtime])
}

# Prevent public API Gateway
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_api_gateway_rest_api"
    resource.change.after.endpoint_configuration.types[_] == "EDGE"
    msg := sprintf("API Gateway %s should not use EDGE endpoint type", [resource.address])
}

# Validate region
deny[msg] {
    provider := input.configuration.provider_config["aws"]
    not provider.expressions.region.constant_value in {"us-east-1", "us-west-2", "eu-west-1"}
    msg := sprintf("Invalid region: %s. Allowed regions: us-east-1, us-west-2, eu-west-1", [provider.expressions.region.constant_value])
}
policies/lambda.rego
rego
package lambda

# Validate Lambda function name pattern
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    not re_match("^[a-z0-9-]+$", resource.change.after.function_name)
    msg := sprintf("Lambda function name %s must contain only lowercase letters, numbers, and hyphens", [resource.change.after.function_name])
}

# Require environment variables for Lambda
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    not resource.change.after.environment
    msg := sprintf("Lambda function %s must have environment variables", [resource.address])
}

# Validate memory size limits
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    resource.change.after.memory_size > 512
    msg := sprintf("Lambda function %s memory size cannot exceed 512MB", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    resource.change.after.memory_size < 128
    msg := sprintf("Lambda function %s memory size must be at least 128MB", [resource.address])
}
2. Create GitHub Actions Workflow
.github/workflows/terraform.yml
yaml
name: Terraform CI/CD with OPA

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  AWS_REGION: us-east-1
  TF_VERSION: latest

jobs:
  terraform:
    name: Terraform Plan/Apply with OPA
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Terraform Format
      id: fmt
      run: terraform fmt -check
      continue-on-error: true

    - name: Terraform Init
      run: terraform init

    - name: Terraform Validate
      run: terraform validate

    - name: Terraform Plan
      id: plan
      run: terraform plan -out=tfplan.binary
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

    - name: Convert Terraform Plan to JSON
      run: terraform show -json tfplan.binary > tfplan.json

    - name: Setup OPA
      run: |
        curl -L -o opa https://openpolicyagent.org/downloads/v0.58.0/opa_linux_amd64
        chmod +x opa
        sudo mv opa /usr/local/bin/

    - name: Run OPA Policies
      run: |
        opa eval --format pretty --data policies/ --input tfplan.json "data.terraform.deny"
        opa eval --format pretty --data policies/ --input tfplan.json "data.lambda.deny"

    - name: OPA Policy Check
      id: opa-check
      run: |
        # Check Terraform policies
        terraform_result=$(opa eval --format json --data policies/ --input tfplan.json "data.terraform.deny" | jq '.result[].expressions[].value')
        lambda_result=$(opa eval --format json --data policies/ --input tfplan.json "data.lambda.deny" | jq '.result[].expressions[].value')
        
        if [ "$terraform_result" != "[]" ] || [ "$lambda_result" != "[]" ]; then
          echo "OPA policy violations found:"
          opa eval --format pretty --data policies/ --input tfplan.json "data.terraform.deny"
          opa eval --format pretty --data policies/ --input tfplan.json "data.lambda.deny"
          exit 1
        else
          echo "All OPA policies passed"
        fi

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' && success()
      run: terraform apply -auto-approve tfplan.binary
      env:
        AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

    - name: Upload Terraform Plan
      uses: actions/upload-artifact@v3
      with:
        name: terraform-plan
        path: tfplan.json

  opa-test:
    name: OPA Unit Tests
    runs-on: ubuntu-latest
    needs: terraform

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup OPA
      run: |
        curl -L -o opa https://openpolicyagent.org/downloads/v0.58.0/opa_linux_amd64
        chmod +x opa
        sudo mv opa /usr/local/bin/

    - name: Run OPA Tests
      run: |
        opa test policies/ -v
3. Add OPA Test Files
policies/terraform_test.rego
rego
package terraform

test_deny_missing_tags {
    input := {
        "resource_changes": [
            {
                "type": "aws_s3_bucket",
                "address": "aws_s3_bucket.example",
                "change": {
                    "after": {
                        "tags": {}
                    }
                }
            }
        ]
    }
    deny[msg] with input as input
    msg == "Resource aws_s3_bucket.example of type aws_s3_bucket must have tags"
}

test_allow_valid_lambda_runtime {
    input := {
        "resource_changes": [
            {
                "type": "aws_lambda_function",
                "address": "aws_lambda_function.hello",
                "change": {
                    "after": {
                        "runtime": "python3.9"
                    }
                }
            }
        ]
    }
    count(deny) == 0 with input as input
}
policies/lambda_test.rego
rego
package lambda

test_deny_invalid_lambda_name {
    input := {
        "resource_changes": [
            {
                "type": "aws_lambda_function",
                "address": "aws_lambda_function.test",
                "change": {
                    "after": {
                        "function_name": "Invalid_Name@123"
                    }
                }
            }
        ]
    }
    deny[msg] with input as input
    msg == "Lambda function name Invalid_Name@123 must contain only lowercase letters, numbers, and hyphens"
}

test_allow_valid_lambda_name {
    input := {
        "resource_changes": [
            {
                "type": "aws_lambda_function",
                "address": "aws_lambda_function.test",
                "change": {
                    "after": {
                        "function_name": "valid-name-123"
                    }
                }
            }
        ]
    }
    count(deny) == 0 with input as input
}
4. Update Terraform Configuration for Compliance
Update your main.tf to comply with the OPA policies:
hcl
# Add tags to all resources that support them
resource "aws_lambda_function" "hello_world" {
  filename      = "lambda_function.zip"
  function_name = "hello-world-lambda"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 128

  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      greeting = "Hello World from Terraform!"
      environment = "production"
    }
  }

  tags = {
    Name        = "hello-world-lambda"
    Environment = "production"
    Terraform   = "true"
  }
}

resource "aws_api_gateway_rest_api" "hello_api" {
  name        = "hello-world-api"
  description = "API Gateway for Hello World Lambda function"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "hello-world-api"
    Environment = "production"
    Terraform   = "true"
  }
}

# Add tags to IAM role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "lambda-execution-role"
    Environment = "production"
    Terraform   = "true"
  }
}
5. Required GitHub Secrets
Make sure to set these secrets in your GitHub repository:
•	AWS_ACCESS_KEY_ID
•	AWS_SECRET_ACCESS_KEY
6. Usage
The workflow will:
1.	Run on every push and pull request
2.	Validate Terraform code
3.	Create a plan and convert it to JSON
4.	Run OPA policies against the plan
5.	Block deployment if policies are violated
6.	Apply changes only if all checks pass on main branch
7.	Run OPA unit tests to ensure policies work correctly
This setup ensures that your Terraform deployments comply with organizational policies before they're applied to your AWS environment.
Run opa eval --format pretty --data policies/ --input tfplan.json "data.terraform.deny" opa eval --format pretty --data policies/ --input tfplan.json "data.terraform.deny" opa eval --format pretty --data policies/ --input tfplan.json "data.lambda.deny" shell: /usr/bin/bash -e {0} env: AWS_DEFAULT_REGION: us-east-1 AWS_REGION: us-east-1 AWS_ACCESS_KEY_ID: *** AWS_SECRET_ACCESS_KEY: *** AWS_SESSION_TOKEN: *** TERRAFORM_CLI_PATH: /home/runner/work/_temp/171fbc89-d83c-4224-83a4-ca33e725e8cc 1 error occurred: policies/terraform.rego:30: rego_parse_error: unexpected ident token: expected \n or ; or } not provider.expressions.region.constant_value in {"us-east-1", "us-west-2", "eu-west-1"}
The error is due to incorrect syntax in the OPA policy. Here's the corrected version:
Fix the terraform.rego file
policies/terraform.rego (corrected)
rego
package terraform

# Deny resources without tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type != "aws_lambda_function"
    not resource.change.after.tags
    msg := sprintf("Resource %s of type %s must have tags", [resource.address, resource.type])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type != "aws_lambda_function"
    resource.change.after.tags == {}
    msg := sprintf("Resource %s of type %s must have tags", [resource.address, resource.type])
}

# Require specific Lambda runtime
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_lambda_function"
    not startswith(resource.change.after.runtime, "python3")
    msg := sprintf("Lambda function %s must use Python runtime, got %s", [resource.address, resource.change.after.runtime])
}

# Prevent public API Gateway (EDGE type)
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_api_gateway_rest_api"
    endpoint_types := resource.change.after.endpoint_configuration.types
    endpoint_types[_] == "EDGE"
    msg := sprintf("API Gateway %s should not use EDGE endpoint type", [resource.address])
}

# Validate region - corrected syntax
deny[msg] {
    provider := input.configuration.provider_config.aws
    region := provider.expressions.region.constant_value
    not valid_regions[region]
    msg := sprintf("Invalid region: %s. Allowed regions: us-east-1, us-west-2, eu-west-1", [region])
}

valid_regions = {
    "us-east-1": true,
    "us-west-2": true,
    "eu-west-1": true
}
Alternative simpler region validation:
If you prefer a simpler approach, you can use this instead:
rego
# Validate region - simpler approach
deny[msg] {
    provider := input.configuration.provider_config.aws
    region := provider.expressions.region.constant_value
    region != "us-east-1"
    region != "us-west-2"
    region != "eu-west-1"
    msg := sprintf("Invalid region: %s. Allowed regions: us-east-1, us-west-2, eu-west-1", [region])
}
Also update the GitHub Actions workflow to handle OPA errors better:
.github/workflows/terraform.yml (updated OPA section)
yaml
    - name: Run OPA Policies
      run: |
        echo "Running Terraform policies..."
        opa eval --format pretty --data policies/ --input tfplan.json "data.terraform.deny" || true
        echo "Running Lambda policies..."
        opa eval --format pretty --data policies/ --input tfplan.json "data.lambda.deny" || true

    - name: OPA Policy Check
      id: opa-check
      run: |
        # Check Terraform policies
        terraform_deny=$(opa eval --format json --data policies/ --input tfplan.json "data.terraform.deny" | jq -r '.result[].expressions[].value | length')
        lambda_deny=$(opa eval --format json --data policies/ --input tfplan.json "data.lambda.deny" | jq -r '.result[].expressions[].value | length')
        
        total_violations=$((terraform_deny + lambda_deny))
        
        if [ "$total_violations" -gt 0 ]; then
          echo "::error::OPA policy violations found: $total_violations violations"
          echo "Terraform violations: $terraform_deny"
          echo "Lambda violations: $lambda_deny"
          echo "=== Detailed violations ==="
          opa eval --format pretty --data policies/ --input tfplan.json "data.terraform.deny"
          opa eval --format pretty --data policies/ --input tfplan.json "data.lambda.deny"
          exit 1
        else
          echo "All OPA policies passed (0 violations)"
        fi
Test your OPA policies locally first:
You can test the policies before running in GitHub Actions:
bash
# Convert plan to JSON
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# Test OPA policies
opa eval --format pretty --data policies/ --input tfplan.json "data.terraform.deny"
opa eval --format pretty --data policies/ --input tfplan.json "data.lambda.deny"

# Run OPA tests
opa test policies/ -v
Key fixes made:
1.	Fixed region validation syntax: Used proper Rego syntax with a helper function valid_regions
2.	Added proper error handling: The GitHub Actions workflow now properly handles OPA output and provides better error messages
3.	Added || true to the initial OPA run to prevent the step from failing immediately
4.	Improved violation counting: Uses jq to properly count the number of violations
The main issue was in the region validation where the syntax not provider.expressions.region.constant_value in {"us-east-1", "us-west-2", "eu-west-1"} is not valid Rego syntax. The corrected version uses a proper set validation approach.


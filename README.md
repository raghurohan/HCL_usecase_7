Here is a detailed README.md file explaining the entire flow of your Lambda + API Gateway Terraform project from a basic learner’s perspective. It covers how each component is created, communicates, and works together.

⸻

## 🚀 Lambda + API Gateway Infrastructure with Terraform

# ✅ Overview

This project creates a simple serverless API using AWS Lambda and API Gateway, all managed by Terraform.
When a user sends an HTTP request to the API Gateway endpoint, it triggers the Lambda function, which returns a “Hello World” response.

⸻

# ✅ High-Level Architecture Flow

[Client (Browser, Postman)] 
         ↓
[API Gateway REST API] → [AWS Lambda Function] → [Response to Client]


⸻

# ✅ Components Breakdown

# 1️⃣ Terraform Configuration
	•	Terraform Provider
	•	Configures AWS as the provider.
	•	Example:

provider "aws" {
  region = "us-east-1"
}



⸻

# 2️⃣ IAM Role for Lambda
	•	Purpose:
The Lambda function needs an IAM Role with permissions to execute and write logs.
	•	How it works:
	•	The aws_iam_role.lambda_exec resource creates a role with a trust policy allowing AWS Lambda to assume it.
	•	Attached the predefined AWS policy AWSLambdaBasicExecutionRole for basic permissions (like writing logs to CloudWatch).

⸻

# 3️⃣ Lambda Function
	•	Purpose:
Runs your custom code (in this case, a simple Python “Hello World” function).
	•	Key configuration:

resource "aws_lambda_function" "hello_world" {
  filename      = "lambda_function.zip"
  function_name = "hello-world"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
}


	•	Environment Variables:
Allows you to pass config data like greeting.
	•	How it works in AWS:
The Lambda function is packaged into a .zip file and uploaded. AWS executes this code when invoked.

⸻

# 4️⃣ API Gateway Setup

4.1 API Gateway REST API
	•	Creates a new API instance (hello-world-api) that exposes HTTP endpoints to external clients.

4.2 API Resource and Method
	•	The /hello resource is created as the endpoint path.
	•	A GET method is created for that resource so users can send HTTP GET requests.

4.3 Integration with Lambda
	•	API Gateway is configured to proxy requests to the Lambda function using AWS_PROXY integration.
Example integration:

integration_http_method = "POST"
type                    = "AWS_PROXY"
uri                     = aws_lambda_function.hello_world.invoke_arn



⸻

# 5️⃣ Lambda Permission
	•	API Gateway needs permission to invoke the Lambda function.
This is configured by aws_lambda_permission.apigw_lambda with the correct source ARN.

⸻

# 6️⃣ API Deployment
	•	Once all configurations are ready, a deployment is created to make the API live in a specific stage (prod).
Example:

resource "aws_api_gateway_deployment" "hello_deployment" {
  rest_api_id = aws_api_gateway_rest_api.hello_api.id
  stage_name  = "prod"
}



⸻

# 7️ Output
	•	Terraform outputs the final URL of the API:

output "api_url" {
  value = "${aws_api_gateway_deployment.hello_deployment.invoke_url}/hello"
}



⸻

#  What Happens When You Make an API Call

Step	Process
1	Client (Postman or browser) sends a GET request to the API Gateway URL: https://{api_id}.execute-api.us-east-1.amazonaws.com/prod/hello
2	API Gateway receives the request and triggers the Lambda function (via the AWS_PROXY integration).
3	The Lambda function executes your Python code (lambda_handler) and returns the greeting message.
4	API Gateway returns the response back to the client.


⸻

#  Key AWS Services Involved

AWS Service	Purpose
IAM Role	Grants execution permission for Lambda.
Lambda	Runs your custom serverless code.
API Gateway	Exposes HTTP endpoints that invoke Lambda functions.
CloudWatch Logs	Collects logs from Lambda executions.


⸻

# Real Communication Flow Diagram

Client → HTTP GET → API Gateway → Lambda Execution → Response → API Gateway → Client


⸻

# Example Command to Run Terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes (deploy infra)
terraform apply


⸻

#  Extra Notes for Beginners
	•	Why AWS Proxy Integration (AWS_PROXY)?
It allows API Gateway to pass the entire HTTP request to Lambda and let the function handle the response formatting.
	•	Why IAM Role?
AWS securely requires Lambda functions to execute under a specific IAM Role with limited permissions for safety.
	•	Why Deployment and Stage?
Deployment helps us manage different environments (prod, dev, etc.).
Example URL:

https://{api_id}.execute-api.us-east-1.amazonaws.com/prod/hello



⸻

# Final Thoughts

This setup enables you to manage your infrastructure as code with Terraform in a reproducible way.
Once applied, you can send HTTP requests to the API and get dynamic responses from your Lambda.

⸻

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

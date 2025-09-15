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

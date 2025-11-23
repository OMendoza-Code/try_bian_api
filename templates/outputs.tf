# --------------------------------------------------------------------
# Outputs importantes
# --------------------------------------------------------------------

output "api_gateway_url" {
  description = "URL base del API Gateway"
  value       = "https://${aws_api_gateway_rest_api.party_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.stage.stage_name}"
}

output "lambda_functions" {
  description = "ARNs de las funciones Lambda creadas"
  value = {
    for key, lambda in aws_lambda_function.lambda : key => lambda.arn
  }
}

output "api_gateway_id" {
  description = "ID del API Gateway"
  value       = aws_api_gateway_rest_api.party_api.id
}

output "endpoints" {
  description = "Endpoints disponibles del API"
  value = {
    for key, path in local.lambdas : key => "https://${aws_api_gateway_rest_api.party_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.stage.stage_name}${path}"
  }
}

# --------------------------------------------------------------------
# Outputs de Redshift
# --------------------------------------------------------------------
output "redshift_endpoint" {
  description = "Endpoint de Redshift Serverless"
  value       = aws_redshiftserverless_workgroup.party_workgroup.endpoint[0].address
}

output "redshift_password_secret" {
  description = "ARN del secreto con la contraseña de Redshift"
  value       = aws_redshiftserverless_namespace.party_namespace.admin_password_secret_arn
}


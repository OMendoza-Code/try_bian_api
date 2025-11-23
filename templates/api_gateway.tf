# --------------------------------------------------------------------
# API Gateway REST
# --------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "party_api" {
  name        = "${var.project_name}-reference-directory"
  description = "BIAN Party Reference Directory API"
}

# Recurso root
data "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.party_api.id
  path        = "/"
}

# --------------------------------------------------------------------
# Crear recursos y métodos dinámicamente por Lambda
# --------------------------------------------------------------------

# Recurso base PartyReferenceDataDirectory
resource "aws_api_gateway_resource" "party_directory" {
  rest_api_id = aws_api_gateway_rest_api.party_api.id
  parent_id   = data.aws_api_gateway_resource.root.id
  path_part   = "PartyReferenceDataDirectory"
}

# Recurso {id}
resource "aws_api_gateway_resource" "party_id" {
  rest_api_id = aws_api_gateway_rest_api.party_api.id
  parent_id   = aws_api_gateway_resource.party_directory.id
  path_part   = "{id}"
}

# Recursos específicos para cada endpoint
resource "aws_api_gateway_resource" "endpoint" {
  for_each = {
    cr_retrieve               = "Retrieve"
    bq_reference_retrieve     = "Reference"
    bq_associations_retrieve  = "Associations"
    bq_demographics_retrieve  = "Demographics"
    bq_bankrelations_retrieve = "BankRelations"
  }

  rest_api_id = aws_api_gateway_rest_api.party_api.id
  parent_id   = aws_api_gateway_resource.party_id.id
  path_part   = each.value
}

# Recursos adicionales para los que necesitan más niveles
resource "aws_api_gateway_resource" "sub_id" {
  for_each = {
    bq_reference_retrieve     = "referenceid"
    bq_associations_retrieve  = "associationid"
    bq_demographics_retrieve  = "demographicsid"
    bq_bankrelations_retrieve = "bankrelationsid"
  }

  rest_api_id = aws_api_gateway_rest_api.party_api.id
  parent_id   = aws_api_gateway_resource.endpoint[each.key].id
  path_part   = "{${each.value}}"
}

resource "aws_api_gateway_resource" "final_retrieve" {
  for_each = {
    bq_reference_retrieve     = "bq_reference_retrieve"
    bq_associations_retrieve  = "bq_associations_retrieve"
    bq_demographics_retrieve  = "bq_demographics_retrieve"
    bq_bankrelations_retrieve = "bq_bankrelations_retrieve"
  }

  rest_api_id = aws_api_gateway_rest_api.party_api.id
  parent_id   = aws_api_gateway_resource.sub_id[each.key].id
  path_part   = "Retrieve"
}

# GET Methods
resource "aws_api_gateway_method" "get" {
  for_each = local.lambdas

  rest_api_id   = aws_api_gateway_rest_api.party_api.id
  resource_id   = each.key == "cr_retrieve" ? aws_api_gateway_resource.endpoint[each.key].id : aws_api_gateway_resource.final_retrieve[each.key].id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

# Integración Lambda Proxy
resource "aws_api_gateway_integration" "lambda_integration" {
  for_each = local.lambdas

  rest_api_id = aws_api_gateway_rest_api.party_api.id
  resource_id = each.key == "cr_retrieve" ? aws_api_gateway_resource.endpoint[each.key].id : aws_api_gateway_resource.final_retrieve[each.key].id
  http_method = aws_api_gateway_method.get[each.key].http_method
  type        = "AWS_PROXY"
  integration_http_method = "POST"
  uri         = aws_lambda_function.lambda[each.key].invoke_arn
}

# Permisos para que API Gateway invoque a la Lambda
resource "aws_lambda_permission" "apigw" {
  for_each = local.lambdas

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.party_api.execution_arn}/*/*"
}

# --------------------------------------------------------------------
# Deploy del API
# --------------------------------------------------------------------
resource "aws_api_gateway_deployment" "deploy" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
  ]

  rest_api_id = aws_api_gateway_rest_api.party_api.id
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.party_api.id
  stage_name    = var.environment
}

# --------------------------------------------------------------------
# API Key y Usage Plan
# --------------------------------------------------------------------
resource "aws_api_gateway_api_key" "api_key" {
  name = "${var.project_name}-api-key"
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name = "${var.project_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.party_api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }

  quota_settings {
    limit  = 100
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = 10
    burst_limit = 20
  }
}

resource "aws_api_gateway_usage_plan_key" "usage_plan_key" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
}
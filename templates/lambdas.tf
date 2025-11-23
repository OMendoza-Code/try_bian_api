# --------------------------------------------------------------------
# IAM Role para todas las Lambdas
# --------------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Política personalizada para Glue
resource "aws_iam_role_policy" "lambda_glue_policy" {
  name = "lambda-glue-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "VisualEditor0"
      Effect = "Allow"
      Action = [
        "glue:GetDatabase",
        "glue:GetTables",
        "glue:GetDatabases",
        "glue:GetTable"
      ]
      Resource = [
        "arn:aws:glue:*:244190103141:table/*/*",
        "arn:aws:glue:*:244190103141:database/*",
        "arn:aws:glue:*:244190103141:catalog/*",
        "arn:aws:glue:*:244190103141:catalog"
      ]
    }]
  })
}

# Política personalizada para KMS
resource "aws_iam_role_policy" "lambda_kms_policy" {
  name = "lambda-kms-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "VisualEditor0"
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:DescribeKey"
      ]
      Resource = "arn:aws:kms:*:244190103141:key/*"
    }]
  })
}

# Política para acceso a Redshift Data API
resource "aws_iam_role_policy" "lambda_redshift_policy" {
  name = "lambda-redshift-data-api-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "redshift-data:ExecuteStatement",
          "redshift-data:DescribeStatement",
          "redshift-data:GetStatementResult",
          "redshift-data:ListStatements"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "redshift-serverless:GetCredentials"
        ]
        Resource = "*"
      }
    ]
  })
}

# Archivo ZIP dummy
data "archive_file" "dummy_zip" {
  type        = "zip"
  output_path = "${path.module}/dummy.zip"
  source {
    content  = "def handler(event, context): return {'statusCode': 200}"
    filename = "lambda_function.py"
  }
}

# --------------------------------------------------------------------
# Mapa con las 5 Lambdas
# --------------------------------------------------------------------
locals {
  lambdas = {
    cr_retrieve             = "/PartyReferenceDataDirectory/{id}/Retrieve"
    bq_reference_retrieve   = "/PartyReferenceDataDirectory/{id}/Reference/{referenceid}/Retrieve"
    bq_associations_retrieve = "/PartyReferenceDataDirectory/{id}/Associations/{associationid}/Retrieve"
    bq_demographics_retrieve = "/PartyReferenceDataDirectory/{id}/Demographics/{demographicsid}/Retrieve"
    bq_bankrelations_retrieve = "/PartyReferenceDataDirectory/{id}/BankRelations/{bankrelationsid}/Retrieve"
  }
}

# --------------------------------------------------------------------
# Crear Lambdas dinámicamente
# --------------------------------------------------------------------
resource "aws_lambda_function" "lambda" {
  for_each = local.lambdas

  function_name = each.key
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  filename      = data.archive_file.dummy_zip.output_path
  
  environment {
    variables = {
      EXTERNAL_DATABASE   = var.glue_catalog_database
      REDSHIFT_DATABASE   = var.redshift_db_name
      REDSHIFT_WORKGROUP  = var.redshift_workgroup_name
      SCHEMA_NAME         = var.redshift_schema_name
      TABLE_NAME          = ""
    }
  }
  
  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}
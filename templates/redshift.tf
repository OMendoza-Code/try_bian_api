# --------------------------------------------------------------------
# IAM Role para Redshift Spectrum
# --------------------------------------------------------------------
resource "aws_iam_role" "redshift_spectrum_role" {
  name = "${var.project_name}-redshift-spectrum-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "redshift.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_spectrum_policy" {
  role       = aws_iam_role.redshift_spectrum_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_policy" "redshift_glue_lakeformation_policy" {
  name = "${var.project_name}-redshift-glue-lf-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "RedshiftPolicyForLF"
      Effect = "Allow"
      Action = [
        "glue:*",
        "lakeformation:GetDataAccess"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "redshift_glue_policy" {
  role       = aws_iam_role.redshift_spectrum_role.name
  policy_arn = aws_iam_policy.redshift_glue_lakeformation_policy.arn
}


# --------------------------------------------------------------------
# Redshift Serverless
# --------------------------------------------------------------------
resource "aws_redshiftserverless_namespace" "party_namespace" {
  namespace_name = var.redshift_namespace_name
  db_name        = var.redshift_db_name
  admin_username = var.redshift_admin_username
  manage_admin_password = true
  iam_roles      = [aws_iam_role.redshift_spectrum_role.arn]
}

resource "aws_redshiftserverless_workgroup" "party_workgroup" {
  namespace_name = aws_redshiftserverless_namespace.party_namespace.namespace_name
  workgroup_name = var.redshift_workgroup_name
  
  config_parameter {
    parameter_key   = "enable_user_activity_logging"
    parameter_value = "true"
  }
}

# Esperar a que Redshift esté disponible
resource "null_resource" "wait_redshift_available" {
  depends_on = [aws_redshiftserverless_workgroup.party_workgroup]

  provisioner "local-exec" {
    command = <<EOF
      echo "Esperando a que Redshift Serverless esté disponible..."
      for i in {1..30}; do
        aws redshift-serverless get-workgroup --workgroup-name ${aws_redshiftserverless_workgroup.party_workgroup.workgroup_name} --profile ${var.aws_profile} --region ${var.aws_region} > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          echo "Redshift disponible."
          exit 0
        fi
        echo "Aún no disponible, intentando de nuevo..."
        sleep 10
      done
      echo "Timeout esperando a Redshift"
      exit 1
    EOF
  }
}

# Schema externo para Spectrum
resource "aws_redshiftdata_statement" "spectrum_schema" {
  workgroup_name = aws_redshiftserverless_workgroup.party_workgroup.workgroup_name
  database       = var.redshift_db_name
  sql            = "CREATE EXTERNAL SCHEMA IF NOT EXISTS s3_data FROM DATA CATALOG DATABASE '${var.glue_catalog_database}' IAM_ROLE '${aws_iam_role.redshift_spectrum_role.arn}';"
  
  depends_on = [null_resource.wait_redshift_available]
}

# Tabla externa de ejemplo
resource "aws_redshiftdata_statement" "party_external_table" {
  workgroup_name = aws_redshiftserverless_workgroup.party_workgroup.workgroup_name
  database       = var.redshift_db_name
  sql               = <<-SQL
    CREATE EXTERNAL TABLE  s3_data.party_data_1 (
      party_id varchar(50),
      party_name varchar(200),
      party_type varchar(50),
      created_date date
    )
    STORED AS PARQUET
    LOCATION 's3://${var.s3_data_bucket}/${var.s3_data_prefix}';
  SQL
  
  depends_on = [aws_redshiftdata_statement.spectrum_schema]
}

# Vista sobre tabla externa
resource "aws_redshiftdata_statement" "party_view" {
  workgroup_name = aws_redshiftserverless_workgroup.party_workgroup.workgroup_name
  database       = var.redshift_db_name
  sql               = <<-SQL
    CREATE OR REPLACE VIEW party_summary AS
    SELECT 
      party_type,
      COUNT(*) as total_parties,
      MAX(created_date) as latest_date
    FROM s3_data.party_data_1
    GROUP BY party_type;
  SQL
  
  depends_on = [aws_redshiftdata_statement.party_external_table]
}

# Crear usuario IAM en Redshift para Lambda
resource "aws_redshiftdata_statement" "create_lambda_user" {
  workgroup_name = aws_redshiftserverless_workgroup.party_workgroup.workgroup_name
  database       = var.redshift_db_name
  sql            = "CREATE USER \"IAMR:${aws_iam_role.lambda_role.arn}\" WITH PASSWORD DISABLE;"
  
  depends_on = [aws_redshiftdata_statement.spectrum_schema]
}

# Permisos para el rol de Lambda en el schema
resource "aws_redshiftdata_statement" "grant_lambda_permissions" {
  workgroup_name = aws_redshiftserverless_workgroup.party_workgroup.workgroup_name
  database       = var.redshift_db_name
  sql            = "GRANT ALL ON SCHEMA s3_data TO \"IAMR:${aws_iam_role.lambda_role.arn}\";"
  
  depends_on = [aws_redshiftdata_statement.create_lambda_user]
}
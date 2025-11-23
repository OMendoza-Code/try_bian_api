# --------------------------------------------------------------------
# Variables del proyecto
# --------------------------------------------------------------------
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "api-bian"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil de AWS"
  type        = string
  default     = ""
}

# --------------------------------------------------------------------
# Variables de Lambda
# --------------------------------------------------------------------
variable "lambda_runtime" {
  description = "Runtime de las funciones Lambda"
  type        = string
  default     = "python3.12"
}

# --------------------------------------------------------------------
# Variables de Redshift
# --------------------------------------------------------------------
variable "redshift_namespace_name" {
  description = "Nombre del namespace de Redshift"
  type        = string
  default     = "ns-bancatlan-redshift"
}

variable "redshift_workgroup_name" {
  description = "Nombre del workgroup de Redshift"
  type        = string
  default     = "wg-redshift-bancatlan"
}

variable "redshift_db_name" {
  description = "Nombre de la base de datos principal"
  type        = string
  default     = "dev"
}

variable "glue_catalog_database" {
  description = "Base de datos del Data Catalog de Glue"
  type        = string
  default     = "awsdatacatalog"
}


variable "redshift_schema_name" {
  description = "Nombre del schema de Redshift para las Lambdas"
  type        = string
  default     = "awsdatacatalog"
}

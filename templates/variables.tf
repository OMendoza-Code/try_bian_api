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
  default     = "mfa"
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
  default     = "party-data-namespace"
}

variable "redshift_workgroup_name" {
  description = "Nombre del workgroup de Redshift"
  type        = string
  default     = "party-data-workgroup"
}

variable "redshift_db_name" {
  description = "Nombre de la base de datos principal"
  type        = string
  default     = "partydb"
}

variable "redshift_admin_username" {
  description = "Usuario administrador de Redshift"
  type        = string
  default     = "admin"
}

variable "spectrum_db_name" {
  description = "Nombre de la base de datos de Spectrum"
  type        = string
  default     = "spectrum"
}

variable "glue_catalog_database" {
  description = "Base de datos del Data Catalog de Glue"
  type        = string
  default     = "stnglbtec"
}

variable "s3_data_bucket" {
  description = "Bucket S3 para datos de Spectrum"
  type        = string
  default     = "tablas-bian"
}

variable "s3_data_prefix" {
  description = "Prefijo para datos en S3"
  type        = string
  default     = "party-data/"
}
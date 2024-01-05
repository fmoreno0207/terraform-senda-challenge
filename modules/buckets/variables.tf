variable "region" {
  description = "La región de AWS donde se creará el bucket"
  #default     = "us-east-1" # Puedes cambiar esto según tu región preferida
}

variable "bucket_name" {
  description = "El nombre único del bucket S3"
}

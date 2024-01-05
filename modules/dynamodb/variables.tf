variable "region" {
  description = "La región de AWS donde se creará la tabla DynamoDB"
}

variable "table_name" {
  description = "Nombre de la tabla DynamoDB"
}

variable "read_capacity" {
  description = "Capacidad de lectura provisionada"
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Capacidad de escritura provisionada"
  type        = number
  default     = 5
}
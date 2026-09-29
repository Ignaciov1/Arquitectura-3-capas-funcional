variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "ID de la AMI Ubuntu Server 24.04 LTS x86_64 en us-east-1"
  type        = string
  default     = "ami-0e86e20dae9224db8"
}

variable "instance_type" {
  description = "Tamano para las instancias de la aplicacion (construccion de imagenes Docker)"
  type        = string
  default     = "t3.medium"
}

variable "db_instance_type" {
  description = "Tamano para la instancia de base de datos MySQL"
  type        = string
  default     = "t3.small"
}
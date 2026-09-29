output "alb_url" {
  description = "URL publica del Application Load Balancer"
  value       = "http://${aws_lb.alb.dns_name}"
}

output "db_public_ip" {
  description = "IP publica de la base de datos para conexion SSH o EC2 Instance Connect"
  value       = aws_instance.database.public_ip
}

output "db_private_ip" {
  description = "IP privada que utilizan las instancias del ASG para conectar a MySQL"
  value       = aws_instance.database.private_ip
}

output "asg_name" {
  description = "Nombre del Auto Scaling Group generado"
  value       = aws_autoscaling_group.app_asg.name
}
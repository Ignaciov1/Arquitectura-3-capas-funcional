provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux_arm64" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ==========================================
# 1. RED (VPC /22 y 6 Subredes)
# ==========================================
resource "aws_vpc" "vpc_prod" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "VPC-EscolarOnline-Produccion" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_prod.id
  tags = { Name = "IGW-EscolarOnline" }
}

resource "aws_subnet" "sub_public_a" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "Subnet-Publica-A-Web" }
}

resource "aws_subnet" "sub_public_b" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "10.0.0.128/25"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "Subnet-Publica-B-Web" }
}

resource "aws_subnet" "sub_private_app_a" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "10.0.1.0/25"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  tags = { Name = "Subnet-Privada-A-App" }
}

resource "aws_subnet" "sub_private_app_b" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "10.0.1.128/25"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false
  tags = { Name = "Subnet-Privada-B-App" }
}

resource "aws_subnet" "sub_private_db_a" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "10.0.2.0/25"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false
  tags = { Name = "Subnet-Privada-A-Data" }
}

resource "aws_subnet" "sub_private_db_b" {
  vpc_id                  = aws_vpc.vpc_prod.id
  cidr_block              = "10.0.2.128/25"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false
  tags = { Name = "Subnet-Privada-B-Data" }
}

# ==========================================
# 2. ENRUTAMIENTO Y NAT GATEWAY
# ==========================================
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = { Name = "EIP-NAT-EscolarOnline" }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.sub_public_a.id
  tags = { Name = "NAT-GW-EscolarOnline" }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc_prod.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "RT-Publica-Web" }
}

resource "aws_route_table_association" "pub_a" {
  subnet_id      = aws_subnet.sub_public_a.id
  route_table_id = aws_route_table.rt_public.id
}
resource "aws_route_table_association" "pub_b" {
  subnet_id      = aws_subnet.sub_public_b.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.vpc_prod.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "RT-Privada-App-Data" }
}

resource "aws_route_table_association" "priv_app_a" {
  subnet_id      = aws_subnet.sub_private_app_a.id
  route_table_id = aws_route_table.rt_private.id
}
resource "aws_route_table_association" "priv_app_b" {
  subnet_id      = aws_subnet.sub_private_app_b.id
  route_table_id = aws_route_table.rt_private.id
}
resource "aws_route_table_association" "priv_db_a" {
  subnet_id      = aws_subnet.sub_private_db_a.id
  route_table_id = aws_route_table.rt_private.id
}
resource "aws_route_table_association" "priv_db_b" {
  subnet_id      = aws_subnet.sub_private_db_b.id
  route_table_id = aws_route_table.rt_private.id
}

# ==========================================
# 3. SEGURIDAD
# ==========================================
resource "aws_security_group" "sg_alb" {
  name        = "sg_alb_prod"
  description = "Acceso HTTP y HTTPS publico hacia el ALB"
  vpc_id      = aws_vpc.vpc_prod.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "SG-ALB-Publico" }
}

resource "aws_security_group" "sg_app" {
  name        = "sg_app_prod"
  description = "Trafico interno desde el ALB"
  vpc_id      = aws_vpc.vpc_prod.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_alb.id]
  }
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "SG-App-Privado" }
}

resource "aws_security_group" "sg_db" {
  name        = "sg_db_prod"
  description = "Acceso MySQL exclusivo desde la capa App"
  vpc_id      = aws_vpc.vpc_prod.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "SG-DB-Aislado" }
}

# ==========================================
# 4. BALANCEADOR DE CARGA
# ==========================================
resource "aws_lb" "alb" {
  name               = "escolaronline-alb-prod"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_alb.id]
  subnets            = [aws_subnet.sub_public_a.id, aws_subnet.sub_public_b.id]
  tags = { Name = "ALB-EscolarOnline-Prod" }
}

resource "aws_lb_target_group" "tg_front" {
  name     = "tg-front-prod"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_prod.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "listener_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_front.arn
  }
}

# ==========================================
# 5. CAPA DE DATOS
# ==========================================
resource "aws_instance" "database" {
  ami                    = data.aws_ami.amazon_linux_arm64.id
  instance_type          = "t4g.small"
  subnet_id              = aws_subnet.sub_private_db_a.id
  vpc_security_group_ids = [aws_security_group.sg_db.id]
  iam_instance_profile   = "LabInstanceProfile"

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker git
              systemctl enable --now docker
              usermod -aG docker ec2-user

              git clone https://github.com/Ignaciov1/microservicios-funcionales11.git /home/ec2-user/app
              chown -R ec2-user:ec2-user /home/ec2-user/app

              docker run -d \
                --name mysql-db \
                --restart always \
                -p 3306:3306 \
                -e MYSQL_ROOT_PASSWORD=root123 \
                -e MYSQL_DATABASE=escolar_online \
                -e MYSQL_USER=alumno \
                -e MYSQL_PASSWORD=alumno123 \
                -v "/home/ec2-user/app/1.6.4 desarrolloApp-ACT1.6/init.sql":/docker-entrypoint-initdb.d/init.sql \
                mysql:8.0
              EOF

  tags = { Name = "EC2-MySQL-Database-Prod" }

  depends_on = [
    aws_nat_gateway.nat_gw,
    aws_route_table_association.priv_db_a
  ]
}

# ==========================================
# 6. CAPA DE APLICACIÓN
# ==========================================
resource "aws_launch_template" "app_template" {
  name_prefix   = "escolaronline-prod-tpl-"
  image_id      = data.aws_ami.amazon_linux_arm64.id
  instance_type = "t4g.small"

  vpc_security_group_ids = [aws_security_group.sg_app.id]

  iam_instance_profile {
    name = "LabInstanceProfile"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted = true
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker git
              
              mkdir -p /usr/local/lib/docker/cli-plugins
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              systemctl enable --now docker
              usermod -aG docker ec2-user

              aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 314870398011.dkr.ecr.us-east-1.amazonaws.com

              git clone https://github.com/Ignaciov1/microservicios-funcionales11.git /home/ec2-user/app
              cd "/home/ec2-user/app/1.6.4 desarrolloApp-ACT1.6"

              echo "DB_HOST=${aws_instance.database.private_ip}" > .env
              chown -R ec2-user:ec2-user /home/ec2-user/app

              sleep 90

              docker compose -f docker-compose.aws.yml up -d
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "EC2-App-Instancia-Prod" }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "asg-escolaronline-prod"
  vpc_zone_identifier = [aws_subnet.sub_private_app_a.id, aws_subnet.sub_private_app_b.id]
  target_group_arns   = [aws_lb_target_group.tg_front.arn]

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  depends_on = [aws_instance.database]
}

# ==========================================
# 7. AWS BACKUP (Contingencia BD)
# ==========================================
resource "aws_backup_vault" "backup_vault" {
  name = "vault-escolaronline"
}

resource "aws_backup_plan" "backup_plan" {
  name = "plan-escolaronline-bd"

  rule {
    rule_name         = "respaldo-diario"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 5 ? * * *)" 
    lifecycle {
      delete_after = 7
    }
  }
}

resource "aws_backup_selection" "backup_selection" {
  iam_role_arn = data.aws_iam_role.lab_role.arn
  name         = "seleccion-bd-mysql"
  plan_id      = aws_backup_plan.backup_plan.id

  resources = [
    aws_instance.database.arn
  ]
}

# ==========================================
# 8. CERTIFICADO AUTOFIRMADO Y LISTENER HTTPS
# ==========================================
# Generar clave privada RSA
resource "tls_private_key" "alb_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generar certificado autofirmado
resource "tls_self_signed_cert" "alb_cert_local" {
  private_key_pem = tls_private_key.alb_key.private_key_pem

  subject {
    common_name  = "freshbox-local.com"
    organization = "FreshBox SpA"
  }

  validity_period_hours = 8760 # 1 año
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Importar el certificado a AWS ACM
resource "aws_acm_certificate" "alb_acm_cert" {
  private_key      = tls_private_key.alb_key.private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert_local.cert_pem
}

# Crear el Listener HTTPS en el ALB
resource "aws_lb_listener" "listener_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.alb_acm_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_front.arn
  }
}
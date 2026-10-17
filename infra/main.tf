# Infrastructure as Code de l'app (AWS) - analysée par Checkov, jamais appliquée pendant la démo.

provider "aws" {
  region = "eu-west-3"
}

resource "aws_s3_bucket" "invoices" {
  bucket = "shopnotes-invoices-demo"
}

# FIX-9 : tout accès public au bucket est bloqué
resource "aws_s3_bucket_public_access_block" "invoices" {
  bucket                  = aws_s3_bucket.invoices.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# FIX-10 : SSH limité au réseau d'administration (VPN), plus d'ouverture au monde
resource "aws_security_group" "app" {
  name        = "shopnotes-app"
  description = "Security group de l'application"

  ingress {
    description = "SSH admin via VPN uniquement"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "HTTPS sortant uniquement"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

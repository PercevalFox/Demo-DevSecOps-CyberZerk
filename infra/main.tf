# Infrastructure as Code de l'app (AWS) - analysée par Checkov, jamais appliquée pendant la démo.

provider "aws" {
  region = "eu-west-3"
}

# VULN-9 : bucket S3 des factures accessible publiquement
resource "aws_s3_bucket" "invoices" {
  bucket = "shopnotes-invoices-demo"
}

resource "aws_s3_bucket_public_access_block" "invoices" {
  bucket                  = aws_s3_bucket.invoices.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# VULN-10 : SSH ouvert au monde entier
resource "aws_security_group" "app" {
  name        = "shopnotes-app"
  description = "Security group de l'application"

  ingress {
    description = "SSH admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Sortie"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

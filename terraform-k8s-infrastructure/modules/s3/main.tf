resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = false  # يفضل تخليه false عشان ما يتمسحش بالغلط

  tags = {
    Name        = var.bucket_name
    Environment = "infra"
    CreatedBy   = "Terraform"
  }
}

# تفعيل النسخ (versioning) اختياري، مفيد لو هتخزن ملفات أو backups
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# تشفير افتراضي
resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


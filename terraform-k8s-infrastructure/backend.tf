terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-backend-atos"
    key            = "terraform/state/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}


terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-backend-atos "
    key            = "terraform/state/infra.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

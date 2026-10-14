terraform {
  backend "s3" {
    bucket       = "agri-pipeline-tfstate-478170046368"
    key          = "pipeline/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
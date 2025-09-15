terraform {
  backend "s3" {
    bucket        = "897722687643-web-tf-state-bucket"
    key           = "usecase7/terraform.tfstate"
    region        = "us-east-1"
    encrypt       = true
    use_lockfile  = true # Enables native S3 state locking
  }
}

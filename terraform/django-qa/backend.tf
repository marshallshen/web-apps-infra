terraform {
  backend "s3" {
    bucket = "web-apps-infra"
    key    = "terraform/django-qa"
    region = "us-east-1"
  }
}

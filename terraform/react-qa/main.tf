# AWS Region for S3 and other resources
provider "aws" {
  region  = "us-east-1"
}

# Variables
variable "fqdn" {
  description = "The fully-qualified domain name of the resulting S3 website."
  default     = "uat.hilinkdev.com"
}

variable "domain" {
  description = "The domain name."
  default     = "hilinkdev.com"
}

# Allowed IPs that can directly access the S3 bucket
variable "allowed_ips" {
  type = list(string)
  default = [
    "0.0.0.0/0" # public access
    # "xxx.xxx.xxx.xxx/mm" # restricted
    # "999.999.999.999/32" # invalid IP, completely inaccessible
  ]
}

# Using this module
module "main" {
  source = "../modules/aws-s3-cloudfront-website"

  fqdn                = "${var.fqdn}"
  ssl_certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"
  allowed_ips         = "${var.allowed_ips}"

  index_document = "index.html"
  error_document = "404.html"

  refer_secret = "${base64sha512("REFER-SECRET-19265125-${var.fqdn}-52865926")}"

  force_destroy = "true"

  # Optional override for PriceClass, defaults to PriceClass_100
  cloudfront_price_class = "PriceClass_200"
}


# ACM Certificate generation

resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.fqdn}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = "${data.aws_route53_zone.main.id}"
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = [for validation in aws_route53_record.cert_validation : validation.fqdn]
}


# Route 53 record for the static site

data "aws_route53_zone" "main" {
  name         = "${var.domain}"
  private_zone = false
}

resource "aws_route53_record" "web" {
  zone_id  = "${data.aws_route53_zone.main.zone_id}"
  name     = "${var.fqdn}"
  type     = "A"

  alias {
    name                   = "${module.main.cf_domain_name}"
    zone_id                = "${module.main.cf_hosted_zone_id}"
    evaluate_target_health = false
  }
}

# Outputs

output "s3_bucket_id" {
  value = "${module.main.s3_bucket_id}"
}

output "s3_bucket_arn" {
  value = "${module.main.s3_bucket_arn}"
}

output "s3_domain" {
  value = "${module.main.s3_website_endpoint}"
}

output "s3_hosted_zone_id" {
  value = "${module.main.s3_hosted_zone_id}"
}

output "cloudfront_domain" {
  value = "${module.main.cf_domain_name}"
}

output "cloudfront_hosted_zone_id" {
  value = "${module.main.cf_hosted_zone_id}"
}

output "cloudfront_distribution_id" {
  value = "${module.main.cf_distribution_id}"
}

output "route53_fqdn" {
  value = "${aws_route53_record.web.fqdn}"
}

output "acm_certificate_arn" {
  value = "${aws_acm_certificate_validation.cert.certificate_arn}"
}

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

locals {
  vm_count    = "3"
  vm_ip       = digitalocean_droplet.web.*.ipv4_address
  common_tags = ["devops", "vlad24081990_at_gmail_com"]
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

# Configure AWS Provider

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "eu-west-1"
}

data "digitalocean_ssh_key" "rebrain" {
  name = "REBRAIN.SSH.PUB.KEY"
}

resource "digitalocean_ssh_key" "vlad" {
  name       = "VLAD.SSH.PUB.KEY"
  public_key = var.ssh_key_vlad
}

# Configure VM
resource "digitalocean_droplet" "web" {
  count    = local.vm_count 
  image    = "ubuntu-20-04-x64"
  name     = "web-${count.index}"
  region   = "fra1"
  size     = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.rebrain.id, digitalocean_ssh_key.vlad.fingerprint]
  tags     = local.common_tags
}

# Configure DNS in route 53

data "aws_route53_zone" "selected" {
  name = "devops.rebrain.srwx.net"
}

resource "aws_route53_record" "devops_dns" {
  count   = local.vm_count 
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "vlad24081990-${count.index}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [element(local.vm_ip.*, count.index)]
}


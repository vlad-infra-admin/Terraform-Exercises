terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

locals {
  vm_count    = length(var.devs)
  vm_ip       = digitalocean_droplet.web.*.ipv4_address
  common_tags = ["devops", "vlad24081990_at_gmail_com"]

  file_content = [for i in range(local.vm_count) :
    templatefile(
      "${path.module}/vms_info.tftpl",
      {
        idx        = i + 1
        dns_name   = "${aws_route53_record.devops_dns.*.name[i]}"
        ip_address = "${local.vm_ip[i]}"
        password   = "${random_string.password.*.result[i]}"
      }
    )
  ]
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

resource "digitalocean_ssh_key" "personal" {
  name       = "PERSONAL.SSH.PUB.KEY"
  public_key = var.ssh_key_personal
}

#Generate passwords
resource "random_string" "password" {
  count   = local.vm_count
  length  = 16
  upper   = true
  lower   = true
  number  = true
  special = false
}

# Configure VMs
resource "digitalocean_droplet" "web" {
  count    = local.vm_count
  image    = "ubuntu-20-04-x64"
  name     = "web-${count.index}"
  region   = "fra1"
  size     = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.rebrain.id, digitalocean_ssh_key.personal.fingerprint]
  tags     = local.common_tags

  #Set user password for vms

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = file(var.ssh_private_key_path)
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 30",
      "sed -i '/^PasswordAuthentication/c PasswordAuthentication yes' /etc/ssh/sshd_config",
      "cat /etc/ssh/sshd_config | grep -i PasswordAuthentication",
      "/usr/bin/systemctl restart sshd.service",
      "/bin/echo -e '${element(random_string.password.*.result, count.index)}\n${element(random_string.password.*.result, count.index)}'| /usr/bin/passwd root",
    ]

  }
}

# Configure DNS in route 53

data "aws_route53_zone" "selected" {
  name = "devops.rebrain.srwx.net"
}

resource "aws_route53_record" "devops_dns" {
  count   = local.vm_count
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "${element(var.devs.*, count.index)}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [element(local.vm_ip.*, count.index)]
}

#Output passwords from instances
output "vm_passwords" {
  value = [for idx in range(local.vm_count) :
  "${aws_route53_record.devops_dns.*.name[idx]} (${local.vm_ip[idx]}) => ${random_string.password.*.result[idx]}"]
}

#Save infastructure info to a file
resource "local_file" "vms_info" {
  content  = "${join("", [for s in local.file_content : format("%s", s)])}"
  filename = "${path.module}/vms_info.txt"
}



variable "do_token" {
  type        = string
  description = "Digital Ocean token"
}

variable "ssh_key_personal" {
  type        = string
  description = "Personal SSH public key"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Personal SSH private key path"

}

variable "aws_access_key" {
  type        = string
  description = "AWS access key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
}

variable "devs" {
  type = list
  default = ["lb-vlad24081990","app1-vlad24081990","app2-vlad24081990"]
}


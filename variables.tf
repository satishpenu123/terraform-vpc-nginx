
#variables start
variable "cidrblk" {
  type = "string"
  default = "10.0.0.0/16"
}

variable "pubsubblk" {
  type = "string"
  default = "10.0.1.0/24"
}

variable "prvsubblk1" {
  type = "string"
  default = "10.0.2.0/24"
}

variable "key_name" {
  type = "string"
  default = "nginx_kp"
}

variable "ami_id" {
  type = "string"
  default = "ami-cd0f5cb6"
}

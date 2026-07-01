variable "environment" { type = string }
variable "app_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

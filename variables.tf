variable "instance_type_prometheus" {
    description = "This defines Prometheus Instance Size/Type"
    type        = string
    default     = ""
}
variable "volume_size_prometheus" {
    description = "This defines Prometheus Instance Root Volume Size"
    type        = number
    default     = ""
}
variable "key_name" {
    description = "This defines Prometheus Instance Pem Key Name"
    type        = string
    default     = ""
}
variable "environment" {
    description = "This defines the Environment Tag"
    type        = string
    default     = ""
}
variable "vpc_id" {
    description = "This defines Prometheus Instance VPC ID"
    type        = string
    default     = ""
}
variable "vpc_cidr_block" {
    description = "This defines Prometheus Instance VPC CIDR Block"
    type        = string
    default     = ""
}
variable "subnet_id" {
    description = "This defines Prometheus Instance VPC Subnet ID"
    type        = string
    default     = ""
}
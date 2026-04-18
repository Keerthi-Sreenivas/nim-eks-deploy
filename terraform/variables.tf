variable "region" {
  default = "us-east-1"
}

variable "gpu_min_nodes" {
  default = 1
}

variable "gpu_max_nodes" {
  default = 5
  description = "Maximum number of GPU nodes for autoscaling"
}

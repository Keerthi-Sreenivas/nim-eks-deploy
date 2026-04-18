variable "region" {
  default     = "us-east-1"
  description = "AWS region for the EKS cluster"
}

variable "gpu_min_nodes" {
  default     = 1
  description = "Minimum number of GPU nodes"
}

variable "gpu_max_nodes" {
  default     = 5
  description = "Maximum number of GPU nodes for autoscaling"
}

variable "project_name" {
  default = "django-ecs-image"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

# variable "private_subnets" {
#   type = map(object({
#     cidr = string
#     az   = string
#   }))

#   default = {
#     "subnet1" = {
#       cidr = "10.0.101.0/24"
#       az   = "us-east-1a"
#     }
#     "subnet2" = {
#       cidr = "10.0.102.0/24"
#       az   = "us-east-1b"
#     }
#   }
# }


variable "db" {
  description = "RDS PostgreSQL configuration"
  type = object({
    name                  = optional(string, "app")
    username              = optional(string, "appuser")
    instance_class        = optional(string, "db.t4g.micro")
    allocated_storage     = optional(number, 20)
    max_allocated_storage = optional(number, 100)
    engine_version        = optional(string, "17.9")
    backup_retention_days = optional(number, 7)
  })
  default = {}
}

variable "is_production" {
  description = "Whether this deployment is production"
  type        = bool
  default     = false
}

# ecs -----
variable "app_name" {
  type    = string
  default = "app"
}

variable "container_image" {
  type    = string
  default = "nginx:latest"
}

variable "container_name" {
  type    = string
  default = "app"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

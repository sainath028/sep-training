variable "type" {
    default = "t2.micro"
}
// Environment name, used as prefix to name resources.
variable "environment" {
  default = "dev"
}

// The allocated storage in gigabytes.
variable "rds_allocated_storage" {
  default = "5"
}

// The instance type of the RDS instance.
variable "rds_instance_class" {
  default = "db.t2.micro"
}

// Specifies if the RDS instance is multi-AZ.
variable "rds_multi_az" {
  default = "false"
}

// Username for the administrator DB user.
variable "mssql_admin_username" {
  default = "admin"
}

// Password for the administrator DB user.
variable "mssql_admin_password" {
  default = "admin123"
}

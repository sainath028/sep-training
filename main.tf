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

locals{
    environment ="dev"
    cidr_block_private = ["10.0.1.0/26","10.0.2.0/26"]
    cidr_block_public = ["10.0.3.0/26","10.0.4.0/26"]
    availability_zones = ["us-east-2a", "us-east-2b"]
    routetype = ["public", "private"]
    ami                        = "ami-046ba197a4a7f497e"
    amilinux = "ami-0b9064170e32bde34"
    key_name                   = "windows"
    type                       = var.type != "" ? var.type : "t2.micro"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${local.environment}-vpc"
    Environment = local.environment
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.cidr_block_public[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${local.environment}-public-subnet"
    Environment = local.environment
  }
}



resource "aws_subnet" "private_subnet" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.cidr_block_private[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${local.environment}-private-subnet"
    Environment = local.environment
  }
}

output "pvt" {
   value = aws_subnet.private_subnet.*.id
}
/*==== Subnets ======*/
/* Internet gateway for the public subnet */
resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name        = "${local.environment}-igw"
    Environment = "${local.environment}"
  }
}
/* Elastic IP for NAT */
resource "aws_eip" "nat_eip" {
  vpc        = true
  tags = {
    Name        = "${local.environment}-EIP"
    Environment = "${local.environment}"
  }  
}

/* NAT */
resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id     = aws_subnet.public_subnet[0].id
  tags = {
    Name        = "nat"
    Environment = "${local.environment}"
  }
}

/* Routing table for subnet */
resource "aws_route_table" "route" {
  count = length(local.routetype)
  vpc_id = "${aws_vpc.vpc.id}"
  tags = {
    Name        = "${local.environment}-${local.routetype[count.index]}-route-table"
    Environment = "${local.environment}"
  }
}

resource "aws_route" "route_pub" {
  route_table_id         = "${aws_route_table.route[0].id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ig.id}"
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = "${aws_route_table.route[1].id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
  depends_on = [aws_nat_gateway.nat]
}

/* Route table associations */
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public_subnet.*.id)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.route[0].id
}
resource "aws_route_table_association" "private" {
  #  for_each = var.azs
  count          = length(aws_subnet.private_subnet.*.id)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.route[1].id
}


/* security group for alb private */
resource "aws_security_group" "alb" {
  name        = "alb_security_group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.environment}-albprivate_security_group"
    Environment = local.environment
  }
}

/* alb */
resource "aws_lb" "alb" {
#  for_each = var.azs
  name            = "albprivate"
  security_groups = [aws_security_group.alb.id]
  subnets         = aws_subnet.private_subnet.*.id
  internal = true
  tags = {
    Name        = "${local.environment}-private-loadbalancer"
    Environment = local.environment
  }
}

/* security group for alb Public*/
resource "aws_security_group" "albpublic" {
  name        = "albpublic_security_group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.environment}-albpublic_security_group"
    Environment = local.environment
  }
}

/* alb */
resource "aws_lb" "albpublic" {
#  for_each = var.azs
  name            = "albpublic"
  security_groups = [aws_security_group.albpublic.id]
  subnets         = aws_subnet.public_subnet.*.id
  # internal = true
  tags = {
    Name        = "${local.environment}-public-loadbalancer"
    Environment = local.environment
  }
}

resource "aws_lb_target_group" "test" {
  name     = "private-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.test.arn
  count            = length(aws_instance.webserver.*.id)
  target_id        = aws_instance.webserver[count.index].id
  port             = 80
}


resource "aws_lb_listener" "private" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}

/* security group for MySQL */
resource "aws_security_group" "MySQL-SG" {
  name = "mysql-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "output from Bastion Host"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

/* Security Group for the Bastion Host! */
resource "aws_security_group" "BH-SG" {
  name = "bastion-host-sg"
  vpc_id = aws_vpc.vpc.id

  # Created an inbound rule for Bastion Host SSH
  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Created an inbound rule for WinRM Https
  ingress {
    description = "WinRM Https"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for WinRM Http
  ingress {
    description = "WinRM Http"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "Custom tcp"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "output from Bastion Host"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/* security group for  Bastion Host Access */
resource "aws_security_group" "DB-SG-SSH" {
  name = "db-sg-bastion-host"
  vpc_id = aws_vpc.vpc.id

  # Created an inbound rule for MySQL Bastion Host
  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    security_groups = [aws_security_group.BH-SG.id]
  }

  # Created an inbound rule for WinRM Https
  ingress {
    description = "WinRM Https"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    security_groups = [aws_security_group.BH-SG.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Created an inbound rule for ssh 
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.BH-SG.id]
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Created an inbound rule for WinRM Http
  ingress {
    description = "WinRM Http"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    security_groups = [aws_security_group.BH-SG.id]
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Custom tcp"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.BH-SG.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.BH-SG.id]
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "output from MySQL BH"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.environment}-db-sg-bastion-host"
    Environment = local.environment
  }
}


/* AWS instance for the webserver */
resource "aws_instance" "webserver" {
  count = 2
  ami = local.ami
  instance_type = local.type
  associate_public_ip_address = false
  subnet_id = aws_subnet.private_subnet[count.index].id
  key_name = local.key_name
  vpc_security_group_ids = [aws_security_group.MySQL-SG.id, aws_security_group.DB-SG-SSH.id]
  tags = {
   Name = "webserver"
  }
}

/* AWS instance for the Bastion windows */
resource "aws_instance" "Bastion-Host" {
  ami = local.ami
  instance_type = local.type
  subnet_id = aws_subnet.public_subnet[0].id
  key_name = local.key_name
  vpc_security_group_ids = [aws_security_group.BH-SG.id]
  tags = {
   Name = "Bastion_Windows"
  }
}

/* AWS instance for the Bastion linux */
resource "aws_instance" "Bastion-linux" {
  ami = local.amilinux
  instance_type = local.type
  subnet_id = aws_subnet.public_subnet[0].id
  key_name = local.key_name
  vpc_security_group_ids = [aws_security_group.BH-SG.id]
  tags = {
   Name = "Bastion_linux"
  }
}

/* RDS */

# resource "aws_db_subnet_group" "default_rds_mssql" {
#   name        = "${var.environment}-rds-mssql-subnet-group"
#   //  count          = length(aws_subnet.private_subnet.*.id)
#   subnet_ids  = aws_subnet.private_subnet.*.id

#   tags = {
#     Name = "${var.environment}-rds-mssql-subnet-group"
#     Env  = "${var.environment}"
#   }
# }

# resource "aws_security_group" "rds_mssql_security_group" {
#   name        = "${var.environment}-all-rds-mssql-internal"
# //  description = "${var.environment} allow all vpc traffic to rds mssql."
#   vpc_id      = aws_vpc.vpc.id

#   ingress {
#     from_port   = 1433
#     to_port     = 1433
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.environment}-all-rds-mssql-internal"
#     Env  = "${var.environment}"
#   }
# }

# resource "aws_db_instance" "default_mssql" {
#   depends_on                = ["aws_db_subnet_group.default_rds_mssql"]
#   identifier                = "${var.environment}-mssql"
#   allocated_storage         = var.rds_allocated_storage
#   license_model             = "license-included"
#   storage_type              = "gp2"
#   engine                    = "sqlserver-se"
#   engine_version            = "12.00.4422.0.v1"
#   instance_class            = var.rds_instance_class
#   multi_az                  = var.rds_multi_az
#   username                  = var.mssql_admin_username
#   password                  = "${var.mssql_admin_password}"
#   vpc_security_group_ids    = [aws_security_group.rds_mssql_security_group.id]
#   db_subnet_group_name      = aws_db_subnet_group.default_rds_mssql.id
#   backup_retention_period   = 3
# //  skip_final_snapshot       = var.skip_final_snapshot
# //  final_snapshot_identifier = "${var.environment}-mssql-final-snapshot"
# }

locals{
    environment ="dev"
    cidr_block_private = ["10.0.1.0/26","10.0.2.0/26"]
    cidr_block_public = ["10.0.3.0/26","10.0.4.0/26"]
    availability_zones = ["us-east-2a", "us-east-2b"]
    routetype = ["public", "private"]
    amilinux = "ami-02d1e544b84bf7502"
    key_name                   = "windows"
    type                       = "t2.micro"
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
  load_balancer_arn = aws_lb.albpublic.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test.arn
  }
}


/* security group for EC2 */
resource "aws_security_group" "ec2" {
  name = "db-sg-host"
  vpc_id = aws_vpc.vpc.id

  /* Created an inbound rule for ssh */
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Custom tcp"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = [aws_security_group.albpublic.id]
  }

  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.albpublic.id]
  }
  egress {
    description = "output from MySQL BH"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.environment}-sg-ec2"
    Environment = local.environment
  }
}

resource "aws_ecr_repository" "hello-world" {
  name                 = "hello-world"
  image_tag_mutability = "MUTABLE"

  tags = {
    project = "hello-world"
  }
}

resource "aws_iam_role" "ec2_role_hello_world" {
  name = "ec2_role_hello_world"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = {
    project = "hello-world"
  }
}

resource "aws_iam_instance_profile" "ec2_profile_hello_world" {
  name = "ec2_profile_hello_world"
  role = aws_iam_role.ec2_role_hello_world.name
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.ec2_role_hello_world.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_instance" "webserver" {
  count = 2
  ami = local.amilinux
  instance_type = local.type
  key_name = local.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile_hello_world.name
  subnet_id = aws_subnet.public_subnet[count.index].id
  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
  EOF
  tags = {
    Name = "webserver"
  }
}

/* RDS */

resource "aws_db_subnet_group" "default_rds_mssql" {
  name        = "${var.environment}-rds-mssql-subnet-group"
  //  count          = length(aws_subnet.private_subnet.*.id)
  subnet_ids  = aws_subnet.private_subnet.*.id

  tags = {
    Name = "${var.environment}-rds-mssql-subnet-group"
    Env  = "${var.environment}"
  }
}

resource "aws_security_group" "rds_sql_security_group" {
  name        = "${var.environment}-all-rds-sql-internal"
//  description = "${var.environment} allow all vpc traffic to rds mssql."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-all-rds-sql-internal"
    Env  = "${var.environment}"
  }
}

resource "aws_db_instance" "default_sql" {
  depends_on                = ["aws_db_subnet_group.default_rds_mssql"]
  identifier                = "${var.environment}-mssql"
  allocated_storage         = var.rds_allocated_storage
  engine                    = "mysql"
  engine_version            = "5.7"
  instance_class            = var.rds_instance_class
  # name                 = "mydb"
  username                  = var.mssql_admin_username
  password                  = var.mssql_admin_password
  parameter_group_name      = "default.mysql5.7"
  skip_final_snapshot       = true
}

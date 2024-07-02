provider "aws" {
  # Credentials should be picked from ~/.aws/credentials
  region     = "ap-south-1"
}
# main vpc
resource "aws_vpc" "main_vpc" {
  cidr_block = "${var.cidrblk}"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "apsouthvpc"
  }
}

resource "aws_subnet" "public_subnet_ap_south_1a" {
  vpc_id                  = "${aws_vpc.main_vpc.id}"
  cidr_block              = "${var.pubsubblk}"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  tags = {
  	Name =  "Subnet public az 1a"
  }
}

resource "aws_subnet" "private_subnet_ap_south_1b" {
  vpc_id                  = "${aws_vpc.main_vpc.id}"
  cidr_block              = "${var.prvsubblk1}"
  availability_zone = "ap-south-1b"
  tags = {
  	Name =  "Subnet private 1 az 1b"
  }
}
 
#create internet gateway
resource "aws_internet_gateway" "vpcigw" {
  vpc_id = "${aws_vpc.main_vpc.id}"
  tags {
        Name = "InternetGateway"
    }
}
#Add igw route to main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.vpcigw.id}"
}


resource "aws_eip" "tuto_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.vpcigw"]
}

#Allows the instances in private subnet to connect to internet for downloading packages
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.tuto_eip.id}"
    subnet_id = "${aws_subnet.public_subnet_ap_south_1a.id}"
    depends_on = ["aws_internet_gateway.vpcigw"]
}

resource "aws_route_table" "private_route_table" {
    vpc_id = "${aws_vpc.main_vpc.id}"

    tags {
        Name = "Private route table"
    }
}

resource "aws_route" "private_route" {
	route_table_id  = "${aws_route_table.private_route_table.id}"
	destination_cidr_block = "0.0.0.0/0"
	nat_gateway_id = "${aws_nat_gateway.nat.id}"
}

# Associate subnet public_subnet_ap_south_1a to public route table
resource "aws_route_table_association" "public_subnet_ap_south_1a_association" {
    subnet_id = "${aws_subnet.public_subnet_ap_south_1a.id}"
    route_table_id = "${aws_vpc.main_vpc.main_route_table_id}"
}

# Associate subnet private_subnet_ap_south_1b to private route table
resource "aws_route_table_association" "pri_subnet_ap_south_1b_association" {
    subnet_id = "${aws_subnet.private_subnet_ap_south_1b.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}

resource "aws_security_group" "pub" {
  name        = "ec2_pub_sg"
  description = "Used in the terraform"

  vpc_id = "${aws_vpc.main_vpc.id}"
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
      ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.cidrblk}"]
  }
    # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = ["aws_internet_gateway.vpcigw"]
  
}

resource "aws_security_group" "prv" {
  name        = "ec2_prv_sg"
  description = "Used in the terraform"

  vpc_id = "${aws_vpc.main_vpc.id}"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidrblk}"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.cidrblk}"]
	}
 ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["${var.cidrblk}"]
  }

# outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = ["aws_internet_gateway.vpcigw"]
  
}
resource "aws_instance" "webpub" {
  instance_type = "t2.micro"
  ami = "${var.ami_id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.pub.id}"]
  subnet_id              = "${aws_subnet.public_subnet_us_east_1a.id}"
  user_data              = "${file("userdata.sh")}"
  tags {
    Name = "webserverpub"
  }
}

resource "aws_instance" "webprv" {
  instance_type = "t2.micro"
  ami = "${var.ami_id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.prv.id}"]
  subnet_id              = "${aws_subnet.private_1_subnet_us_east_1b.id}"
  user_data              = "${file("userdata.sh")}"
  tags {
    Name = "webserverprv1"
  }
}


module "admin-sns-email-topic" {
    source = "github.com/deanwilson/tf_sns_email"

    display_name  = "WebApp health Check Notifications"
    email_address = "amjadhussain3751@gmail.com"
    owner         = "Amjad"
    stack_name    = "admin-sns-email"
}

resource "aws_cloudwatch_metric_alarm" "webappalarm" {
  alarm_name = "webapphealthcheckalarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "HealthCheckStatus"
  namespace = "AWS/Route53"
  period = "60"
  statistic = "Minimum"
  threshold = "0"
  alarm_description = "This metric monitor whether the app is down or not."
  alarm_actions = ["${module.admin-sns-email-topic.arn}"]
  insufficient_data_actions = []
}


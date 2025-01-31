# Prestashop Web Application Deployment with Terraform
## Overview
This project automates the deployment of a PrestaShop e-commerce platform on AWS using Terraform. It provisions an EC2 instance running PrestaShop via Docker and an RDS MySQL database for persistent storage. 
## Prerequisites
To use this Terraform configuration, ensure you have the following installed:

* Terraform: [Installation Guide](https://developer.hashicorp.com/terraform/install)
* AWS Account: Ensure you have an AWS account and the necessary permissions to create resources such as EC2, VPC, RDS, etc.
* AWS CLI: [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
* SSH Key Pair: You need to have an SSH key pair created in AWS for accessing your EC2 instance.

## Introduction
This project demonstrates the process of deploying a fully functional PrestaShop web application on AWS using Terraform. The setup involves creating AWS resources such as a Virtual Private Cloud (VPC), subnets, an EC2 instance, an RDS MySQL database, and security groups. However, the key focus of this project is to simplify the whole setup process by using Docker for the application deployment while ensuring that the database is hosted separately from the application server.

## Project Structure
```bash
├── main.tf               # Main Terraform configuration file for AWS resources
├── variables.tf          # Variables used in Terraform configuration
├── outputs.tf            # Outputs from the Terraform configuration
├── scripts/              # Scripts directory containing setup scripts
│   └── install-docker.sh # Shell script to install Docker and PrestaShop
```

## Project Repo

```bash

git clone https://github.com/Nsisong-hub/My-prestashop-terraform-doc.git

```

## Configuration Files Breakdown
**main.tf** 

***Provider Configuration***
* Set up Terraform to use AWS as the cloud provider and specify the region
```bash
provider "aws" {
  region = "us-east-1"
}
```
***VPC Creation***
* Configure a Virtual Private Cloud (VPC) to isolate your infrastructure
```bash
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "Prestashop-VPC" }
}
```
***Internet Gateway***
* Create an internet gateway to enable internet access for resources within your VPC
* Attach the internet gateway to th VPC
```bash
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "Prestashop-Internet-Gateway" }
}
```
***Public Subnets***
* Create two public subnets that automatically assigns public IPs to instances
* And ensures that both are in different availability zones
  
```bash
resource "aws_subnet" "public_subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"  
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "Prestashop-Public-Subnet1"
  }
}
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"  
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"  # Ensure a different AZ
  tags = {
    Name = "Prestashop-Public-Subnet2"
  }
}
```
***Route Tables***

* Create Routes Table and Associate it with the Public Subnets
```bash
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "Prestashop-Public-Route-Table"
  }
}
resource "aws_route_table_association" "public_subnet1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_subnet2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public.id
}
```


***Security Groups for EC2 instance***
* Define security group allowing SSH (22) and HTTP (80) traffic for the EC2 instance

```bash

resource "aws_security_group" "ec2" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "Prestashop-EC2-SG" }
}
```


 ***Security Group for RDS***
 *  Create a security group for your RDS database
 *  Allow an incoming traffic on port 3306 (MySQL) from the subnets where your EC2 instance is located
 *  Be sure to replace the `cidr_blocks` with  your actual subnet CIDRs
```bash
resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24", "10.0.3.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Prestashop-RDS-SG"
  }
}
```
***Create an RDS MySQL Database***
* Replace the `db_name` with your db_name
* Replace the `username` with your username
* Replace the `password` with your password
* Set publicly_acessible to `false` since its a database
* Attach the RDS instance to the security group `aws_security_group.rds`
* Specify the subnet group which the RDS instance will belong to
* You may skip final snapshot to avoid error when running terraform destroy
  
```bash  
resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "prestashopdb"  
  username             = "admin"         
  password             = "Password123" 
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name = aws_db_subnet_group.main.name

#Skip final snapshot to avoid error when run terraform destroy
  skip_final_snapshot = true
}
```
***Create an RDS DB Subnet Group***
* Ensure the the subnets are in different AZs
```bash
resource "aws_db_subnet_group" "main" {
  name       = "prestashop-rds-subnet-group"
  subnet_ids = [
    aws_subnet.public_subnet1.id,
    aws_subnet.public_subnet2.id, 
  ]
  tags = {
    Name = "prestashop-rds-subnet-group"
  }
}

```
***EC2 Instance***
* Launch an EC2 instance running Ubuntu and give it a descriptive name
* Update the ami with the correct AMI for Ubuntu in us-east-1 on your account
* Use a t2.micro instance type free tier
* Assign the EC2 instance to a public subnet,so it can have internet access
* Attach a security group (ec2) to the EC2 instance
* Replace the `mykeypair` with your key pair name
* Using user data script, install Docker and Prestashop
```bash
resource "aws_instance" "prestashop" {
  ami           = "ami-04b4f1a9cf54c11d0"    
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet1.id
  security_groups = [aws_security_group.ec2.id]
  key_name      = "mykeypair"
  user_data = file("scripts/install-docker.sh")
  tags = { Name = "Prestashop-EC2" }
}
```
`scripts/install-docker.sh`
* This script runs on the EC2 instance to install Docker, start the Docker service, and run PrestaShop in a Docker container
*  It ensures the web server can execute necessary files but prevents unauthorized modifications
*  Deletes the `install` directory after PrestaShop installation is complete
*  Renames the `admin` directory to a randomly generated name
*  *Note: These are common security practices that should not be negleted*
```bash
#!/bin/bash
apt-get update -y
apt-get install -y docker.io
systemctl start docker
systemctl enable docker

docker run -d --name prestashop -p 80:80 -e DB_SERVER="${rds_endpoint}" -e DB_USER="admin" -e DB_PASSWD="P@ssword123" prestashop/prestashop

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
rm -rf /var/www/html/install
mv /var/www/html/admin /var/www/html/admin4931y4sdr0f62y5yad4

```
**Variables.tf**
* Define the input variables  to be used in the Terraform configuration
* In my case, the region `us-east-1` and the VPC CIDR block `10.0.0.0/16`

```bash
variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

```

**Outputs.tf**
* Define the output variables to print out the values after Terraform applies the configuration
* In my case, after Terraform applies the configuration, it prints out the following values:
* **prestashop_public_ip**: The public IP of the EC2 instance.
* **rds_endpoint:** The endpoint of the MySQL database.
* **prestashop_url:** The full URL to access the PrestaShop application.


```bash
output "prestashop_public_ip" {
  value = aws_instance.prestashop.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "prestashop_url" {
  value = "http://${aws_instance.prestashop.public_ip}"
}
```
## Deployment Steps
**Clone the Repository**
* Clone this repository to your local machine:
 

 ```bash
git clone https://github.com/Nsisong-hub/My-prestashop-terraform-doc.git
cd prestashop-terraform
  ```
**Initialize Terraform**
* Run the following command to initialize Terraform and download the necessary provider plugins:
```bash
terraform init
```
**Validate Configuration:** 
* Run the following command to validate the Terraform configuration
```bash
terraform validate
```
**Plan the Infrastructure**
```bash
terraform plan
```
**Apply Configuration:**
* Run the following command to apply the Terraform configuration
```bash
terraform apply
```
*Note: Terraform will display the changes it intends to make. Type `yes` to proceed*

## Access PrestaShop
* Once the deployment is complete, the public IP of your EC2 instance and other output values will be displayed on screen
* So, locate the public IP of your EC2 instance and the copy it
* To access your PrestaShop web application, open a web browser and go to:
  
```arduino
http://<prestashop_public_ip>

```
## Images
<img width="1120" alt="pd41" src="https://github.com/user-attachments/assets/bdcad335-df95-4372-806f-80ea70a091ac" />

<img width="1120" alt="pd42" src="https://github.com/user-attachments/assets/8ae1fd0d-d7c7-41da-aea0-8a7b7ea1e13b" />

* Choose your language and then click on Next. You should see the following page
  
  <img width="1120" alt="pd43" src="https://github.com/user-attachments/assets/cb51002c-57c8-4527-9313-4fb026973490" />

* Accept the license and click on the Next. You should see the following page

   <img width="1120" alt="pd44" src="https://github.com/user-attachments/assets/1b2b5997-ffd1-438c-9444-a1e7e9653db5" />
   
 <img width="1120" alt="pd45" src="https://github.com/user-attachments/assets/2d686b75-89c9-49e3-8498-38704bebf11b" />
 
* Provide your site information and click on the Next. You should see the following page

<img width="1120" alt="pd46" src="https://github.com/user-attachments/assets/34d15705-20a0-4e07-a8db-550e841b2451" />

<img width="1118" alt="pd47" src="https://github.com/user-attachments/assets/8bc0b1d3-ddc8-4327-96b8-03f098f57cc0" />

* Provide your database information and click on the Next. You should see the following page
  
  <img width="1120" alt="pd48" src="https://github.com/user-attachments/assets/c5a46e66-7dcc-4657-bf4c-f4a3800a92bc" />
  
* Click on the “Manage your store“ or "Discover your store" You will be redirected to the following pages
  <img width="1120" alt="n1" src="https://github.com/user-attachments/assets/5dcad432-0ada-4586-8db5-3078d6b35c9f" />
  <img width="1120" alt="n2" src="https://github.com/user-attachments/assets/c8fe5daa-23e3-4b8a-839c-f7d4e1a76b36" />
  <img width="1120" alt="n3" src="https://github.com/user-attachments/assets/342880d9-a3bb-4ee2-b9a0-b8d186a81750" />
  <img width="1112" alt="n5" src="https://github.com/user-attachments/assets/1098c781-6ec3-4041-86f8-a849f4309d42" />

  # Conclusion
This solution ensures that the database is not hosted on the same server as the application and here is how; the MySQL database is hosted on Amazon RDS, a separate managed service provided by AWS. This guarantees the database is on a different server, physically and logically separate from the EC2 instance running the PrestaShop application. Secondly the connection between PrestaShop (running on the EC2 instance) and the MySQL database (hosted on RDS) is configured via the RDS endpoint as no database is installed or hosted on the EC2 instance itself. And lastly, the whole deployment process is simplified by running the PrestaShop application via Docker on the EC2 instance where the PrestaShop and its dependencies already are pre-packaged in the Docker image, thereby reducing manual setup.

# References
* [PrestaShop Installation on AWS with EC2 Instance Connect](https://github.com/Nsisong-hub/My-Prestashop-Documentation.git)
* [Terraform Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
  
# Author                                                                  
**Nsisong Etim**                                                               
 *Contact: You can always reach me on [Linkedln](https://www.linkedin.com/in/nsisong-etim-64589126a)*











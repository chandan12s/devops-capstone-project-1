data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "k8s_node" {
  key_name   = "${var.project_name}-k8s-node-key"
  public_key = var.ssh_public_key
}

# Security group: locked to YOUR IP only for SSH and the Kubernetes API.
# NodePort range is open broadly since that's how we'll reach the app
# itself (no load balancer - those cost money / need public IPs too).
resource "aws_security_group" "k8s_node" {
  name        = "${var.project_name}-k8s-node-sg"
  description = "Security group for the single-node kubeadm cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH - restricted to my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Kubernetes API server - restricted to my IP"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "NodePort range - for reaching the app directly"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound (package installs, ECR pulls, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-k8s-node-sg" }
}

# IAM role so the node can authenticate to ECR without storing any keys
resource "aws_iam_role" "k8s_node" {
  name = "${var.project_name}-k8s-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "k8s_node_ecr_readonly" {
  role       = aws_iam_role.k8s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "k8s_node" {
  name = "${var.project_name}-k8s-node-profile"
  role = aws_iam_role.k8s_node.name
}

resource "aws_instance" "k8s_node" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.k8s_node.id]
  iam_instance_profile        = aws_iam_instance_profile.k8s_node.name
  key_name                    = aws_key_pair.k8s_node.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  user_data                   = file("${path.module}/scripts/bootstrap-k8s.sh")
  user_data_replace_on_change = true

  tags = { Name = "${var.project_name}-k8s-node" }
}
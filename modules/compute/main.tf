data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name = "${var.project_name}-${var.environment}-sg"
  description = "Security group for EC2"
  vpc_id = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
  description = "ArgoCD NodePort"
  from_port   = 30000
  to_port     = 32767
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
#   ingress {
#   description = "K3s API"
#   from_port   = 6443
#   to_port     = 6443
#   protocol    = "tcp"
#   cidr_blocks = ["YOUR_IP/32"]
# } # For Future: I Will Replace YOUR_IP with my actual IP address to allow access to K3s API from my machine

}
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name
}


resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
            #!/bin/bash
            exec > /var/log/user-data-debug.log 2>&1
            set -x

            echo "User data script started..."

            apt update -y
            apt install -y curl

            echo "Installing k3s..."

            curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

            echo "Checking if k3s installed..."

            if [ ! -f /usr/local/bin/kubectl ]; then
              echo "kubectl not found. k3s installation failed."
              exit 1
            fi

            echo "Waiting for k3s..."
            until /usr/local/bin/kubectl get nodes; do
              sleep 5
            done

            echo "Installing ArgoCD..."
            /usr/local/bin/kubectl create namespace argocd || true
            /usr/local/bin/kubectl apply -n argocd \
              -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

            echo "Waiting for ArgoCD server..."
            until /usr/local/bin/kubectl get pods -n argocd | grep argocd-server | grep Running; do
              sleep 10
            done

            echo "Patching ArgoCD service..."
            /usr/local/bin/kubectl patch svc argocd-server -n argocd \
            -p '{"spec": {"type": "NodePort", "ports":[{"port":80,"targetPort":8080,"nodePort":30080}]}}'

            echo "Creating application namespace..."
            /usr/local/bin/kubectl create namespace dev-research-app || true

            echo "Creating ArgoCD Application..."
            cat <<APP | /usr/local/bin/kubectl apply -f -
            apiVersion: argoproj.io/v1alpha1
            kind: Application
            metadata:
              name: research-app
              namespace: argocd
            spec:
              project: default
              source:
                repoURL: https://github.com/Lukky175/research-summarizer-k8s.git
                targetRevision: HEAD
                path: .
              destination:
                server: https://kubernetes.default.svc
                namespace: dev-research-app
              syncPolicy:
                automated:
                  prune: true
                  selfHeal: true
            APP

            echo "Bootstrap complete."
            EOF
              
  tags = {
    Name = "${var.project_name}-${var.environment}-ec2"

  }
}

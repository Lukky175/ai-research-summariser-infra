data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# tfsec:ignore:aws-ec2-no-public-ingress-sgr
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for EC2"
  vpc_id      = var.vpc_id

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

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  associate_public_ip_address = true

  metadata_options {
    http_tokens   = "required" #Prevents SSRF (Server-Side Request Forgery) Attacks by requiring IMDSv2 for metadata access.
    http_endpoint = "enabled"
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }
  user_data = <<-EOF
            #!/bin/bash

            # Redirect all output to log file for debugging
            exec > /var/log/user-data-debug.log 2>&1
            set -euxo pipefail

            echo "===== EC2 Bootstrap Started ====="

            ############################################
            # Install required packages
            ############################################
            apt update -y
            apt install -y curl

            ############################################
            # Install k3s (Lightweight Kubernetes)
            ############################################
            echo "Installing k3s..."
            curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik" sh -

            # Verify kubectl is installed
            if [ ! -f /usr/local/bin/kubectl ]; then
              echo "kubectl not found. k3s installation failed."
              exit 1
            fi

            ############################################
            # Wait for Kubernetes node to become Ready
            ############################################
            echo "Waiting for Kubernetes node to become Ready..."
            echo "Waiting for Kubernetes API to be ready..."
            # Wait until kubectl can talk to API
            until kubectl get nodes >/dev/null 2>&1; do
              echo "Waiting for API..."
              sleep 5
            done

            echo "Waiting for node to become Ready..."
            until kubectl get nodes | grep -q " Ready "; do
              kubectl get nodes
              sleep 5
            done

            echo "Cluster is Ready. Waiting extra 15 seconds for full stabilization..."
            sleep 15

            ############################################
            # Configure kubeconfig properly
            ############################################
            echo "Configuring kubeconfig..."

            mkdir -p /root/.kube
            cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
            chmod 600 /root/.kube/config

            export KUBECONFIG=/root/.kube/config
            echo "KUBECONFIG set to $KUBECONFIG"

            kubectl get nodes
            sleep 5
            ############################################
            # Install Helm
            ############################################
            echo "Installing Helm..."
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
            echo "helm version"
            helm version

            ############################################
            # Install NGINX Ingress Controller
            ############################################
            echo "Installing NGINX Ingress Controller..."

            helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
            helm repo update

            kubectl create namespace ingress-nginx || true

            helm install ingress-nginx ingress-nginx/ingress-nginx \
              --namespace ingress-nginx

            echo "Waiting for NGINX Ingress to be ready..."
            kubectl wait --for=condition=Ready pod --all -n ingress-nginx --timeout=300s

            ############################################
            # Install cert-manager
            ############################################
            echo "Installing cert-manager..."

            helm repo add jetstack https://charts.jetstack.io
            helm repo update

            kubectl create namespace cert-manager || true

            helm install cert-manager jetstack/cert-manager \
              --namespace cert-manager \
              --set installCRDs=true

            echo "Waiting for cert-manager pods..."
            kubectl wait --for=condition=Ready pod --all -n cert-manager --timeout=300s

            ############################################
            # Create Let's Encrypt ClusterIssuer
            ############################################
            echo "Creating ClusterIssuer..."

            cat <<ClusterIssuer | kubectl apply -f -
            apiVersion: cert-manager.io/v1
            kind: ClusterIssuer
            metadata:
              name: letsencrypt-prod
            spec:
              acme:
                email: lakshit175@gmail.com
                server: https://acme-v02.api.letsencrypt.org/directory
                privateKeySecretRef:
                  name: letsencrypt-prod
                solvers:
                - http01:
                    ingress:
                      class: nginx
            ClusterIssuer

            ############################################
            # Install ArgoCD
            ############################################
            echo "Installing ArgoCD..."

            kubectl create namespace argocd || true

            kubectl apply -n argocd \
              --server-side \
              -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

            ############################################
            # Wait for ALL ArgoCD components to be Ready
            ############################################
            echo "Waiting for ArgoCD components to be ready..."
            kubectl wait --for=condition=Ready pod --all -n argocd --timeout=300s

            ############################################
            # Create Application Namespace
            ############################################
            kubectl create namespace dev-research-app || true

            ############################################
            # Create ArgoCD GitOps Application
            ############################################
            echo "Creating ArgoCD Application..."

            cat <<APP | kubectl apply -f -
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
                path: overlays/dev
              destination:
                server: https://kubernetes.default.svc
                namespace: dev-research-app
              syncPolicy:
                automated:
                  prune: true
                  selfHeal: true
            APP

            ############################################
            # Install Prometheus Community Helm Repo
            ############################################
            echo "Installing Prometheus Community Helm Repo..."
            helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
            helm repo update

            ############################################
            # Creating monitoring namespace for Prometheus and Grafana
            ############################################
            echo "Creating monitoring namespace for Prometheus and Grafana..."
            kubectl create namespace monitoring || true

            ############################################
            # Install kube-prometheus-stack (Prometheus + Grafana) using Helm
            ############################################
            echo "Installing kube-prometheus-stack (Prometheus + Grafana) using Helm..."
            helm install monitoring prometheus-community/kube-prometheus-stack \
              --namespace monitoring

            echo "Waiting for Prometheus and Grafana pods to be ready..."
            kubectl wait --for=condition=Ready pod --all -n monitoring --timeout=600s
            kubectl get pods -n monitoring
 
            echo "===== Bootstrap Complete ====="

            EOF
  tags = {
    Name = "${var.project_name}-${var.environment}-ec2"

  }
}

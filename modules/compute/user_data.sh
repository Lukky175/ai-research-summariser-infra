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
            # Configure ArgoCD to run without internal TLS
            ############################################
            echo "Configuring ArgoCD insecure mode..."

            kubectl patch configmap argocd-cmd-params-cm -n argocd \
              --type merge \
              -p '{"data":{"server.insecure":"true"}}'

            kubectl rollout restart deployment argocd-server -n argocd

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

            ############################################
            # Install External Secrets Operator using Helm
            ############################################
            echo "Installing External Secrets Operator using Helm..."
            helm repo add external-secrets https://charts.external-secrets.io
            helm repo update

            kubectl create namespace external-secrets || true

            helm upgrade external-secrets external-secrets/external-secrets \
                -n external-secrets \
                --set hostNetwork=true
                
            echo "===== Bootstrap Complete ====="

            EOF
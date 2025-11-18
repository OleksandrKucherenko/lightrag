# Cloud Deployment Guide for LightRAG

This guide provides step-by-step instructions for deploying the LightRAG Kubernetes stack to major cloud providers.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Azure (AKS)](#azure-aks)
- [AWS (EKS)](#aws-eks)
- [Google Cloud (GKE)](#google-cloud-gke)
- [DigitalOcean (DOKS)](#digitalocean-doks)
- [Civo](#civo)
- [Cost Comparison](#cost-comparison)
- [Best Practices](#best-practices)

## Prerequisites

### Common Requirements

- Cloud provider account with billing enabled
- Command-line tools installed:
  - `kubectl` (Kubernetes CLI)
  - Provider-specific CLI (az, aws, gcloud, doctl, civo)
- OpenAI API keys (or compatible LLM provider)
- Domain name (optional, for production deployments)

### Resource Requirements

**Minimum cluster specs:**
- **Nodes**: 2-3 worker nodes
- **CPU per node**: 4 cores
- **RAM per node**: 16GB
- **Storage**: 100GB+ SSD
- **Total**: ~12 CPU cores, 32-48GB RAM

**Recommended for production:**
- **Nodes**: 3-5 worker nodes
- **CPU per node**: 8 cores
- **RAM per node**: 32GB
- **Storage**: 200GB+ NVMe SSD
- **Total**: 24-40 CPU cores, 96-160GB RAM

---

## Azure (AKS)

### 1. Install Azure CLI

```bash
# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# macOS
brew install azure-cli

# Windows
# Download from https://aka.ms/installazurecliwindows

# Login
az login
```

### 2. Create Resource Group

```bash
# Set variables
export RESOURCE_GROUP="lightrag-rg"
export LOCATION="eastus"  # or westeurope, westus2, etc.
export CLUSTER_NAME="lightrag-aks"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 3. Create AKS Cluster

```bash
# Create cluster with autoscaling
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 5 \
  --network-plugin azure \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME

# Verify connection
kubectl get nodes
```

### 4. Install NGINX Ingress Controller

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace ingress-nginx \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

### 5. Configure Storage

```bash
# AKS uses Azure Disk by default
# Check available storage classes
kubectl get storageclass

# Use 'managed-premium' for production (SSD)
# Update k8s/03-storage.yaml to set storageClassName: managed-premium
```

### 6. Deploy LightRAG

```bash
# Create secrets
kubectl create namespace lightrag

kubectl create secret generic lightrag-secrets \
  --namespace=lightrag \
  --from-literal=REDIS_PASSWORD='your-secure-password' \
  --from-literal=LLM_BINDING_API_KEY='sk-your-llm-key' \
  --from-literal=EMBEDDING_BINDING_API_KEY='sk-your-embedding-key' \
  --from-literal=OPENAI_API_KEY='sk-your-openai-key' \
  --from-literal=LIGHTRAG_API_KEY='your-lightrag-key' \
  --from-literal=LOBECHAT_ACCESS_CODE='dev-access-2024'

kubectl create secret generic redis-secret \
  --namespace=lightrag \
  --from-literal=password='your-secure-password'

# Deploy using Helm
helm install lightrag ./helm/lightrag \
  --namespace lightrag \
  --values - <<EOF
global:
  publishDomain: lightrag.yourdomain.com
  storageClass: managed-premium

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    enabled: true
    secretName: lightrag-tls

redis:
  persistence:
    storageClass: managed-premium

memgraph:
  persistence:
    data:
      storageClass: managed-premium
    logs:
      storageClass: managed-premium

qdrant:
  persistence:
    storage:
      storageClass: managed-premium
    snapshots:
      storageClass: managed-premium
EOF
```

### 7. Configure DNS

```bash
# Get external IP
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "External IP: $EXTERNAL_IP"

# Add A records in your DNS provider:
# lightrag.yourdomain.com -> $EXTERNAL_IP
# *.lightrag.yourdomain.com -> $EXTERNAL_IP
```

### 8. Install cert-manager (Optional - for HTTPS)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create Let's Encrypt issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Cost Estimation (Azure)

**Monthly costs (estimated):**
- AKS control plane: Free
- 3x Standard_D4s_v3 nodes: ~$350/month
- Storage (100GB premium SSD): ~$15/month
- Load Balancer: ~$20/month
- **Total**: ~$385/month

---

## AWS (EKS)

### 1. Install AWS CLI and eksctl

```bash
# Install AWS CLI
# Linux/macOS
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure

# Install eksctl
# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# macOS
brew install eksctl
```

### 2. Create EKS Cluster

```bash
# Set variables
export CLUSTER_NAME="lightrag-eks"
export REGION="us-east-1"  # or eu-west-1, us-west-2, etc.

# Create cluster configuration
cat > cluster-config.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
  version: "1.28"

managedNodeGroups:
  - name: lightrag-nodes
    instanceType: t3.xlarge
    desiredCapacity: 3
    minSize: 2
    maxSize: 5
    volumeSize: 100
    volumeType: gp3
    privateNetworking: true
    ssh:
      allow: false
    labels:
      role: worker
    tags:
      Environment: production
      Application: lightrag

iam:
  withOIDC: true

addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy
  - name: aws-ebs-csi-driver
EOF

# Create cluster
eksctl create cluster -f cluster-config.yaml

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify
kubectl get nodes
```

### 3. Install AWS Load Balancer Controller

```bash
# Create IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 4. Install NGINX Ingress Controller

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb"
```

### 5. Configure Storage

```bash
# EKS uses EBS CSI driver
# Check storage classes
kubectl get storageclass

# Use 'gp3' for production (cost-effective SSD)
```

### 6. Deploy LightRAG

```bash
# Create namespace and secrets
kubectl create namespace lightrag

# Create secrets (same as Azure section)
kubectl create secret generic lightrag-secrets \
  --namespace=lightrag \
  --from-literal=REDIS_PASSWORD='your-secure-password' \
  --from-literal=LLM_BINDING_API_KEY='sk-your-llm-key' \
  --from-literal=EMBEDDING_BINDING_API_KEY='sk-your-embedding-key' \
  --from-literal=OPENAI_API_KEY='sk-your-openai-key' \
  --from-literal=LIGHTRAG_API_KEY='your-lightrag-key'

kubectl create secret generic redis-secret \
  --namespace=lightrag \
  --from-literal=password='your-secure-password'

# Deploy with Helm
helm install lightrag ./helm/lightrag \
  --namespace lightrag \
  --set global.storageClass=gp3 \
  --set ingress.enabled=true \
  --set ingress.className=nginx
```

### 7. Configure DNS

```bash
# Get load balancer hostname
LB_HOSTNAME=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Load Balancer: $LB_HOSTNAME"

# Create Route53 records or use CNAME in your DNS provider
# lightrag.yourdomain.com -> $LB_HOSTNAME
```

### Cost Estimation (AWS)

**Monthly costs (estimated):**
- EKS control plane: $72/month
- 3x t3.xlarge instances: ~$300/month
- Storage (300GB gp3): ~$25/month
- Network Load Balancer: ~$20/month
- Data transfer: ~$20-50/month
- **Total**: ~$437-467/month

---

## Google Cloud (GKE)

### 1. Install gcloud CLI

```bash
# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# macOS
brew install google-cloud-sdk

# Initialize
gcloud init
gcloud auth login
```

### 2. Create GKE Cluster

```bash
# Set variables
export PROJECT_ID="your-project-id"
export CLUSTER_NAME="lightrag-gke"
export REGION="us-central1"
export ZONE="${REGION}-a"

# Set project
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com

# Create cluster
gcloud container clusters create $CLUSTER_NAME \
  --zone $ZONE \
  --num-nodes 3 \
  --machine-type n2-standard-4 \
  --disk-type pd-ssd \
  --disk-size 100 \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 5 \
  --enable-autorepair \
  --enable-autoupgrade \
  --release-channel regular \
  --workload-pool=${PROJECT_ID}.svc.id.goog

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE

# Verify
kubectl get nodes
```

### 3. Install NGINX Ingress Controller

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

### 4. Configure Storage

```bash
# GKE uses pd-standard by default
# Check storage classes
kubectl get storageclass

# Use 'pd-ssd' for better performance
```

### 5. Deploy LightRAG

```bash
# Create namespace and secrets
kubectl create namespace lightrag

kubectl create secret generic lightrag-secrets \
  --namespace=lightrag \
  --from-literal=REDIS_PASSWORD='your-secure-password' \
  --from-literal=LLM_BINDING_API_KEY='sk-your-llm-key' \
  --from-literal=EMBEDDING_BINDING_API_KEY='sk-your-embedding-key' \
  --from-literal=OPENAI_API_KEY='sk-your-openai-key'

kubectl create secret generic redis-secret \
  --namespace=lightrag \
  --from-literal=password='your-secure-password'

# Deploy with Helm
helm install lightrag ./helm/lightrag \
  --namespace lightrag \
  --set global.storageClass=pd-ssd \
  --set ingress.enabled=true \
  --set ingress.className=nginx
```

### 6. Configure DNS

```bash
# Get external IP
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "External IP: $EXTERNAL_IP"

# Configure Cloud DNS or external DNS provider
# Point your domain to $EXTERNAL_IP
```

### 7. Configure Google Cloud DNS (Optional)

```bash
# Create DNS zone
gcloud dns managed-zones create lightrag-zone \
  --dns-name="lightrag.yourdomain.com." \
  --description="LightRAG DNS zone"

# Add A record
gcloud dns record-sets create lightrag.yourdomain.com. \
  --zone=lightrag-zone \
  --type=A \
  --ttl=300 \
  --rrdatas=$EXTERNAL_IP

# Add wildcard record
gcloud dns record-sets create "*.lightrag.yourdomain.com." \
  --zone=lightrag-zone \
  --type=A \
  --ttl=300 \
  --rrdatas=$EXTERNAL_IP
```

### Cost Estimation (GKE)

**Monthly costs (estimated):**
- GKE control plane: $73/month (Autopilot) or Free (Standard)
- 3x n2-standard-4 instances: ~$360/month
- Storage (300GB pd-ssd): ~$52/month
- Load Balancer: ~$18/month
- Network egress: ~$20-50/month
- **Total**: ~$523-603/month (Standard), ~$450-530/month (Autopilot)

---

## DigitalOcean (DOKS)

### 1. Install doctl CLI

```bash
# Linux
cd /tmp
wget https://github.com/digitalocean/doctl/releases/download/v1.100.0/doctl-1.100.0-linux-amd64.tar.gz
tar xf doctl-1.100.0-linux-amd64.tar.gz
sudo mv doctl /usr/local/bin

# macOS
brew install doctl

# Authenticate
doctl auth init
```

### 2. Create DOKS Cluster

```bash
# Set variables
export CLUSTER_NAME="lightrag-doks"
export REGION="nyc1"  # or sfo3, lon1, fra1, etc.

# List available regions
doctl kubernetes options regions

# List available node sizes
doctl kubernetes options sizes

# Create cluster
doctl kubernetes cluster create $CLUSTER_NAME \
  --region $REGION \
  --version latest \
  --node-pool "name=lightrag-pool;size=s-4vcpu-8gb;count=3;auto-scale=true;min-nodes=2;max-nodes=5" \
  --wait

# Get kubeconfig
doctl kubernetes cluster kubeconfig save $CLUSTER_NAME

# Verify
kubectl get nodes
```

### 3. Install NGINX Ingress Controller

```bash
# DigitalOcean has built-in support for NGINX
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/do-loadbalancer-protocol"="http" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/do-loadbalancer-algorithm"="round_robin"
```

### 4. Configure Storage

```bash
# DOKS uses DigitalOcean Block Storage
# Check storage class
kubectl get storageclass

# Use 'do-block-storage' (default)
```

### 5. Deploy LightRAG

```bash
# Create namespace and secrets
kubectl create namespace lightrag

kubectl create secret generic lightrag-secrets \
  --namespace=lightrag \
  --from-literal=REDIS_PASSWORD='your-secure-password' \
  --from-literal=LLM_BINDING_API_KEY='sk-your-llm-key' \
  --from-literal=EMBEDDING_BINDING_API_KEY='sk-your-embedding-key' \
  --from-literal=OPENAI_API_KEY='sk-your-openai-key'

kubectl create secret generic redis-secret \
  --namespace=lightrag \
  --from-literal=password='your-secure-password'

# Deploy with Helm
helm install lightrag ./helm/lightrag \
  --namespace lightrag \
  --set global.storageClass=do-block-storage \
  --set ingress.enabled=true \
  --set ingress.className=nginx
```

### 6. Configure DNS

```bash
# Get load balancer IP
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "External IP: $EXTERNAL_IP"

# Configure DigitalOcean DNS or external provider
# Create A records pointing to $EXTERNAL_IP
```

### 7. Configure DigitalOcean DNS (Optional)

```bash
# Create domain
doctl compute domain create lightrag.yourdomain.com

# Add A record
doctl compute domain records create lightrag.yourdomain.com \
  --record-type A \
  --record-name @ \
  --record-data $EXTERNAL_IP \
  --record-ttl 3600

# Add wildcard record
doctl compute domain records create lightrag.yourdomain.com \
  --record-type A \
  --record-name "*" \
  --record-data $EXTERNAL_IP \
  --record-ttl 3600
```

### Cost Estimation (DigitalOcean)

**Monthly costs (estimated):**
- Control plane: Free
- 3x s-4vcpu-8gb droplets: ~$144/month ($48 each)
- Storage (300GB): ~$30/month ($0.10/GB)
- Load Balancer: $12/month
- Bandwidth: Included (1TB per droplet)
- **Total**: ~$186/month

**Best value for small to medium deployments!**

---

## Civo

### 1. Install Civo CLI

```bash
# Linux/macOS
curl -sL https://civo.com/get | sh

# Or with Homebrew
brew install civo

# Authenticate
civo apikey add my-key YOUR_API_KEY
civo apikey current my-key
```

### 2. Create Civo Cluster

```bash
# Set variables
export CLUSTER_NAME="lightrag-civo"
export REGION="NYC1"  # or LON1, FRA1

# List available regions
civo region ls

# List available sizes
civo size ls

# Create cluster
civo kubernetes create $CLUSTER_NAME \
  --nodes 3 \
  --size g4s.kube.medium \
  --region $REGION \
  --wait \
  --save \
  --merge

# Verify
kubectl get nodes
```

### 3. Install NGINX Ingress Controller

```bash
# Civo has marketplace apps, but we'll use Helm for consistency
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

### 4. Configure Storage

```bash
# Civo uses local storage by default
kubectl get storageclass

# Use 'civo-volume' for persistent storage
```

### 5. Deploy LightRAG

```bash
# Create namespace and secrets
kubectl create namespace lightrag

kubectl create secret generic lightrag-secrets \
  --namespace=lightrag \
  --from-literal=REDIS_PASSWORD='your-secure-password' \
  --from-literal=LLM_BINDING_API_KEY='sk-your-llm-key' \
  --from-literal=EMBEDDING_BINDING_API_KEY='sk-your-embedding-key' \
  --from-literal=OPENAI_API_KEY='sk-your-openai-key'

kubectl create secret generic redis-secret \
  --namespace=lightrag \
  --from-literal=password='your-secure-password'

# Deploy with Helm
helm install lightrag ./helm/lightrag \
  --namespace lightrag \
  --set global.storageClass=civo-volume \
  --set ingress.enabled=true \
  --set ingress.className=nginx
```

### 6. Configure DNS

```bash
# Get load balancer IP
EXTERNAL_IP=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "External IP: $EXTERNAL_IP"

# Configure Civo DNS or external provider
```

### 7. Configure Civo DNS (Optional)

```bash
# Create DNS domain
civo dns domain-create lightrag.yourdomain.com

# Add A record
civo dns domain-record-create lightrag.yourdomain.com \
  --name @ \
  --type A \
  --value $EXTERNAL_IP \
  --ttl 600

# Add wildcard record
civo dns domain-record-create lightrag.yourdomain.com \
  --name "*" \
  --type A \
  --value $EXTERNAL_IP \
  --ttl 600
```

### Cost Estimation (Civo)

**Monthly costs (estimated):**
- Control plane: Free
- 3x g4s.kube.medium nodes: ~$60/month ($20 each)
- Storage (300GB): ~$15/month ($0.05/GB)
- Load Balancer: Free
- Bandwidth: Free (10TB)
- **Total**: ~$75/month

**Most cost-effective option!**

---

## Cost Comparison

| Provider | Monthly Cost | Control Plane | Nodes (3x) | Storage | LB | Notes |
|----------|-------------|---------------|------------|---------|----|----|
| **Civo** | ~$75 | Free | $60 | $15 | Free | Most affordable, fast provisioning |
| **DigitalOcean** | ~$186 | Free | $144 | $30 | $12 | Great value, simple pricing |
| **Azure** | ~$385 | Free | $350 | $15 | $20 | Enterprise features, global reach |
| **AWS** | ~$437 | $72 | $300 | $25 | $20 | Most flexible, largest ecosystem |
| **Google Cloud** | ~$523 | $73* | $360 | $52 | $18 | Best for AI/ML workloads |

*GKE Standard mode is free, Autopilot is $73/month

**Recommendations:**
- **Development/Testing**: Civo or DigitalOcean
- **Production (Small)**: DigitalOcean
- **Production (Large)**: AWS or Azure
- **AI/ML Focus**: Google Cloud
- **Budget-conscious**: Civo
- **Enterprise**: Azure or AWS

---

## Best Practices

### 1. Security

```bash
# Use secrets management
# AWS: Secrets Manager
# Azure: Key Vault
# GCP: Secret Manager

# Enable network policies
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: lightrag-network-policy
  namespace: lightrag
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/part-of: lightrag-stack
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: lightrag
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: lightrag
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
```

### 2. Monitoring

```bash
# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Default: admin / prom-operator
```

### 3. Backups

```bash
# Install Velero for backups
# AWS
velero install \
  --provider aws \
  --bucket lightrag-backups \
  --secret-file ./credentials-velero \
  --backup-location-config region=us-east-1

# Create backup schedule
velero schedule create lightrag-daily \
  --schedule="0 2 * * *" \
  --include-namespaces lightrag
```

### 4. Auto-scaling

```bash
# Install cluster autoscaler (provider-specific)
# or use Kubernetes Metrics Server + HPA

# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Create HPA
kubectl autoscale deployment lightrag \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  --namespace=lightrag
```

### 5. Cost Optimization

- Use spot/preemptible instances for non-critical workloads
- Enable cluster autoscaling
- Use appropriate storage classes (don't over-provision)
- Monitor and right-size resources
- Use reserved instances for production (AWS/Azure)
- Enable pod disruption budgets

### 6. High Availability

```bash
# Spread pods across zones
kubectl label nodes <node-name> topology.kubernetes.io/zone=us-east-1a

# Add pod anti-affinity to deployments
# Edit deployments to include:
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - lightrag
              topologyKey: topology.kubernetes.io/zone
```

---

## Troubleshooting

### Common Issues

**1. Pods stuck in Pending**
```bash
kubectl describe pod <pod-name> -n lightrag
# Check for resource constraints or PVC binding issues
```

**2. Load Balancer not getting external IP**
```bash
kubectl describe svc ingress-nginx-controller -n ingress-nginx
# Check cloud provider limits and quotas
```

**3. Storage provisioning fails**
```bash
kubectl get events -n lightrag --sort-by='.lastTimestamp'
# Verify storage class exists and provider CSI driver is installed
```

**4. DNS resolution issues**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup redis.lightrag.svc.cluster.local
```

### Getting Help

- Provider-specific support channels
- Kubernetes Slack: https://slack.k8s.io/
- LightRAG GitHub Issues
- Cloud provider documentation

---

## Next Steps

1. Choose your cloud provider
2. Follow the deployment guide
3. Configure monitoring and backups
4. Set up CI/CD pipeline
5. Configure domain and SSL certificates
6. Run validation tests
7. Go to production!

For more information, see:
- [Main K8s README](README.md)
- [Testing Guide](TESTING.md)
- [Helm Chart README](../helm/lightrag/README.md)

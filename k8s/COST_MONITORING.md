# Cost Monitoring with Kubecost

This guide explains how to set up and use Kubecost for monitoring the costs of your LightRAG Kubernetes deployment.

## Table of Contents

- [What is Kubecost?](#what-is-kubecost)
- [Why Use Kubecost?](#why-use-kubecost)
- [Installation](#installation)
- [Configuration](#configuration)
- [Cloud Provider Integration](#cloud-provider-integration)
- [Monitoring LightRAG Costs](#monitoring-lightrag-costs)
- [Cost Optimization](#cost-optimization)
- [Alerts and Reports](#alerts-and-reports)
- [Troubleshooting](#troubleshooting)

## What is Kubecost?

Kubecost is a cost monitoring and management tool for Kubernetes that provides:

- **Real-time cost visibility** by namespace, pod, deployment, service
- **Resource allocation tracking** (CPU, memory, storage, network)
- **Cost optimization recommendations** (idle resources, right-sizing)
- **Cloud provider billing integration** (AWS, Azure, GCP, DigitalOcean)
- **Budget alerts and reports**
- **Multi-cluster support** (Enterprise)

**Free Tier**: Full cost monitoring with 15-day retention
**Enterprise**: Extended retention, multi-cluster, SSO, advanced features

## Why Use Kubecost?

For LightRAG deployments, Kubecost helps you:

✅ Track costs by component (Redis, Memgraph, Qdrant, LightRAG, LobeChat)
✅ Identify idle or over-provisioned resources
✅ Compare costs across environments (dev vs prod)
✅ Get right-sizing recommendations
✅ Monitor cost trends over time
✅ Set budget alerts to prevent overspending
✅ Generate chargeback reports for cost allocation

## Installation

### Option 1: Helm (Recommended)

```bash
# Add Kubecost Helm repository
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update

# Install Kubecost with default values
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace \
  --set prometheus.server.global.external_labels.cluster_id=lightrag-cluster

# Or install with custom values (recommended)
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace \
  --values k8s/kubecost-values.yaml
```

### Option 2: Using Provided Manifest

```bash
# Review the manifest first
cat k8s/11-kubecost.yaml

# Note: This is informational only
# The actual deployment should use Helm as shown in the file
```

### Verify Installation

```bash
# Check deployment status
kubectl get pods -n kubecost

# Check services
kubectl get svc -n kubecost

# Wait for Kubecost to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=cost-analyzer \
  -n kubecost \
  --timeout=300s
```

## Configuration

### Access Kubecost UI

**Via Port Forward** (simplest):
```bash
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090

# Open in browser
open http://localhost:9090
```

**Via Ingress** (for production):
```bash
# Already configured in kubecost-values.yaml
# Add to /etc/hosts:
echo "<INGRESS_IP> kubecost.dev.localhost" | sudo tee -a /etc/hosts

# Access at:
open http://kubecost.dev.localhost
```

### Initial Setup

1. **Open Kubecost UI** (http://localhost:9090)
2. **Set Currency** (default: USD)
3. **Configure Cluster** (cluster_id: lightrag-cluster)
4. **Add Cloud Integration** (optional, see below)

### Basic Configuration

Edit the Helm values for custom configuration:

```bash
# Create custom values file
cat > my-kubecost-values.yaml <<EOF
kubecostProductConfigs:
  currencyCode: "EUR"  # Change currency

prometheus:
  server:
    retention: "30d"  # Increase retention

ingress:
  enabled: true
  hosts:
    - host: kubecost.mycompany.com
EOF

# Upgrade with new values
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  -f my-kubecost-values.yaml
```

## Cloud Provider Integration

Integrating with your cloud provider gives you:
- Accurate cloud billing data
- Reserved instance / savings plan tracking
- Network egress costs
- Storage costs from cloud provider billing

### AWS Integration

```bash
# 1. Set up Cost and Usage Report (CUR) in AWS
#    https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations

# 2. Update Helm values
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set kubecostProductConfigs.athenaBucketName="s3://my-kubecost-bucket" \
  --set kubecostProductConfigs.athenaRegion="us-east-1" \
  --set kubecostProductConfigs.athenaDatabase="athenacurcfn_my_report" \
  --set kubecostProductConfigs.athenaTable="my_report"
```

### Azure Integration

```bash
# 1. Set up Azure billing export
#    https://docs.kubecost.com/install-and-configure/install/cloud-integration/azure-out-of-cluster

# 2. Update Helm values
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set kubecostProductConfigs.azureSubscriptionID="<subscription-id>" \
  --set kubecostProductConfigs.azureTenantID="<tenant-id>" \
  --set kubecostProductConfigs.azureClientID="<client-id>" \
  --set kubecostProductConfigs.azureClientPassword="<password>"
```

### Google Cloud Integration

```bash
# 1. Enable BigQuery billing export
#    https://docs.kubecost.com/install-and-configure/install/cloud-integration/gcp-out-of-cluster

# 2. Update Helm values
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set kubecostProductConfigs.gcpBillingDataDataset="billing_dataset" \
  --set kubecost ProductConfigs.gcpBillingDataTable="gcp_billing_export" \
  --set kubecostProductConfigs.projectID="my-project-id"
```

### DigitalOcean / Civo

For providers without native billing export:

```bash
# Use manual pricing configuration
# Update kubecost-values.yaml with your actual costs

kubecostProductConfigs:
  defaultModelPricing: |-
    {
      "CPU": "0.031611",
      "RAM": "0.004237",
      "storage": "0.00005"
    }
```

Get your actual costs from:
- **DigitalOcean**: Droplet hourly cost / vCPUs
- **Civo**: Node hourly cost / vCPUs

## Monitoring LightRAG Costs

### View Namespace Costs

1. Open Kubecost UI
2. Go to **Allocations** → **Namespace**
3. Select **lightrag** namespace
4. View cost breakdown by:
   - Pod
   - Deployment
   - Service
   - Label

### View by Component

Filter by deployment to see individual component costs:

```bash
# View costs in Kubecost UI:
# Allocations → Filter → Deployment → Select:
# - redis
# - memgraph
# - qdrant
# - lightrag
# - lobechat
```

### Expected Cost Breakdown (Example)

For a typical LightRAG deployment:

| Component | % of Total | Est. Monthly (AWS) |
|-----------|------------|-------------------|
| Memgraph | 35-40% | $140-170 |
| Qdrant | 25-30% | $100-130 |
| LightRAG | 20-25% | $80-110 |
| Redis | 10-12% | $40-50 |
| LobeChat | 5-8% | $20-35 |
| Ingress/LB | Variable | $20-30 |

**Total**: ~$400-525/month (varies by cloud and usage)

### API Access

Query costs programmatically:

```bash
# Port forward Kubecost
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090

# Query namespace costs (last 7 days)
curl -G http://localhost:9090/model/allocation \
  --data-urlencode 'window=7d' \
  --data-urlencode 'aggregate=namespace' | jq

# Query pod costs in lightrag namespace
curl -G http://localhost:9090/model/allocation \
  --data-urlencode 'window=7d' \
  --data-urlencode 'aggregate=pod' \
  --data-urlencode 'filterNamespaces=lightrag' | jq
```

## Cost Optimization

### 1. Identify Idle Resources

**In Kubecost UI:**
1. Go to **Savings** → **Right-sizing**
2. View recommendations for:
   - Over-provisioned pods
   - Idle resources
   - Cluster optimization

**Expected Savings**: 20-30% by right-sizing

### 2. Adjust Resource Limits

Based on Kubecost recommendations:

```bash
# Example: Right-size LightRAG deployment
kubectl set resources deployment lightrag \
  -n lightrag \
  --limits=cpu=2000m,memory=4Gi \
  --requests=cpu=1000m,memory=2Gi

# Or update the manifest
kubectl edit deployment lightrag -n lightrag
```

### 3. Use Spot Instances (Cloud)

**AWS**:
```bash
# Add spot instance node group to EKS
eksctl create nodegroup \
  --cluster lightrag-eks \
  --name spot-workers \
  --node-type t3.xlarge \
  --nodes-min 1 \
  --nodes-max 3 \
  --spot
```

**Azure**:
```bash
# Add spot node pool to AKS
az aks nodepool add \
  --cluster-name lightrag-aks \
  --name spotnodes \
  --priority Spot \
  --eviction-policy Delete \
  --node-count 2
```

**Savings**: 60-90% on compute costs

### 4. Enable Cluster Autoscaling

Automatically scale down during low usage:

```bash
# Already configured in cloud deployment guides
# Verify autoscaling is enabled:
kubectl get deployment cluster-autoscaler -n kube-system
```

### 5. Optimize Storage

**In Kubecost UI:**
1. Go to **Assets** → **Disks**
2. Identify underutilized PVCs
3. Resize or delete unused volumes

**Example**:
```bash
# Check PVC usage
kubectl get pvc -n lightrag

# Resize PVC (if supported by storage class)
kubectl patch pvc qdrant-snapshots -n lightrag \
  -p '{"spec":{"resources":{"requests":{"storage":"5Gi"}}}}'
```

## Alerts and Reports

### Set Budget Alerts

1. Open Kubecost UI
2. Go to **Alerts** → **Create Alert**
3. Configure alert:
   - **Type**: Budget
   - **Scope**: Namespace = lightrag
   - **Budget**: $500/month
   - **Threshold**: 80%
   - **Notification**: Email/Slack

### Weekly Cost Reports

```bash
# Enable weekly reports in Helm values
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set reporting.reports.enabled=true \
  --set reporting.email.enabled=true \
  --set reporting.email.address="team@company.com"
```

### Slack Integration

```bash
# Configure Slack webhook
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set reporting.slackWebhookUrl="https://hooks.slack.com/services/xxx"
```

## Troubleshooting

### Kubecost Not Showing Data

**Check Prometheus**:
```bash
# Verify Prometheus is running
kubectl get pods -n kubecost | grep prometheus

# Check Prometheus targets
kubectl port-forward -n kubecost svc/kubecost-prometheus-server 9091:80
open http://localhost:9091/targets
```

**Restart Kubecost**:
```bash
kubectl rollout restart deployment -n kubecost
```

### Inaccurate Costs

**Verify Pricing**:
```bash
# Check current pricing configuration
kubectl exec -n kubecost \
  $(kubectl get pods -n kubecost -l app=cost-analyzer -o name | head -1) \
  -- cat /var/configs/pricing.json
```

**Update Pricing**:
```bash
# Use custom pricing in Helm values
# See kubecost-values.yaml
```

### High Memory Usage

Kubecost can use significant memory with large clusters:

```bash
# Increase Prometheus retention
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set prometheus.server.retention="7d"  # Reduce from 15d

# Increase resource limits
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set kubecost.resources.limits.memory="1Gi"
```

### Data Gaps

**Check Scrape Interval**:
```bash
kubectl get configmap -n kubecost kubecost-prometheus-server -o yaml | grep scrape_interval
```

**Increase Retention** (if data is being deleted too soon):
```bash
helm upgrade kubecost kubecost/cost-analyzer \
  -n kubecost \
  --reuse-values \
  --set prometheus.server.retention="30d"
```

## Advanced Features (Enterprise)

For production deployments, consider Kubecost Enterprise:

- **Multi-cluster visibility**: Monitor costs across dev/staging/prod
- **SAML/OIDC SSO**: Enterprise authentication
- **Advanced RBAC**: Team-based access control
- **Extended retention**: Up to 1 year of cost data
- **Custom reports**: Scheduled reports and dashboards
- **API rate limits**: Higher API limits for automation

**Pricing**: Contact Kubecost sales (typically $20-50/node/month)

## Cost Monitoring Best Practices

1. **Set Budgets**: Define monthly budgets per environment
2. **Review Weekly**: Check cost trends every week
3. **Right-size Regularly**: Apply recommendations monthly
4. **Use Spot Instances**: For non-critical workloads
5. **Enable Autoscaling**: Scale down during off-hours
6. **Monitor Trends**: Watch for cost anomalies
7. **Tag Resources**: Use labels for better cost allocation
8. **Delete Unused**: Remove idle resources promptly

## Resources

- **Official Docs**: https://docs.kubecost.com/
- **GitHub**: https://github.com/kubecost/cost-analyzer-helm-chart
- **Community**: https://kubecost.com/community
- **API Docs**: https://docs.kubecost.com/apis
- **Blog**: https://blog.kubecost.com/

## Example Queries

### Get Total Cluster Cost

```bash
curl -G http://localhost:9090/model/allocation \
  --data-urlencode 'window=month' \
  --data-urlencode 'aggregate=cluster' | jq '.data[0].totalCost'
```

### Compare Namespaces

```bash
curl -G http://localhost:9090/model/allocation \
  --data-urlencode 'window=7d' \
  --data-urlencode 'aggregate=namespace' | jq -r '.data[] | "\(.name): $\(.totalCost)"'
```

### Get Efficiency Score

```bash
curl http://localhost:9090/model/clusterInfo | jq '.data.efficiency'
```

## Integration with Cloud Deployment

For each cloud provider, see:
- [AWS Cost Integration](CLOUD_DEPLOYMENT.md#aws-eks) - CUR setup
- [Azure Cost Integration](CLOUD_DEPLOYMENT.md#azure-aks) - Billing export
- [GCP Cost Integration](CLOUD_DEPLOYMENT.md#google-cloud-gke) - BigQuery
- [DigitalOcean](CLOUD_DEPLOYMENT.md#digitalocean-doks) - Manual pricing
- [Civo](CLOUD_DEPLOYMENT.md#civo) - Manual pricing

---

**Next Steps**: After installing Kubecost, monitor your costs for a week to understand your baseline, then start applying optimization recommendations.

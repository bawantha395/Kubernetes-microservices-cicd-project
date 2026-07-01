# Runbook: Fresh Start to Live Cluster

This guide is for any new team member to start from zero and bring the platform online.

Scope covered:
1. GitHub Actions fresh pipeline run
2. EKS access and bootstrap
3. Argo CD setup and app sync
4. Route53 and CloudFront flow
5. External Secrets setup
6. Prometheus and Grafana setup
7. Health checks and troubleshooting

## 1. Prerequisites

Install and verify:

```bash
aws --version
kubectl version --client
helm version
terraform version
```

Required access:
1. AWS account permissions for EKS, IAM, VPC, RDS, ECR, Route53, CloudFront, ACM, Secrets Manager.
2. GitHub repository admin or maintainer access.
3. Local AWS CLI configured to same account and region used by pipeline.

Set AWS region used by this project:

```bash
export AWS_REGION=us-east-1
```

## 2. GitHub Repository Secrets

In repository settings, configure these secrets before running pipeline:
1. AWS_ACCESS_KEY_ID
2. AWS_SECRET_ACCESS_KEY
3. DB_USERNAME_PROD
4. DB_PASSWORD_PROD
5. DB_USERNAME_DEV
6. DB_PASSWORD_DEV

Pipeline file:
- .github/workflows/new-cicd.yml

## 3. Trigger Fresh Deployment Pipeline

Deployment is triggered by:
1. Push to `prod` branch, or
2. Manual workflow dispatch with action `deploy` and environment `prod`.

After successful run, Terraform provisions core AWS resources and updates deployment manifests.

## 4. Connect to EKS Cluster

List clusters and connect:

```bash
aws eks list-clusters --region us-east-1
```

For prod, expected cluster name is typically:

```bash
prod-prod-issue-app-cluster
```

Update kubeconfig:

```bash
aws eks update-kubeconfig --region us-east-1 --name prod-prod-issue-app-cluster
kubectl get nodes
```

## 5. Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
```

Access UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Get admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo
```

Open:
- https://localhost:8080
- Username: admin

## 6. Install AWS Load Balancer Controller (required for Ingress class `alb`)

This project ingress uses ALB, so this controller is mandatory.

Set cluster and account variables:

```bash
export CLUSTER_NAME=prod-prod-issue-app-cluster
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

Associate OIDC provider if not already associated:

```bash
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster $CLUSTER_NAME --approve
```

Create IAM policy for controller:

```bash
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.9.0/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
```

Create service account and role binding:

```bash
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

Install controller with Helm:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=$(aws eks describe-cluster --region us-east-1 --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text)
```

Verify:

```bash
kubectl -n kube-system get deploy aws-load-balancer-controller
```

## 7. Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n issue-app \
  --create-namespace \
  --set webhook.port=9443
```

Verify:

```bash
kubectl -n issue-app get pods | grep external-secrets
```

## 8. Register Argo CD Applications

Main app:

```bash
kubectl apply -f kubernetes/argocd/application-prod.yaml
```

Monitoring stack app:

```bash
kubectl apply -f kubernetes/argocd/application-monitoring-stack.yaml
kubectl apply -f kubernetes/argocd/application-monitoring-addons.yaml
```

Check sync state:

```bash
kubectl get applications -n argocd
kubectl describe application issue-app-prod -n argocd
kubectl describe application monitoring-stack -n argocd
kubectl describe application monitoring-addons -n argocd
```

## 9. Route53 and CloudFront Notes

Terraform creates Route53 + ACM + CloudFront through module `dns_cdn`.

Important behavior in this repo:
1. CloudFront origin requires ALB DNS name.
2. ALB DNS name is currently hardcoded placeholder in `terraform/environments/prod/main.tf` (`alb_dns_name`).

Recommended sequence:
1. Deploy infra and apps first.
2. Wait until ingress creates real ALB.
3. Get ALB DNS and update `alb_dns_name` value in `terraform/environments/prod/main.tf`.
4. Rerun deploy pipeline to update CloudFront origin.

Get actual ALB DNS:

```bash
kubectl -n issue-app get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
```

## 10. Access Prometheus and Grafana

Grafana:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Open:
- http://localhost:3000
- Username: admin
- Password: admin123

Prometheus:

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Open:
- http://localhost:9090

Change Grafana admin password after first login.

## 11. Verify End-to-End Health

```bash
kubectl get ns
kubectl -n issue-app get pods,svc,ingress
kubectl -n monitoring get pods,svc
kubectl -n argocd get applications
```

Check secrets synced:

```bash
kubectl -n issue-app get externalsecret
kubectl -n issue-app get secret api-gateway-secrets auth-service-secrets issue-service-secrets
```

## 12. Day-2 Operations

Sync applications manually when needed:

```bash
argocd app sync issue-app-prod
argocd app sync monitoring-stack
argocd app sync monitoring-addons
```

Rollback to previous Git commit:
1. Revert manifest changes in Git.
2. Push to `prod`.
3. Argo CD auto-sync applies rollback.

## 13. Known Repo-Specific Caveats

1. GitHub Actions currently references `terraform output -raw ecr_repository_url` in workflow, while Terraform output file exposes `ecr_repository_urls` map. If pipeline fails at image URL extraction, update workflow output handling.
2. CloudFront origin uses a placeholder ALB DNS until you update it with real ingress ALB hostname.
3. ALB controller installation is required because ingress class is `alb`.

## 14. Quick Start Checklist

1. Set GitHub secrets.
2. Run deploy pipeline.
3. Connect kubeconfig to EKS.
4. Install Argo CD.
5. Install AWS Load Balancer Controller.
6. Install External Secrets Operator.
7. Apply Argo app manifests (prod + monitoring).
8. Confirm ingress ALB hostname and update CloudFront origin if needed.
9. Verify Grafana and Prometheus.

# Kubernetes Microservices CI/CD Architecture

This diagram summarizes the end-to-end architecture across GitHub Actions, Terraform, AWS, Argo CD, Kustomize, Helm, and Kubernetes microservices.

```mermaid
flowchart TB
  %% =========================
  %% Actors
  %% =========================
  Dev[Developer]
  User[End User / Browser]

  %% =========================
  %% Git + CI/CD
  %% =========================
  subgraph GitHub[GitHub]
    Repo[Source Repository]
    GHA[GitHub Actions\nnew-cicd.yml]
    Repo --> GHA
  end

  Dev --> Repo

  %% =========================
  %% Terraform State Backend
  %% =========================
  subgraph TFState[Terraform State Backend]
    S3[S3 Bucket\nTerraform State]
    DDB[DynamoDB Table\nState Lock]
  end

  GHA --> S3
  GHA --> DDB

  %% =========================
  %% Terraform Provisioned AWS
  %% =========================
  subgraph AWS[AWS (Provisioned by Terraform)]
    subgraph Network[VPC Network]
      VPC[VPC]
      PUB[Public Subnets]
      PRIV[Private Subnets]
      IGW[Internet Gateway]
      NAT[NAT Gateway]
      VPC --> PUB
      VPC --> PRIV
      PUB --> IGW
      PRIV --> NAT
    end

    EKS[EKS Cluster]
    NG[Managed Node Group\nEC2 workers]
    RDS[(RDS MySQL)]
    ECR[ECR Repositories\napi/auth/issue/frontend]
    SM[Secrets Manager]
    R53[Route 53 Hosted Zone]
    ACM[ACM Certificate]
    CF[CloudFront Distribution]

    PRIV --> EKS
    EKS --> NG
    PRIV --> RDS
    R53 --> CF
    ACM --> CF
  end

  GHA --> AWS
  GHA --> ECR

  %% =========================
  %% GitOps + Argo CD
  %% =========================
  subgraph GitOps[GitOps Delivery]
    Kustomize[Kustomize Overlays\nkubernetes/environments/*]
    Argo[Argo CD Applications\napplication-dev/prod]
    Kustomize --> Argo
  end

  GHA --> Kustomize
  GHA --> Repo
  Repo --> Argo
  Argo --> EKS

  %% =========================
  %% Kubernetes Runtime
  %% =========================
  subgraph K8s[EKS Kubernetes Runtime (namespace: issue-app)]
    Ingress[Ingress (ALB class)\nHost: tcmslk.me\n/api -> api-gateway\n/ -> frontend]

    FE[frontend-service]
    APIGW[api-gateway]
    AUTH[auth-service]
    ISSUE[issue-service]

    ESO[External Secrets Operator\n(Installed via Helm)]
    SA[ServiceAccount + IRSA\nissue-app-sa]
    SS[SecretStore]
    K8SSecrets[Kubernetes Secrets]

    Ingress --> FE
    Ingress --> APIGW
    APIGW --> AUTH
    APIGW --> ISSUE

    SA --> SS
    ESO --> SS
    SS --> K8SSecrets
    K8SSecrets --> APIGW
    K8SSecrets --> AUTH
    K8SSecrets --> ISSUE
  end

  subgraph Observability[Monitoring Namespace (monitoring)]
    PROM[Prometheus]
    GRAF[Grafana]
    ALERT[Alertmanager]
  end

  %% =========================
  %% External traffic path
  %% =========================
  User --> R53
  CF --> Ingress

  %% =========================
  %% Data/Artifact dependencies
  %% =========================
  ECR --> FE
  ECR --> APIGW
  ECR --> AUTH
  ECR --> ISSUE

  AUTH --> RDS
  ISSUE --> RDS

  SM --> ESO

  APIGW --> PROM
  AUTH --> PROM
  ISSUE --> PROM
  PROM --> ALERT
  PROM --> GRAF
```

## Deployment Flow (High Level)

1. Developer pushes changes to GitHub.
2. GitHub Actions runs Terraform plan/apply and provisions or updates AWS resources.
3. GitHub Actions builds container images and pushes them to ECR.
4. GitHub Actions updates Kustomize overlays (image tags / runtime config) and commits changes.
5. Argo CD detects Git changes and syncs manifests to EKS.
6. In-cluster External Secrets Operator (installed by Helm) fetches secrets from AWS Secrets Manager via IRSA.
7. User traffic flows through Route 53 and CloudFront to ALB ingress, then to frontend and API services.

## Monitoring Components Added

1. Argo CD app for kube-prometheus-stack (Helm chart): kubernetes/argocd/application-monitoring-stack.yaml
2. Argo CD app for monitoring add-ons (ServiceMonitors + PrometheusRule): kubernetes/argocd/application-monitoring-addons.yaml
3. ServiceMonitors and alert rules: kubernetes/monitoring
4. Metrics-enabled Spring Boot services with Actuator + Prometheus registry dependencies.

## Apply Monitoring in Cluster

```bash
kubectl apply -f kubernetes/argocd/application-monitoring-stack.yaml
kubectl apply -f kubernetes/argocd/application-monitoring-addons.yaml
```

## Access Grafana

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Then open http://localhost:3000

Default credentials in the current setup:
- username: admin
- password: admin123

Important: change the Grafana admin password before production use.

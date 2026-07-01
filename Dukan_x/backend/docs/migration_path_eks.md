# Migration Path: ECS to EKS

## Overview
This document outlines the strategy for migrating the DukanX backend from **Amazon ECS (Elastic Container Service)** to **Amazon EKS (Elastic Kubernetes Service)** in the future.

## Why Migrate?
-   **Ecosystem**: Access to the rich Kubernetes ecosystem (Helm charts, Operators, sidecars).
-   **Portability**: Run the same workloads on AWS, Azure, GCP, or On-Premise.
-   **Granular Control**: Advanced networking, service mesh (Istio), and custom scheduling.

## 1. No Code Changes Required
Since the application is already **Containerized** (Docker), the application code does not change.
-   **Artifact**: The same Docker image in ECR is used.
-   **Env Vars**: Configuration remains environment-variable driven.

## 2. Concept Mapping

| Feature | ECS Fargate | EKS (Kubernetes) |
| :--- | :--- | :--- |
| **Unit of Work** | Task Definition | Pod Spec / Deployment |
| **Service Discovery** | Service Discovery (Cloud Map) | K8s Service (ClusterIP) |
| **Load Balancing** | ALB -> Target Group | Ingress Controller -> Service |
| **Config** | Task Environment Vars | ConfigMaps & Secrets |
| **Scaling** | App Auto Scaling | Horizontal Pod Autoscaler (HPA) |
| **Network** | VPC / Security Groups | VPC CNI / Network Policies |

## 3. Migration Steps

### Step A: Infrastructure Setup
1.  **Provision EKS Cluster**: Use `eksctl` or Terraform.
2.  **Node Groups**: Utilize **Fargate Profiles** on EKS to maintain the "Serverless" operational model (No EC2 management).

### Step B: Manifest Creation
Convert ECS Task Definitions to Kubernetes Manifests.

**Deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dukanx-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dukanx
  template:
    metadata:
      labels:
        app: dukanx
    spec:
      containers:
      - name: backend
        image: <AWS_ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/dukanx-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: dukanx-secrets
              key: database_url
```

**Service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: dukanx-service
spec:
  selector:
    app: dukanx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
  type: LoadBalancer # Or use Ingress
```

### Step C: Cutover
1.  Deploy manifests to EKS.
2.  Verify connectivity to RDS (Security Group adjustment may be needed).
3.  Update DNS (Route53) to point to EKS Load Balancer.

## 4. Cost Considerations for EKS
-   **Control Plane**: EKS charges ~$73/month just for the cluster control plane. ECS has no control plane cost.
-   *Recommendation*: Only switch to EKS if you strictly need Kubernetes features or have a multi-cloud requirement. For a single AWS environment, ECS Fargate is more cost-effective.

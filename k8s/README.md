# Kubernetes Deployment

These manifests deploy the Task API onto the kubeadm cluster provisioned
in `../terraform/ec2.tf`. There is no local Kind cluster in this version
of the project - see `../docs/architecture-decisions.md` for why.

## Before you start

1. The EC2 instance must be running (`terraform apply` done, instance state = running).
2. SSH into the node - all commands below run **on the node**, since
   that's where `kubectl`, `aws` CLI, and the IAM role for ECR live:
   ```bash
   ssh -i ~/.ssh/devops-capstone-key ubuntu@<node-public-ip>
   ```
3. Verify the cluster is up:
   ```bash
   kubectl get nodes
   # should show one node, STATUS = Ready
   ```

## Task 7: Build and push the image (run from your own machine, not the node)

```bash
cd app
docker build -t task-api:v1 .
docker run --rm -p 3000:3000 task-api:v1   # quick local smoke test, then Ctrl+C

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-south-1
ECR_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/devops-capstone/task-api"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
docker tag task-api:v1 "${ECR_URL}:v1"
docker push "${ECR_URL}:v1"
```

## Task 8: Deploy with plain kubectl (run ON the node)

```bash
# First, get the ECR pull secret in place (valid ~12 hours)
bash refresh-ecr-secret.sh   # copy this script to the node first - see terraform/scripts/

# Edit deployment.yaml - replace ACCOUNT_ID and REGION with real values
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

kubectl get pods
kubectl get pods -o wide
kubectl describe pod <pod-name>   # confirm readiness/liveness probes are passing
```

Test it's reachable (from your own machine, using the node's public IP):
```bash
curl http://<node-public-ip>:30080/health
curl http://<node-public-ip>:30080/api/tasks
```

## Task 9: Switch to Helm (run ON the node)

Clean up the raw manifests first to avoid a port conflict, then install via Helm:
```bash
kubectl delete -f deployment.yaml -f service.yaml

cd ~/helm/task-api   # copy this folder to the node first
helm install task-api . \
  --set image.repository=${ECR_URL} \
  --set image.tag=v1

helm list
helm status task-api
kubectl get pods

# Demonstrate an upgrade (e.g. scaling replicas)
helm upgrade task-api . --set replicaCount=3 --set image.repository=${ECR_URL} --set image.tag=v1
helm history task-api
```

## Tearing down

```bash
helm uninstall task-api
```
And remember: `terraform destroy` (or at least stop the EC2 instance) when you're done for the session.
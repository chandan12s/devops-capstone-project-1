# Task 15 — Kubernetes Networking Issue: Issue Description & Resolution

## Issue summary

**What broke:** Pods in the `dev` namespace lost the ability to reach
any external service (and also lost internal DNS resolution).  
**Symptom:** `curl` from inside a pod to any external URL hangs or
times out; DNS lookups for external names fail with `NXDOMAIN` or
`connection timed out`.  
**Root cause:** An overly broad `NetworkPolicy` was applied that denied
all pod egress, including to `kube-dns` and the internet.

## Diagnostic steps — in order, with the real commands and outputs

This is the three-layer diagnosis the PDF asks for: Kubernetes
networking → security groups → routing. Work through them in this
order, innermost layer first.

### Layer 1: Kubernetes networking

**Confirm the pod is actually running:**
```bash
kubectl get pods -n dev -o wide
# Expected: pod STATUS=Running, READY=1/1
```
[paste your output here]

**Try to reach an external service from inside the pod:**
```bash
kubectl exec -n dev <pod-name> -- curl -s --max-time 5 https://httpbin.org/get
# Expected when broken: curl: (28) Connection timed out after 5000 ms
```
[paste your output here]

**Try DNS resolution from inside the pod:**
```bash
kubectl exec -n dev <pod-name> -- nslookup google.com
# Expected when broken: ;; connection timed out; no servers could be reached
```
[paste your output here]

**This isolates the problem to the pod's network, not the node.**  
If `curl` from the node itself works (`curl -s https://httpbin.org/get`)
but the same command from inside the pod times out, the issue is
between the pod and the outside world - either a NetworkPolicy or the
node's security group. Check NetworkPolicy first:

```bash
kubectl get networkpolicy -n dev
# OUTPUT WHEN BROKEN:
# NAME               POD-SELECTOR                    AGE
# deny-all-egress    app=task-api-dev-task-api       2m

kubectl describe networkpolicy deny-all-egress -n dev
# Look at the Egress section:
# Egress:  <none>   <-- empty = deny all egress
```
[paste your output here]

**Finding:** a `deny-all-egress` NetworkPolicy with an empty `egress:`
list was applied to the affected pods. This is the root cause.

### Layer 2: AWS security groups

Even with the NetworkPolicy identified, always check the security group
too — both layers can independently block traffic, and fixing only one
would leave the issue partially unresolved.

```bash
# Get the node's security group name from the Terraform output or EC2 console:
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=devops-capstone-k8s-node-sg" \
  --region ap-south-1 \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```
[paste your output here]

**Expected finding:** security group allows all outbound (`0.0.0.0/0`
on all ports) — this was intentionally set in `terraform/ec2.tf`. So
the security group is NOT the cause here; the NetworkPolicy is.

If the security group had been restricting outbound 443, the fix would
have been a `terraform apply` with an updated egress rule — not just
the NetworkPolicy fix below.

### Layer 3: Routing

```bash
# From the node (not the pod), confirm the default route is present
ip route show
# Should show: default via <gateway-ip> dev eth0

# Confirm the node itself can reach the internet
curl -s --max-time 5 https://httpbin.org/get | head -5
```
[paste your output here]

**Expected finding:** routing is fine at the node level. This confirms
the pod's egress block is purely at the NetworkPolicy layer.

## Root cause

A `NetworkPolicy` (`deny-all-egress`) was applied to the `dev`
namespace with an empty `egress:` list. In Kubernetes, a NetworkPolicy
that selects pods and specifies `policyTypes: [Egress]` with no
`egress:` rules means "deny all egress from selected pods" — the
exact opposite of "allow all," which is what an empty spec without any
NetworkPolicy means. This is a common point of confusion.

The policy also blocked port 53 to `kube-dns`, which broke internal
DNS resolution in addition to external connectivity — explaining why
both `nslookup google.com` and `curl https://external-service.com`
failed simultaneously.

## Fix applied

Replaced the `deny-all-egress` NetworkPolicy with a least-privilege
version that allows only what the app genuinely needs:

```bash
kubectl apply -f k8s/netpol-allow-egress.yaml
```

The new policy allows:
- Port 53 UDP+TCP → kube-dns (internal name resolution)
- Port 443 TCP → any destination (HTTPS for ECR, external APIs)

Everything else remains denied — the policy isn't removed entirely,
it's corrected.

## Validation after fix

```bash
# DNS now resolves from inside the pod
kubectl exec -n dev <pod-name> -- nslookup google.com
# Expected: shows a real IP address

# External HTTPS works
kubectl exec -n dev <pod-name> -- curl -s --max-time 5 https://httpbin.org/get
# Expected: returns JSON response

# App health check still works from outside
curl http://<node-ip>:30080/health
# Expected: {"status":"ok","timestamp":"..."}

# Confirm the updated NetworkPolicy is in place
kubectl describe networkpolicy deny-all-egress -n dev
# Egress section should now show ports 53 (UDP+TCP) and 443 (TCP)
```
[paste your output here]

## What to do differently next time

1. **Never apply a deny-all NetworkPolicy without simultaneously
   defining the allow rules** — apply them in the same `kubectl apply`
   command or the same manifest file, so there's no window where
   traffic is blocked.

2. **Test network policies in a non-production namespace first.** The
   `dev` namespace is the right place to catch this; catching it in
   `prod` would have been a real incident.

3. **`kubectl describe networkpolicy` should be in your first-response
   runbook** any time pods lose external connectivity. It's a 5-second
   check that rules in or out a whole class of issues immediately.

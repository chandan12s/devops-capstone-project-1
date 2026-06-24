#!/bin/bash
# Runs automatically on first boot (as root) via EC2 user-data.
# Full output is logged to /var/log/k8s-bootstrap.log for troubleshooting.
set -euxo pipefail
exec > >(tee -a /var/log/k8s-bootstrap.log) 2>&1

echo "=== Starting Kubernetes bootstrap: $(date) ==="

# --- 1. Disable swap (kubeadm hard requirement) ---
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# --- 2. Kernel modules + sysctl settings required for pod networking ---
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# --- 3. Install containerd as the container runtime ---
apt-get update
apt-get install -y containerd unzip
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- 4. Install kubeadm, kubelet, kubectl (pinned to v1.33, the current LTS) ---
apt-get install -y apt-transport-https ca-certificates curl gpg
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- 5. Install AWS CLI v2 (needed to authenticate to ECR from this node) ---
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# --- 6. Initialize the cluster (single control-plane node) ---
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-cert-extra-sans="${PUBLIC_IP}"

# --- 7. Configure kubectl for both root and the ubuntu user ---
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

export KUBECONFIG=/etc/kubernetes/admin.conf

# --- 8. Install the Flannel CNI plugin (pod-to-pod networking) ---
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# --- 9. Allow scheduling pods on this node ---
# kubeadm taints the control-plane node by default so it won't run app
# pods - fine for multi-node clusters, but we only have one node here.
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

# --- 10. Install metrics-server (needed for `kubectl top` and HPA later) ---
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
sleep 10
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true

# --- 11. Install Helm ---
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "=== Kubernetes bootstrap complete: $(date) ==="
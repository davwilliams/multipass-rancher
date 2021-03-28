#!/bin/bash

# -------------------------------------------------------------------------------------
# Script: multipass-rancher-install.sh
# Highly functional Rancher lab for Linux or macOS via Ubuntu Multipass
#
# Usage:
# ./multipass-rancher-install.sh -w <num_agents> -c <num_cpus> -m <mem_size> -d <disk_size>
#
# Example:
# ./multipass-rancher-install.sh -w 3 -c 2 -m 4096 -d 20
#
# ToDo: Error handling, support for advanced server and agent customizations
#
# Governed under the MIT license. 
# -------------------------------------------------------------------------------------

while getopts w:c:m:d: flag; do
  case "${flag}" in
    w) NUM_AGENTS=${OPTARG};;
    c) NUM_CPUS=${OPTARG};;
    m) MEM_SIZE=${OPTARG};;
    d) DISK_SIZE=${OPTARG};;
  esac
done

provision_k3s_agents () {
    COUNTER=1
    until [ $COUNTER -gt $NUM_AGENTS ]; do
      multipass launch focal --name k3s-agent-$COUNTER --cpus $NUM_CPUS --mem ${MEM_SIZE}M --disk ${DISK_SIZE}G
      let COUNTER+=1
    done
}

install_k3s_agents () {
    COUNTER=1
    until [ $COUNTER -gt $NUM_AGENTS ]; do
      echo
      multipass exec k3s-agent-$COUNTER \
        -- /bin/bash -c "curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_TOKEN} K3S_URL=${K3S_SERVER_URL} sh -"
      let COUNTER+=1
    done
}

# Provision nodes for K3s Rancher node (server)
echo "Lauching K3s lab nodes..."
multipass launch focal --name k3s-rancher --cpus 2 --mem 4096M --disk 20G

# K3s Installation
# Note: This script installs a dynamically-defined cluster with the following attributes:
#       - Single-server (non-HA)
#       - sqlite DB backend (via Kine, also non-HA)
#       - Flannel CNI with default configuration (VXLAN backend)

# Deploy K3s on k3s-rancher node (server)
echo && echo "Deploying latest release of K3s on the Rancher node..."
multipass exec k3s-rancher -- /bin/bash -c "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -"


# Prep for deployment on agents
echo && echo "Retrieving information preparatory to deploying K3s to the agent nodes..."
K3S_SERVER_IP=$(multipass info k3s-rancher | grep "IPv4" | awk -F' ' '{print $2}')
K3S_SERVER_URL="https://${K3S_SERVER_IP}:6443"
echo "  k3s-rancher IP is: " $K3S_SERVER_IP
K3S_TOKEN="$(multipass exec k3s-rancher -- /bin/bash -c "sudo cat /var/lib/rancher/k3s/server/node-token")"
echo "  Join token for this K3s cluster is: " $K3S_TOKEN

# Deploy K3s on agent nodes
echo && echo "Provisioning K3s agent(s)..."
provision_k3s_agents
echo && echo "Deploying K3s on the agent nodes..."
install_k3s_agents

# Check cluster status
echo && echo "Verifying cluster status..."
sleep 20  # Give enough time for agent nodes to become ready
multipass exec k3s-rancher -- /bin/bash -c "kubectl get nodes -o wide"
multipass exec k3s-rancher -- /bin/bash -c "cp /etc/rancher/k3s/k3s.yaml ~/.kube/config"
multipass exec k3s-rancher -- /bin/bash -c "chmod go-r ~/.kube/config"

# K3s Installation
# Note: Rancher Management Server is installed via Helm with the following attributes:
#       - Cert-Manager prerequisite for managing ingress cert
#       - Current supports Rancher-generated cert; if using your own or Let's Encrypt, see Rancher docs
#       - Modern browsers will not support the Rancher-generated cert, you will need to import and trust it

# Installing Helm, adding repos
echo & echo "Installing Helm on K3s server..."
multipass exec k3s-rancher -- /bin/bash -c "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
multipass exec k3s-rancher -- /bin/bash -c "chmod 700 get_helm.sh"
multipass exec k3s-rancher -- /bin/bash -c "./get_helm.sh"
echo && echo "Adding Helm repos..."
multipass exec k3s-rancher -- /bin/bash -c "helm repo add jetstack https://charts.jetstack.io"
multipass exec k3s-rancher -- /bin/bash -c "helm repo add rancher-latest https://releases.rancher.com/server-charts/latest"
multipass exec k3s-rancher -- /bin/bash -c "helm repo update"

# Install Cert-Manager
echo && echo "Intalling Cert-Manager..."
multipass exec k3s-rancher -- /bin/bash -c "kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.crds.yaml"
multipass exec k3s-rancher -- /bin/bash -c "kubectl create namespace cert-manager"
multipass exec k3s-rancher -- /bin/bash -c "helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.2.0"
echo && echo "Verifying Cert-Manager installation"
multipass exec k3s-rancher -- /bin/bash -c "sleep 10 && kubectl get pods --namespace cert-manager"

# Install Rancher
multipass exec k3s-rancher -- /bin/bash -c "kubectl create namespace cattle-system"
multipass exec k3s-rancher -- /bin/bash -c "helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.${K3S_SERVER_IP}.xip.io"
multipass exec k3s-rancher -- /bin/bash -c "kubectl -n cattle-system rollout status deploy/rancher"
multipass exec k3s-rancher -- /bin/bash -c "kubectl -n cattle-system get deploy rancher"
echo && echo "You can reach Rancher at https://rancher.${K3S_SERVER_IP}.xip.io"
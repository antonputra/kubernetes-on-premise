# Kubernetes On-Premise Guide (Ubuntu).

## Components

- Kubernetes: `1.34`
- Containerd: `2.1.4`
- Runc: `1.3.0`
- CNI plugins: `1.7.1`
- Calico: `3.30.3`
- MetalLB: `0.15.2`

## Steps

### Preparing the hosts (Update DNS)

- control-plane-00
- node-00
- node-01
- node-02
- node-03
- ...

```sh
export DESIRED_HOST_NAME="control-plane-00"
export CURRENT_HOST_NAME="ubuntu"

sudo apt update && sudo apt -y upgrade
sudo sed -i "s/$CURRENT_HOST_NAME/$DESIRED_HOST_NAME/" /etc/hostname
sudo sed -i "s/$CURRENT_HOST_NAME/$DESIRED_HOST_NAME/" /etc/hosts
sudo reboot
```

### Disable Swap Memory (Kubelet Requirement)

```sh
sudo swapoff -a
sudo sed -i 's/\/swap.img/#\/swap.img/' /etc/fstab
free -h
```

### Installing a container runtime (containerd)

```sh
export CONTAINERD_VER="2.1.4"

curl -L https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VER/containerd-$CONTAINERD_VER-linux-amd64.tar.gz -o containerd-$CONTAINERD_VER-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-$CONTAINERD_VER-linux-amd64.tar.gz
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /lib/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
```

#### Installing runc

```sh
export RUNC_VER="1.3.0"


curl -L https://github.com/opencontainers/runc/releases/download/v$RUNC_VER/runc.amd64 -o runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
```

#### Installing CNI plugins

```sh
export PLUGINS_VER="1.7.1"

curl -L https://github.com/containernetworking/plugins/releases/download/v$PLUGINS_VER/cni-plugins-linux-amd64-v$PLUGINS_VER.tgz -o cni-plugins-linux-amd64-v$PLUGINS_VER.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v$PLUGINS_VER.tgz
sudo mkdir /etc/containerd/

sudo sh -c 'containerd config default > /etc/containerd/config.toml'
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd

stat -fc %T /sys/fs/cgroup/
```

### Install and configure prerequisites

```sh
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

lsmod | grep br_netfilter
lsmod | grep overlay

sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

### Install kubeadm (on all the hosts)

```sh
export K8S_VER="1.34"

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VER/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VER/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Initializing your control-plane node

```sh
sudo kubeadm init --pod-network-cidr=10.0.0.0/16
```

### Copy Kubernetes Config

```sh
sudo cat /etc/kubernetes/admin.conf

vim ~/.kube/config
```

### Installing a Pod network add-on

```sh
export CALICO_VER="3.30.3"

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VER/manifests/tigera-operator.yaml

## It takes a while for CRDs to become available; if it fails, retry multiple times.
kubectl apply -f https://raw.githubusercontent.com/antonputra/kubernetes-on-premise/main/calico.yaml
```

### Join Master (Example)

```sh
sudo kubeadm join 192.168.50.135:6443 --token 91frs1.soriol1w90rjqg5u \
	--discovery-token-ca-cert-hash sha256:984c077be96832548ca5185268fbc37804b6ce19799c54c53ba1973ead6b611c
```

### Add Roles

```sh
kubectl label node node-00 node-role.kubernetes.io/worker=
kubectl label node node-01 node-role.kubernetes.io/worker=
kubectl label node node-02 node-role.kubernetes.io/worker=
kubectl label node node-03 node-role.kubernetes.io/worker=
```

### Add Labels

```sh
kubectl label node node-00 node=node-00
kubectl label node node-01 node=node-01
kubectl label node node-02 node=node-02
kubectl label node node-03 node=node-03
```

### Install MetalLB

```sh
kubectl edit configmap -n kube-system kube-proxy

apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true

export METALLB_VER="0.15.2"

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$METALLB_VER/config/manifests/metallb-native.yaml

## It takes a while for CRDs to become available; if it fails, retry multiple times.
kubectl apply -f https://raw.githubusercontent.com/antonputra/kubernetes-on-premise/main/metallb.yaml
```

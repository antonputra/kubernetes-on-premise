#!/bin/bash

# Update DNS

export HOST_NAME="control-plane-00"

sudo apt update && sudo apt -y upgrade
sudo sed -i "s/ubuntu/$HOST_NAME/" /etc/hostname
sudo sed -i "s/ubuntu/$HOST_NAME/" /etc/hosts
sudo reboot

export CONTAINERD_VER="1.7.22"
export RUNC_VER="1.1.14"
export PLUGINS_VER="1.5.1"

# Disable Swap Memory

sudo swapoff -a
sudo sed -i 's/\/swap.img/#\/swap.img/' /etc/fstab
free -h

# Installing a container runtime (containerd)

curl -L https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VER/containerd-$CONTAINERD_VER-linux-amd64.tar.gz -o containerd-$CONTAINERD_VER-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-$CONTAINERD_VER-linux-amd64.tar.gz
sudo curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /lib/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Installing runc

curl -L https://github.com/opencontainers/runc/releases/download/v$RUNC_VER/runc.amd64 -o runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

#Installing CNI plugins

curl -L https://github.com/containernetworking/plugins/releases/download/v$PLUGINS_VER/cni-plugins-linux-amd64-v$PLUGINS_VER.tgz -o cni-plugins-linux-amd64-v$PLUGINS_VER.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v$PLUGINS_VER.tgz
sudo mkdir /etc/containerd/

sudo sh -c 'containerd config default > /etc/containerd/config.toml'
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd

stat -fc %T /sys/fs/cgroup/

# Install and configure prerequisites

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

# Install kubeadm (on all the hosts)

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

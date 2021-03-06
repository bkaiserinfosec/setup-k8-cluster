#!/bin/bash

# Step 1 - Pre-Configure the System
dnf -y upgrade
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
modprobe br_netfilter
firewall-cmd --add-masquerade --permanent
firewall-cmd --reload
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
swapoff -a
# Step 2 - Install Docker CE
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
dnf install docker-ce --nobest -y
systemctl start docker
systemctl enable docker
# Step 3 - Install Kubernetes
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
dnf upgrade -y
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet
systemctl start kubelet
# Step 4 - Configure Kubernetes
kubeadm config images pull
firewall-cmd --zone=public --permanent --add-port={6443,2379,2380,10250,10251,10252}/tcp
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=192.168.1.232/32 accept'
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=192.168.1.235/32 accept'
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=192.168.1.236/32 accept'
firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=172.17.0.0/16 accept'
firewall-cmd --reload
kubeadm init --pod-network-cidr 192.168.0.0/16
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
# Step 5 - Initialize Pod Networking
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
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
dnf -y remove podman runc
curl https://download.docker.com/linux/centos/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
sed -i -e "s/enabled=1/enabled=0/g" /etc/yum.repos.d/docker-ce.repo
dnf --enablerepo=docker-ce-stable -y install docker-ce 
systemctl enable --now docker
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
dnf install -y wget kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet
swapoff -a
systemctl daemon-reload
systemctl restart kubelet
kubeadm init --apiserver-advertise-address=192.168.72.131 --pod-network-cidr=10.5.0.0/16
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml
kubectl get pod --all-namespaces




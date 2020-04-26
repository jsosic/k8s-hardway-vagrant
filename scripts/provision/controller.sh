#!/bin/bash

[[ ! -e /etc/yum.repos.d/google-cloudsdk.repo ]] && cat > /etc/yum.repos.d/google-cloudsdk.repo <<EOF
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
priority=1
EOF

yum -y update
yum -y install epel-release
yum -y install nc telnet bind-utils net-tools vim mlocate


# install and configure etcd
export INTERNAL_IP=$(ip addr show eth1 | grep "inet\\b" | awk '{print $2}' | cut -d/ -f1)

yum -y install etcd kubernetes-master
[[ ! -e /etc/etcd/etcd.conf.rpmorig ]]; mv /etc/etcd/etcd.conf /etc/etcd/etcd.conf.rpmorig

cat > /etc/etcd/etcd.conf <<EOF
#[Member]
#ETCD_CORS=""
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
#ETCD_WAL_DIR=""
ETCD_LISTEN_PEER_URLS="https://${INTERNAL_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${INTERNAL_IP}:2379,https://127.0.0.1:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
ETCD_NAME="$(hostname -s)"
#ETCD_SNAPSHOT_COUNT="100000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
#ETCD_QUOTA_BACKEND_BYTES="0"
#ETCD_MAX_REQUEST_BYTES="1572864"
#ETCD_GRPC_KEEPALIVE_MIN_TIME="5s"
#ETCD_GRPC_KEEPALIVE_INTERVAL="2h0m0s"
#ETCD_GRPC_KEEPALIVE_TIMEOUT="20s"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${INTERNAL_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${INTERNAL_IP}:2379"
#ETCD_DISCOVERY=""
#ETCD_DISCOVERY_FALLBACK="proxy"
#ETCD_DISCOVERY_PROXY=""
#ETCD_DISCOVERY_SRV=""
ETCD_INITIAL_CLUSTER="controller01=https://10.240.0.101:2380,controller02=https://10.240.0.102:2380,controller03=https://10.240.0.103:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
#ETCD_STRICT_RECONFIG_CHECK="true"
#ETCD_ENABLE_V2="true"
#ETCD_ENABLE_V2="true"

#[Proxy]
#ETCD_PROXY="off"
#ETCD_PROXY_FAILURE_WAIT="5000"
#ETCD_PROXY_REFRESH_INTERVAL="30000"
#ETCD_PROXY_DIAL_TIMEOUT="1000"
#ETCD_PROXY_WRITE_TIMEOUT="5000"
#ETCD_PROXY_READ_TIMEOUT="0"

#[Security]
ETCD_CERT_FILE="/etc/etcd/kubernetes.pem"
ETCD_KEY_FILE="/etc/etcd/kubernetes-key.pem"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/ca.pem"
#ETCD_AUTO_TLS="false"
ETCD_PEER_CERT_FILE="/etc/etcd/kubernetes.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/kubernetes-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/ca.pem"
#ETCD_PEER_AUTO_TLS="false"

#[Logging]
#ETCD_DEBUG="false"
#ETCD_LOG_PACKAGE_LEVELS=""
#ETCD_LOG_OUTPUT="default"

#[Unsafe]
#ETCD_FORCE_NEW_CLUSTER="false"

#[Version]
#ETCD_VERSION="false"
#ETCD_AUTO_COMPACTION_RETENTION="0"

#[Profiling]
#ETCD_ENABLE_PPROF="false"
#ETCD_METRICS="basic"

#[Auth]
#ETCD_AUTH_TOKEN="simple"
EOF

cp /vagrant/configs/kubernetes.pem     /etc/etcd/kubernetes.pem
cp /vagrant/configs/kubernetes-key.pem /etc/etcd/kubernetes-key.pem
cp /vagrant/configs/ca.pem             /etc/etcd/ca.pem
chown etcd: /etc/etcd/*pem

systemctl enable --now etcd

# List etcd cluster members
#ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem


# control plane installation
yum -y install kubernetes-master

# api server
[[ ! -e /etc/kubernetes/apiserver.rpmorig ]] && mv /etc/kubernetes/apiserver /etc/kubernetes/apiserver.rpmorig

cat > /etc/kubernetes/apiserver <<EOF
###
# kubernetes system config
#
# The following values are used to configure the kube-apiserver
#

# The address on the local server to listen to.
KUBE_API_ADDRESS="--bind-address=0.0.0.0"

# The port on the local server to listen on.
# KUBE_API_PORT="--port=8080"

# Port minions listen on
# KUBELET_PORT="--kubelet-port=10250"

# Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=https://10.240.0.101:2379,https://10.240.0.102:2379,https://10.240.0.103:2379 --etcd-cafile=/var/lib/kubernetes/ca.pem --etcd-certfile=/var/lib/kubernetes/kubernetes.pem --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem"

# Address range to use for services
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.32.0.0/24"

# default admission control policies
KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota"

# Add your own!
KUBE_API_ARGS="--advertise-address=${INTERNAL_IP} \\
 --apiserver-count=3 \\
 --authorization-mode=RBAC \\
 --client-ca-file=/var/lib/kubernetes/ca.pem \\
 --enable-swagger-ui=true \\
 --event-ttl=1h \\
 --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
 --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
 --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
 --kubelet-https=true \\
 --runtime-config=api/all \\
 --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
 --service-node-port-range=30000-32767 \\
 --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
 --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem"
EOF

mkdir -p /var/lib/kubernetes
cp /vagrant/configs/ca.pem                  /var/lib/kubernetes/
cp /vagrant/configs/ca-key.pem              /var/lib/kubernetes/
cp /vagrant/configs/kubernetes-key.pem      /var/lib/kubernetes/
cp /vagrant/configs/kubernetes.pem          /var/lib/kubernetes/
cp /vagrant/configs/service-account-key.pem /var/lib/kubernetes/
cp /vagrant/configs/service-account.pem     /var/lib/kubernetes/
cp /vagrant/configs/encryption-config.yaml  /var/lib/kubernetes/
chown -R kube: /var/lib/kubernetes

systemctl enable --now kube-apiserver

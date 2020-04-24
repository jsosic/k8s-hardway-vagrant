#!/bin/bash

cat > /etc/yum.repos.d/google-cloudsdk.repo <<EOF
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

dnf -y update
dnf -y install epel-release
dnf -y install nc telnet bind-utils net-tools vim mlocate

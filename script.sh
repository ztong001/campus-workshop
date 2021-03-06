#!/bin/bash

helpme()
{
  cat <<HELPMEHELPME
Syntax: sudo $0

Installs the stuff needed to get the VirtualBox Ubuntu (or other similar Linux
host) into good shape to run our development environment.

This script needs to run as root.

The current directory must be the dev-env project directory.

HELPMEHELPME
}

if [[ "$1" == "-?" || "$1" == "-h" || "$1" == "--help" ]] ; then
  helpme
  exit 1
fi

# Installs the stuff needed to get the VirtualBox Ubuntu (or other similar Linux
# host) into good shape to run our development environment.

# ALERT: if you encounter an error like:
# error: [Errno 1] Operation not permitted: 'cf_update.egg-info/requires.txt'
# The proper fix is to remove any "root" owned directories under your update-cli directory
# as source mount-points only work for directories owned by the user running vagrant

# Stop on first error
set -e

# Install WARNING before we start provisioning so that it
# will remain active.  We will remove the warning after
# success
SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
cat "$SCRIPT_DIR/failure-motd.in" >> /etc/motd

# Update system
apt-get update -qq

# Prep apt-get for docker install
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

# Add docker repository
echo deb https://apt.dockerproject.org/repo ubuntu-trusty main > /etc/apt/sources.list.d/docker.list

# Update system
apt-get update -qq

# # Storage backend logic
# case "${DOCKER_STORAGE_BACKEND}" in
#   aufs|AUFS|"")
#     DOCKER_STORAGE_BACKEND_STRING="aufs" ;;
#   btrfs|BTRFS)
#     # mkfs
#     apt-get install -y btrfs-tools
#     mkfs.btrfs -f /dev/sdb
#     rm -Rf /var/lib/docker
#     mkdir -p /var/lib/docker
#     . <(sudo blkid -o udev /dev/sdb)
#     echo "UUID=${ID_FS_UUID} /var/lib/docker btrfs defaults 0 0" >> /etc/fstab
#     mount /var/lib/docker
# 
#     DOCKER_STORAGE_BACKEND_STRING="btrfs" ;;
#   *) echo "Unknown storage backend ${DOCKER_STORAGE_BACKEND}"
#      exit 1;;
# esac

# Install docker
apt-get install -y apparmor docker-engine
# linux-image-extra-$(uname -r)

# Configure docker
# DOCKER_OPTS="-s=${DOCKER_STORAGE_BACKEND_STRING} -r=true --api-cors-header='*' -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock ${DOCKER_OPTS}"
# sed -i.bak '/^DOCKER_OPTS=/{h;s|=.*|=\"'"${DOCKER_OPTS}"'\"|};${x;/^$/{s||DOCKER_OPTS=\"'"${DOCKER_OPTS}"'\"|;H};x}' /etc/default/docker

service docker restart
usermod -a -G docker vagrant # Add vagrant user to the docker group

#install docker-compose
curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Test docker
#docker run --rm busybox echo All good

docker pull yeasy/hyperledger-fabric:0.6-dp \
  && docker pull yeasy/hyperledger-fabric-peer:0.6-dp \
  && docker pull yeasy/hyperledger-fabric-base:0.6-dp \
  && docker pull yeasy/blockchain-explorer:latest \
  && docker tag yeasy/hyperledger-fabric-peer:0.6-dp hyperledger/fabric-peer \
  && docker tag yeasy/hyperledger-fabric-base:0.6-dp hyperledger/fabric-baseimage \
  && docker tag yeasy/hyperledger-fabric:0.6-dp hyperledger/fabric-membersrvc

#install npm
apt-get install -y npm
npm install -g npm
rm /usr/local/bin/npm
ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
npm install -g n
n 6.5.0


#install GO
# gcc for cgo
apt-get update && apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
	&& rm -rf /var/lib/apt/lists/*

export GOLANG_VERSION=1.7.5
GOLANG_DOWNLOAD_URL=https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
GOLANG_DOWNLOAD_SHA256=2e4dd6c44f0693bef4e7b46cc701513d74c3cc44f2419bf519d7868b12931ac3

curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
	&& echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
	&& tar -C /usr/local -xzf golang.tar.gz \
	&& rm golang.tar.gz

GOPATH=/go

mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
printf "\n\nexport GOPATH=${GOPATH}\nexport PATH=$GOPATH/bin:/usr/local/go/bin:$PATH\n" >> /home/vagrant/.profile

mkdir -p $GOPATH/src/github.com/hyperledger
cd $GOPATH/src/github.com/hyperledger ; git clone -b v0.6 https://github.com/hyperledger/fabric.git
chown vagrant:vagrant -R $GOPATH/src

# Set Go environment variables needed by other scripts
# export GOPATH="/opt/gopath"
# export GOROOT="/opt/go/"
# PATH=$GOROOT/bin:$GOPATH/bin:$PATH

# Ensure permissions are set for GOPATH
# sudo chown -R vagrant:vagrant $GOPATH

# finally, remove our warning so the user knows this was successful
rm /etc/motd

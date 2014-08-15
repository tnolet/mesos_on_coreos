#!/bin/sh

# This script does the basic install of Mesos on Debian 7 (wheezy). More specifically, it is bases
# on the ubuntu:latest docker image. Installation details mostly copied from  https://mesosphere.io/learn/run-docker-on-mesosphere/
# Note: this is a single host installation, where the mesos master, mesos slave and zookeeper run on the same machine.

## add mesosphere repo and keys
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

## update repos
sudo apt-get -y update
sudo apt-get -y install curl python-setuptools python-pip python-dev python-protobuf

## install zookeeperd
sudo apt-get -y install zookeeperd

## set a default id for zookeeper
echo 1 | sudo dd of=/var/lib/zookeeper/myid

## Install and run Docker
## http://docs.docker.io/installation/ubuntulinux/ for more details
##  We only use the client part and redirect it to use the docker daemon on the host.
## e.g. docker -H 10.1.42.1:2375 images
sudo apt-get -y install docker.io
sudo ln -sf /usr/bin/docker.io /usr/local/bin/docker
sudo sed -i '$acomplete -F _docker docker' /etc/bash_completion.d/docker.io

## install mesos, marathon and deimos
sudo apt-get -y install mesos marathon deimos
sudo mkdir -p /etc/mesos-master
echo in_memory | sudo dd of=/etc/mesos-master/registry

## Configure Deimos as a containerizer
sudo mkdir -p /etc/mesos-slave
echo /usr/local/bin/deimos | sudo tee /etc/mesos-slave/containerizer_path
echo external | sudo tee /etc/mesos-slave/isolation

# create a config file for deimos to talk to docker on the TCP port
# MOST IMPORTANT: create the "[log]" and "console..." stanzas are necessary due to a bug.
# A mesos slave will not start correctly with Deimos if these are not in the configuration.


echo "[docker]"                          > /etc/deimos.cfg
echo 'host: ["tcp://10.1.42.1:2375"]'   >> /etc/deimos.cfg
echo "[log]"                            >> /etc/deimos.cfg
echo "console: INFO"                    >> /etc/deimos.cfg

locale-gen en_US.UTF-8
service rsyslog start
service zookeeper start
service marathon start
/usr/bin/mesos-init-wrapper master &
/usr/local/sbin/mesos-slave --master=zk://localhost:2181/mesos --work_dir=/var/lib/mesos --isolation=external --containerizer_path=/usr/local/bin/deimos --hostname=172.17.8.101 > /dev/null 2>&1 &



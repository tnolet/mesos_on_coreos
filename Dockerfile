FROM ubuntu:latest

MAINTAINER tim@magnetic.io

# This Dockerfile does the basic install of Mesosphere stack on CoreOS using the Ubuntu base Docker container.
# Installation details mostly copied from  https://mesosphere.io/learn/run-docker-on-mesosphere/
# Some tweaks are needed when starting this container to get Mesos running in Docker.
# 1. The CoreOS host needs to mount the Docker socket to the container
# 2. The Docker containers for Mesos master and slave need to use the --net=host option to bind directly to the host's
#    network stack.
# 3. Deimos can instruct Docker to download images, for this it needs access to the disk cache. So, we
#    need to mount the /var/lib/docker/... on CoreOS to our Ubuntu container, e.g.
#    docker run -v /var/lib/docker/btrfs/subvolumes:/var/lib/docker/btrfs/subvolumes
#
# For more info, see the accompanying README.md and mesos_bootstrap.sh script

# add mesosphere repo and keys
RUN echo "deb http://repos.mesosphere.io/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mesosphere.list

RUN sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF

# update repos
RUN sudo apt-get -y update

RUN sudo apt-get -y install curl python-setuptools python-pip python-dev python-protobuf

# install zookeeperd
RUN sudo apt-get -y install zookeeperd

# set an initial id for zookeeper
RUN echo 1 | sudo dd of=/var/lib/zookeeper/myid

# Install and run Docker
# http://docs.docker.io/installation/ubuntulinux/ for more details
#  We only use the client part. We bind the the docker.sock from the host to the container.
RUN sudo apt-get -y install docker.io

RUN sudo ln -sf /usr/bin/docker.io /usr/local/bin/docker

RUN sudo sed -i '$acomplete -F _docker docker' /etc/bash_completion.d/docker.io

# install mesos, marathon and deimos
RUN sudo apt-get -y install mesos=0.19.1-1.0.ubuntu1404

RUN sudo apt-get -y install marathon=0.6.1-1.1

RUN sudo apt-get -y install deimos=0.2.3

# Add the bootstrap script

ADD ./mesos_bootstrap.sh /usr/local/bin/mesos_bootstrap.sh

# use the mesos_bootstrap.sh script to start

ENTRYPOINT ["/usr/local/bin/mesos_bootstrap.sh"]
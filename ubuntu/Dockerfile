FROM ubuntu:latest

MAINTAINER tim@magnetic.io

# This Dockerfile does the basic install of Mesosphere stack on CoreOS using the Ubuntu base Docker container.
# Installation details mostly copied from  https://mesosphere.io/learn/run-docker-on-mesosphere/
# However, some tweaks are needed to get mesos running in Docker.
# 1. The CoreOS host needs to expose the Docker API via TCP (e.g. localhost:2375)
# 2. The Docker container needs to access the Docker API using the Docker0 bridge.
#    e.g. On CoreOS this is 10.1.42.1:2375
# 3. The slave needs to report the CoreOS hostname as its own hostname to the master
#    For this, you need to pass in the CoreOS hostname into the container when starting up, e.g.
#    docker run -h `hostname`
# 4. Deimos can instruct Docker to download images, for this it needs access to the disk cache. So, we
#    need to mount the /var/lib/docker/... on CoreOS to our Ubuntu container, e.g.
#    docker run -v /var/lib/docker/btrfs/subvolumes:/var/lib/docker/btrfs/subvolumes
#
# Note: this is a single host installation, where the mesos master, mesos slave and zookeeper run on the same machine.

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
RUN sudo apt-get -y install mesos marathon deimos

# Add the bootstrap script

ADD ./mesos_bootstrap.sh /usr/local/bin/mesos_bootstrap.sh

# use the mesos_bootstrap.sh script to start

ENTRYPOINT ["/usr/local/bin/mesos_bootstrap.sh"]





#!/bin/bash

########################################################################################################################
##
##
##  Mesos_bootstrap.sh relies on the following environment variables. The MAIN_IP and DOCKER0_IP are required and have
##  no default. You should pass them into the Docker container using the -e flag.
##
##  $MAIN_IP                - the IP of the host running Docker to which Mesos master and slave can bind (required)
##  $DOCKER0_IP             - the IP assigned to the docker0 interface onthe CoreOS host
##  $ETCD_PORT              - the port on which ETCD runs on CoreOS (default: 4001)
##  $ETCD_MESOS_PATH        - the path in ETCD where we store Mesos related data (default: /mesos)
##  $ETCD_TTL               - the TTL used in retrying ETCD calls
##
##  Usage:
##
##  When no arguments are passed into this script, it will try to dynamically configure a Mesos cluster consisting of:
##  - 1 node running a Master, Zookeeper, Marathon and a local Slave
##  - x slave nodes, depending on the amount of nodes you spin up
##
##  Discovery of the Master's IP is done using ETCD. For this to work, all nodes should be in the same ETCD cluster.
##  If automagic setup doesn't work, you can also pass in arguments and flag to set up Mesos manually:
##
##
##
##  For example, when you want to start a master
##
##  $ ./mesos_bootstrap.sh master`
##
##  When starting a slave you need to pass in the Master's Zookeeper address
##
##  $ ./mesos_bootstrap.sh slave --master=zk://172.17.8.101/mesos
##
##  Starting a Marathon instance is the same as a slave
##
##  $ ./mesos_bootstrap.sh marathon --master=zk://172.17.8.101/mesos --etcd=false
##
##  This script is partly based on the great work by deis:
##  https://github.com/deis/
##
## @todo: replace flags with REAL flags that don't depend on the position in cmd line
##
########################################################################################################################

# set font types
bold="\e[1;36m"
normal="\e[0m"
red="\e[0;31m"
yellow="\e[0;33m"
green="\e[0;32m"
blue="\e[0;34m"
purple="\e[0;35 m"
normal="\e[0m"

export MAIN_IP=${MAIN_IP}
export MESOS_BOOTSTRAP_VERSION=1.0


echo -e  "${bold}==> Starting Mesos/CoreOS Bootstrap on $MAIN_IP (version $MESOS_BOOTSTRAP_VERSION)${normal}"


# configure docker
export DOCKER0_IP=${DOCKER0_IP}
export DOCKER_PORT=${DOCKER_PORT:-2375}
export DOCKER="$DOCKER0_IP:$DOCKER_PORT"

# configure etcd
export ETCD_PORT=${ETCD_PORT:-4001}
export ETCD="$DOCKER0_IP:$ETCD_PORT"
export ETCD_PATH=${ETCD_PATH:-/mesos}
export ETCD_TTL=${ETCD_TTL:-10}

# configure Mesos
export MASTER_PORT=${MASTER_PORT:-5050}
export SLAVE_PORT=${SLAVE_PORT:-5051}


MAX_RETRIES_CONNECT=10
retry=0

# Set locale: this is required by the standard Mesos startup scripts
echo -e  "${normal}==> info: Setting locale to en_US.UTF-8..."
locale-gen en_US.UTF-8 > /dev/null 2>&1

# Start syslog if not started....
echo -e  "${normal}==> info: Starting syslog..."
service rsyslog start > /dev/null 2>&1


# All functions
function start_zookeeper {
    echo -e  "${normal}==> info: Starting Zookeeper..."
    service zookeeper start
}

function start_slave {

    set_deimos

    MASTER=`echo $1 | cut -d '=' -f2`

    # using ETCD or not?
    USING_ETCD=`echo $2 | cut -d '=' -f2`

    # set the slave parameters
    echo ${MASTER} > /etc/mesos/zk
    echo /var/lib/mesos > /etc/mesos-slave/work_dir
    echo external > /etc/mesos-slave/isolation
    echo /usr/local/bin/deimos > /etc/mesos-slave/containerizer_path
    echo ${MAIN_IP}  > /etc/mesos-slave/ip

    echo -e  "${bold}==> info: Mesos slave will try to register with a master at ${MASTER}"
    echo -e  "${normal}==> info: Starting slave..."

    /usr/bin/mesos-init-wrapper slave > /dev/null 2>&1 &

	# wait for the slave to start
    sleep 1 && while [[ -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$SLAVE_PORT\" && \$1 ~ tcp") ]] ; do
	    echo -e  "${normal}==> info: Waiting for Mesos slave to come online..."
	    sleep 3;
	done
	echo -e  "${normal}==> info: Mesos slave started on port ${SLAVE_PORT}"

    # When not using ETCD for Master discovery, this is the end of the script.
    if [ ${USING_ETCD} = false ]; then
        # while the Slave runs, keep the Docker container running
        while [[ ! -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$SLAVE_PORT\" && \$1 ~ tcp") ]] ; do
            echo -e  "${normal}==> info: `date` - Mesos slave is running on port ${SLAVE_PORT}"
            sleep 10
        done
    fi

}

function start_master {

    # using ETCD or not?
    USING_ETCD=`echo $1 | cut -d '=' -f2`

    echo $MAIN_IP > /etc/mesos-master/ip
    echo in_memory > /etc/mesos/registry
    echo "zk://localhost:2181/mesos" > /etc/mesos/zk

    echo -e  "${normal}==> info: Starting Mesos master..."

    /usr/bin/mesos-init-wrapper master > /dev/null 2>&1 &

	# wait for the master to start
    sleep 1 && while [[ -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$MASTER_PORT\" && \$1 ~ tcp") ]] ; do
	    echo -e  "${normal}==> info: Waiting for Mesos master to come online..."
	    sleep 3;
	done
	echo -e  "${normal}==> info: Mesos master started on port ${MASTER_PORT}"

    # When not using ETCD for Master discovery, this is the end of the script.
    if [ ${USING_ETCD} = false ]; then

        # while the Master runs, keep the Docker container running
        while [[ ! -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$MASTER_PORT\" && \$1 ~ tcp") ]] ; do
            echo -e  "${normal}==> info: `date` - Mesos master is running on port ${MASTER_PORT}"
            sleep 10
        done

    fi
}

function start_marathon {
    MASTER_MARATHON=`echo $1 | cut -d '=' -f2`
        # using ETCD or not?
    USING_ETCD=`echo $2 | cut -d '=' -f2`

    echo $MASTER_MARATHON > /etc/mesos/master
    echo $MASTER_MARATHON > /etc/mesos/zk
    service marathon start > /dev/null 2>&1 &

    # while marathon runs, keep the Docker container running
    while [[ ! -z $(ps -ef | grep marathon | grep -v grep) ]] ; do
        echo -e  "${normal}==> info: `date` - Marathon with master ${MASTER_MARATHON} is running"
        sleep 10
    done

}

function set_deimos {

    # Set the Deimos configuration Dockerfile
    echo "[docker]"                          > /etc/deimos.cfg
    echo "[log]"                            >> /etc/deimos.cfg
    echo "console: INFO"                    >> /etc/deimos.cfg

}

function print_usage {

    echo "not implemented yet"

}

function print_auto_mode {

    echo -e  "${normal}==> info: No flags or parameters were given, starting auto discovery..."

}

# Catch the command line options.
case "$1" in
    marathon)
        start_marathon $2;;
    master)
        start_zookeeper && start_master --etcd=false;;
    slave)
        start_slave $2 --etcd=false;;
    help)
        print_usage;;
    *)
        print_auto_mode
esac

#
# ETCD POLLING
#

echo -e  "${normal}==> info: Connecting to ETCD..."

# wait for etcd to be available
until curl -L http://${ETCD}/v2/keys/ > /dev/null 2>&1; do
	echo -e  "${normal}==> info: Waiting for etcd at $ETCD..."
	sleep $(($ETCD_TTL/2))  # sleep for half the TTL
	if [[ "$retry" -gt ${MAX_RETRIES_CONNECT} ]]; then
	echo -e  "==> error: Exceed maximum of ${MAX_RETRIES_CONNECT}...exiting"
	exit 1
	fi
	((retry++))
done

# wait until etcd has discarded potentially stale values
sleep $(($ETCD_TTL/2))

echo -e  "${normal}==> info: Connected to ETCD at $ETCD"

# Try to determine if there already is a master. This should return a valid public IP number.
export MASTER_IP=`curl -Ls ${ETCD}/v2/keys/mesos/master | \
                    sed -n 's/^.*"value":"\([0-9]\)/1/p' | \
                    sed -n 's/[{}]//g;p' | \
                    cut -d '"' -f1`

# Here comes the decision tree...
# 1. If we find an active master through ETCD, connect to it using zookeeper
# 2. If no master is found, just start a slave. Not much use...but hey....


if [[ ! -z ${MASTER_IP} ]]; then

    start_slave --master=zk://${MASTER_IP}:2181/mesos --etcd=true

# Create a master and slave and register the master's zookeeper ID in ETCD.
# Then start a Marathon instance.

    else

    echo -e  "${bold}==> info: Found no master: will start a new master and slave"

    start_zookeeper

    start_master --etcd=true

    start_slave --master=zk://localhost:2181/mesos --etcd=true

    # start Marathon
    echo -e  "${bold}==> info: Starting Marathon in a separate container..."
    docker run --rm --name marathon -p 8080:8080 tnolet/mesos-on-coreos:1.0 marathon --master=zk://${MAIN_IP}:2181/mesos &


    # While the master is running, keep publishing its IP to ETCD
    while [[ ! -z $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".$MASTER_PORT\" && \$1 ~ tcp") ]] ; do
	    curl -L http://${ETCD}/v2/keys${ETCD_PATH}/master -XPUT -d value=${MAIN_IP} -d ttl=${ETCD_TTL} >/dev/null 2>&1
		sleep $(($ETCD_TTL/2)) # sleep for half the TTL
    done

    exit 1
fi

wait


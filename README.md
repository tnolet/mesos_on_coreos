# Mesos-on-coreos

An Ubuntu container for Apache Mesos and Marathon on CoreOS. You can use Deimos in conjunction with Marathon and Mesos
to run Docker containers on the CoreOS host that is hosting this container.
For more info on Mesos and Marathon, please visit
[mesosphere.io](http://www.mesosphere.io)

## Usage

This container has a basic install of Zookeeper, Mesos, Marathon and Deimos. It kick starts a `mesos_bootstrap.sh`
script to configure all the components. For this, it needs some environment variables to be passed in using the `-e` flag.
The `MAIN_IP` and `DOCKER0_IP` are required and have no default. 

    $MAIN_IP         - the IP of the host running Docker to which Mesos master and slave can bind (required)
    $DOCKER0_IP      - the IP assigned to the docker0 interface onthe CoreOS host
    $ETCD_PORT       - the port on which ETCD runs on CoreOS (default: 4001)
    $ETCD_MESOS_PATH - the path in ETCD where we store Mesos related data (default: /mesos)
    $ETCD_TTL        - the TTL used in retrying ETCD calls in seconds (default: 10)

This container also relies on a working ETCD connection, typically used with CoreOS.


When no arguments are passed into this script, it will try to dynamically configure a Mesos cluster consisting of:  
- 1 node running a Master, Zookeeper, Marathon and a local slave. Marathon runs in a separate docker container.    
- x slave nodes, depending on the amount of nodes you spin up. The slaves only run the Mesos slave process and Deimos.  

Discovery of the Master's IP and reporting it to slaves is done using ETCD. For this to work, all nodes should be in 
the same ETCD cluster. 
If automagic setup doesn't work, you can also pass in arguments and the `--etcd=false` flag to set up Mesos manually.

## Example: auto-discovery with ETCD

For example, when you want to start up the whole shebang using auto-discovery.

    docker run --rm --name mesos \ 
                    --net=host \
                    -p 5050:5050 \
                    -p 5051:5051 \
                    -p 2181:2181 \
                    -e MAIN_IP=172.17.8.101 \
                    -e DOCKER0_IP=`ifconfig docker0 | grep 'inet ' | awk '{print $2}'` \
                    -v /var/lib/docker/btrfs/subvolumes:/var/lib/docker/btrfs/subvolumes \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    tnolet/mesos-on-coreos:1.0

Notice we are passing in the `PUBLIC_IP` environment variable and dynamically grabbing the docker0 IP. 
Also, we do not run in bridged mode but use the hosts IP
network stack. This is important for Mesos masters and slaves for reporting the hosts IP address using Zookeeper.

After the whole thing is started up, the normal API and dashboards are available at the master's IP, e.g 
`172.17.8.101:5050` for the Mesos dashboard and `172.17.8.101:8080` for Marathon.

## Example: manual configuration

When  using ETCD for auto-discovery, you need to first start a master passing in the `--etcd=false` flag. This 
will start a master and a zookeeper instance in the same container

    ...
    tnolet/mesos-on-coreos:1.0 master --etcd=false

Then start a Marathon container, passing in the zookeeper address for the master. No need to specify the extra etcd flag. 

    ...
    tnolet/mesos-on-coreos:1.0 master marathon --master=zk://172.17.8.101/mesos 

Then start a slave container, passing in the zookeeper address for the master. You can boot up as many slaves as you want
on as many containers. As longs as they are reachable over the network.

    ...
    tnolet/mesos-on-coreos:1.0 master slave --master=zk://172.17.8.101/mesos


## Systemd and Cloud-config

CoreOS uses `systemd` and `cloudconfig` to control running services on startup. You can find examples of the above 
commands in the a handy `user-data.yml` which you can use with CoreOS to get all this running instantly at boot.
You can find it in the [https://github.com/tnolet/mesos_on_coreos](https://github.com/tnolet/mesos_on_coreos) repo.

## AWS and Vagrant

In the [https://github.com/tnolet/mesos_on_coreos](https://github.com/tnolet/mesos_on_coreos) repo you can also find
a pre-configured Vagrantfile and AWS Cloudformation template ([aws_cfn_template.json](https://github.com/tnolet/mesos_on_coreos/blob/master/aws_cfn_template.json)). Passing in a fresh ETCD discovery URL into either using
the `user-data.yml` should get you up and running very fast.

### Vagrant example

Set the `num_instances` option to the total amount of boxes you want to spin up. This includes the master. You can also
set the memory and amount of CPU's if you like.

    # Vagrantfile
    CLOUD_CONFIG_PATH = "./user-data.yml"
    
    $num_instances = 3
    $vb_memory = 1024
    $vb_cpus = 1
Open the accompanying `user-data.yml` an paste in a discovery URL from ETCD (found here: [http://discovery.etcd.io/new](http://discovery.etcd.io/new))
 
    #user-data.yml
    coreos:
      etcd:
          #generate a new token for each unique cluster from https://discovery.etcd.io/new
          discovery: https://discovery.etcd.io/27f2c10f29cd24a466a634aaabf64b2d
Then do a `vagrant up` and grab some coffee. It will downloaded CoreOS once and the mesos-on-coreos docker container for
 each box. 
 
### *Quick Tip*

If you are fed up with downloading containers when developing, save the container to disk and import it when you are booting 
your Vagrant boxes. It saves a lot of time when you are destroying your Vagrant boxes a lot.

        $ docker save tnolet/mesos-on-coreos > tnolet_mesos-on-coreos.tar

Just mount your disk to Vagrant and import it using this snippet in your Vagrantfile:

    DOCKER_UBUNTU_MESOS="tnolet_mesos-on-coreos.tar"
    
    config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']
    config.vm.provision :shell, :inline => "export TMPDISK=/", :privileged => false
    if File.exist?(DOCKER_UBUNTU_MESOS)
        config.vm.provision :shell, :inline => "docker load -i /home/core/share/#{DOCKER_UBUNTU_MESOS}", :privileged => false
    end

This was tested on OSX Mavericks.

## Todo

-   replace flags with REAL flags that don't depend on the position in cmd line


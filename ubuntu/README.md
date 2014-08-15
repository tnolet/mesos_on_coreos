# Running Apache Mesos on CoreOS
---


## Goal

Run a Mesos cluster on CoreOS, and to spice it up a bit also make it configure itself.

## Challenges

1.  upstart and initctl
2.  ip's
3.  random stuff (log statements, locale etc.)
4.  hostnames
5.  using docker on the host, not inside the guest
6.  volumes
7.  Zookeeper publishing private Docker IP instead of public IP (fix by --net=host and binding mesos to a specific IP using --ip)
8.  Only marathon plays up. It needs to validate the hostname, but can't. Shouldn't be a big problen on AWS or your own DC, but I'm not running 
    a DNS on my Macbook and (for now) Docker doesn't allow editing a /etc/hosts file.


## Installing


## Run it!

<pre>
docker run -i -t -p 5050:5050 -p 8080:8080 -p 5051:5051 -h `hostname` -v /var/lib/docker/btrfs/subvolumes:/var/lib/docker/btrfs/subvolumes tnolet/ubuntu_mesos:1.0 /bin/bash -l
</pre>

`/usr/local/sbin/mesos-master --registry=in_memory --quorum=1 --zk=zk://localhost:2181/mesos --port=5050 --work_dir=/var/lib/mesos > /dev/null 2>&1 &`

`/usr/local/sbin/mesos-slave --master=zk://localhost:2181/mesos --log_dir=/var/log/mesos --containerizer_path=/usr/local/bin/deimos --isolation=external > /dev/null 2>&1 $`


## Deploy a Docker container

Json file

<pre>
{
    "container": {
    "image": "docker:///busybox:latest",
    "options" : ["-P"]
  },
  "id": "busybox",
  "instances": "1",
  "cpus": ".5",
  "mem": "350",
  "uris": [],
  "cmd": "sleep 5",
  "ports" : []
}
</pre>

I'm using [HTTPie](https://github.com/jakubroztocil/httpie)
<pre>
Tims-MacBook-Pro:mesos tim$ http POST 172.17.8.101:8080/v2/apps < busy.json  
HTTP/1.1 201 Created  
Content-Type: application/json  
Location: http://172.17.8.101:8080/v2/apps/busybox  
Server: Jetty(8.y.z-SNAPSHOT)  
Transfer-Encoding: chunked   
null  
</pre>



docker run -i -t --rm --name ubuntu_mesos --net=host -p 5050:5050 -p 8080:8080 -p 5051:5051 -p 2181:2181 -e PUBLIC_IP=172.17.8.101 -v /var/lib/docker/btrfs/subvolumes:/var/lib/docker/btrfs/subvolumes -v /var/run/docker.sock:/var/run/docker.sock tnolet/ubuntu_mesos:1.0 /bin/bash -l

docker run -i -t --rm --name ubuntu_marathon -P -e PUBLIC_IP=172.17.8.101 tnolet/ubuntu_mesos:1.0 /bin/bash -l


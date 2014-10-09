# ElastiCache - the CoreOS way

I've used AWS ElastiCache for memcached services before and wanted to play
around with CoreOS and see if I could achieve roughly the same clustering using
fleetctl and similar service discovery capabilities for applications using etcd.

Currently, this repo provides a Vagrantfile to create a 3 node CoreOS cluster.

## Getting started

### Install dependencies
 * [VirtualBox][virtualbox] 4.3.10 or greater.
 * [Vagrant][vagrant] 1.6 or greater.

### Start the 3 node coreos cluster

  ```shell
  $ vagrant up
  ```

### ssh to one of the the nodes

  ```shell
  $ ssh-add ~/.vagrant.d/insecure_private_key
  $ vagrant ssh core-01 -- -A
  ```

### Deploy 3 memcached Docker containers and register them with etcd

  ```shell
  core@core-01 ~ $ cd share
  core@core-01 ~/share $ fleetctl submit memcached@.service memcached-discovery@.service
  core@core-01 ~/share $ fleetctl start memcached@{1..3}.service
  core@core-01 ~/share $ fleetctl start memcached-discovery@{1..3}.service
  ```

### Where is everything running in the cluster?

  ```shell
  core@core-01 ~ $ fleetctl list-units
  ```

### Use your memcached nodes

The memcached processes are listening on 11211 on each Vagrant VM. You should
be able to telnet to each vm from your Vagrant host machine using these addresses
and ports:

 * 172.17.8.101 11211
 * 172.17.8.102 11211
 * 172.17.8.103 11211

## What more is planned?

I hope to add the following to this repo over the coming weeks:

 * An AWS CloudFormation that launches this CoreOS infrastructure in EC2 across multiple AZs
 * Use https://coreos.com/docs/launching-containers/launching/launching-containers-fleet/#schedule-based-on-machine-metadata to ensure the memcached containers can be scheduled across multiple AZs for HA
 * Improve the memcached-discovery service to more meaningfully report the health of the memcached service

## Related Reading
 * https://github.com/coreos/coreos-vagrant
 * https://coreos.com/docs/launching-containers/launching/launching-containers-fleet/
 * https://www.digitalocean.com/community/tutorials/how-to-create-flexible-services-for-a-coreos-cluster-with-fleet-unit-files

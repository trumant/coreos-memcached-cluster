# ElastiCache - the CoreOS way

I've used AWS ElastiCache for memcached services before and wanted to play
around with CoreOS and see if I could achieve roughly the same clustering using
fleetctl and similar service discovery capabilities using etcd.

You can choose to run the CoreOS cluster on Vagrant or EC2.

Each node in the CoreOS cluster runs memcached and publishes memcached connection
details to etcd at /services/memcached/.

## Getting started

### Requirements
 * [VirtualBox][virtualbox] 4.3.10 or greater.
 * [Vagrant][vagrant] 1.6 or greater.
 * AWS Account
 * Install and configure [aws-cli](https://github.com/aws/aws-cli#installation)
 * Ruby, Bundler

## Standup the Vagrant cluster

Vagrantfile creates a 3 node CoreOS cluster and uses a dynamically generated etcd
discovery url. Every vagrant up will create a new cluster.

### Start the 3 node coreos cluster

  ```shell
  $ vagrant up
  ```

You'll have 3 vagrants running as core-01, core-02, core-03 at:
 * 172.17.8.101
 * 172.17.8.102
 * 172.17.8.103

### ssh to one of the the nodes

  ```shell
  $ ssh-add ~/.vagrant.d/insecure_private_key
  $ vagrant ssh core-01 -- -A
  ```

## Standup the AWS CloudFormation Stack

### Generate the CloudFormation template

```bash
$ ./coreos-memcached-cloudformation.rb expand > coreos-memcached-cluster.json
$ aws cloudformation validate-template --template-body file://coreos-memcached-cluster.json
```

If the template validates successfully, you'll see a listing of all parameters
accepted by the stack.

### Create the stack

#### Stack Parameters

You must provide values for the following parameters:

- DiscoveryURL - generate a new one at [https://discovery.etcd.io/new]
- KeyPair - your EC2 Key Pair name
- GithubUser - your Github user name - to authorize your Github public key for the core user on the CoreOS nodes

To customize the security profile of your stack, also override the default value of:

- AllowSSHFrom - defaults to the public ip of the box that generated the CloudFormation file

#### Run the create

```bash
$ aws cloudformation create-stack --stack-name coreos-memcached-cluster \
   --template-body file://coreos-memcached-cluster.json \
   --parameters '[{"ParameterKey":"DiscoveryURL", "ParameterValue":"YOUR_DISCOVERY_URL_HERE"}, {"ParameterKey":"KeyPair", "ParameterValue":"YOUR_EC2_KEY_NAME_HERE"}, {"ParameterKey":"GithubUser", "ParameterValue":"YOUR_GITHUB_USERNAME_HERE"}]'
```

### Update the stack

The default value for CidrIp will only allow SSH from the public IPv4 of the host you create the stack from. If your public IPv4 changes, re-generate the stack file using:

```bash
$ ./coreos-memcached-cloudformation.rb expand > coreos-memcached-cluster.json
```

And run a stack update:

```bash
$ aws cloudformation update-stack --stack-name coreos-memcached-cluster \
   --template-body file://coreos-memcached-cluster.json
```

## Deploy the memcached containers

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

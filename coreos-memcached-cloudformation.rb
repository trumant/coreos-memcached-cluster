#!/usr/bin/env ruby

require 'bundler/setup'
require 'cloudformation-ruby-dsl/cfntemplate'
require 'cloudformation-ruby-dsl/spotprice'
require 'cloudformation-ruby-dsl/table'
require 'open-uri'

template do

  value :AWSTemplateFormatVersion => '2010-09-09'

  value :Description => 'CoreOS on EC2: http://coreos.com/docs/running-coreos/cloud-providers/ec2/'

  mapping 'RegionMap',
          :'ap-northeast-1' => { :AMI => 'ami-97ab9e96' },
          :'sa-east-1' => { :AMI => 'ami-b148fdac' },
          :'ap-southeast-2' => { :AMI => 'ami-47ed8f7d' },
          :'ap-southeast-1' => { :AMI => 'ami-de52748c' },
          :'us-east-1' => { :AMI => 'ami-ba902dd2' },
          :'us-west-2' => { :AMI => 'ami-e590ddd5' },
          :'us-west-1' => { :AMI => 'ami-8b5359ce' },
          :'eu-west-1' => { :AMI => 'ami-8c9d3ffb' }

  # Note we're using public subnets here. Since memcached is a backend service
  # we wouldn't typical expose it publically. Its done for this example only to
  # avoid creating a bastion instance. DO NOT USE THIS IN PRODUCTION UN-MODIFIED
  mapping 'SubnetConfig',
      :VPC => { :CIDR => "10.236.0.0/16" },
      :PublicSubnetA  => { :CIDR => "10.236.100.0/24" },
      :PublicSubnetB  => { :CIDR => "10.236.101.0/24" },
      :PublicSubnetC  => { :CIDR => "10.236.102.0/24" }

  parameter 'InstanceType',
            :Description => 'EC2 HVM instance type (m3.medium, etc).',
            :Type => 'String',
            :Default => 't2.micro',
            :AllowedValues => [
                'm3.medium',
                'm3.large',
                'm3.xlarge',
                'm3.2xlarge',
                'c3.large',
                'c3.xlarge',
                'c3.2xlarge',
                'c3.4xlarge',
                'c3.8xlarge',
                'cc2.8xlarge',
                'cr1.8xlarge',
                'hi1.4xlarge',
                'hs1.8xlarge',
                'i2.xlarge',
                'i2.2xlarge',
                'i2.4xlarge',
                'i2.8xlarge',
                'r3.large',
                'r3.xlarge',
                'r3.2xlarge',
                'r3.4xlarge',
                'r3.8xlarge',
                't2.micro',
                't2.small',
                't2.medium',
            ],
            :ConstraintDescription => 'Must be a valid EC2 HVM instance type.'

  parameter 'ClusterSize',
            :Default => '3',
            :MinValue => '3',
            :MaxValue => '12',
            :Description => 'Number of nodes in cluster (3-12).',
            :Type => 'Number'

  parameter 'DiscoveryURL',
            :Description => 'An unique etcd cluster discovery URL. Grab a new token from https://discovery.etcd.io/new',
            :Type => 'String'

  parameter 'AdvertisedIPAddress',
            :Description => 'Use \'private\' if your etcd cluster is within one region or \'public\' if it spans regions or cloud providers.',
            :Default => 'private',
            :AllowedValues => [ 'private', 'public' ],
            :Type => 'String'

  parameter 'AllowSSHFrom',
            :Description => 'The net block (CIDR) that SSH is available to.',
            :Default => "#{open("http://api.ipify.org").read}/32",
            :Type => 'String'

  parameter 'KeyPair',
            :Description => 'The name of an EC2 Key Pair to allow SSH access to the instance.',
            :Type => 'String'

  parameter 'GithubUser',
            :Description => 'The public key associated with this github user will be added to the authorized keys for the core user',
            :Type => 'String'

  resource 'CoreOSVPC', :Type => 'AWS::EC2::VPC', :Properties => {
    :CidrBlock => find_in_map("SubnetConfig", "VPC", "CIDR"),
    :EnableDnsSupport => false,
    :EnableDnsHostnames => false
  }

  resource 'PublicSubnetA', :Type => 'AWS::EC2::Subnet', :DependsOn => 'CoreOSVPC', :Properties => {
    :VpcId => ref('CoreOSVPC'),
    :AvailabilityZone => join("", aws_region, "a"),
    :CidrBlock => find_in_map("SubnetConfig", "PublicSubnetA", "CIDR")
  }

  resource 'PublicSubnetB', :Type => 'AWS::EC2::Subnet', :DependsOn => 'CoreOSVPC', :Properties => {
    :VpcId => ref('CoreOSVPC'),
    :AvailabilityZone => join("", aws_region, "b"),
    :CidrBlock => find_in_map("SubnetConfig", "PublicSubnetB", "CIDR")
  }

  resource 'PublicSubnetC', :Type => 'AWS::EC2::Subnet', :DependsOn => 'CoreOSVPC', :Properties => {
    :VpcId => ref('CoreOSVPC'),
    :AvailabilityZone => join("", aws_region, "c"),
    :CidrBlock => find_in_map("SubnetConfig", "PublicSubnetC", "CIDR")
  }

  resource 'CoreOSSecurityGroup', :Type => 'AWS::EC2::SecurityGroup', :DependsOn => 'CoreOSVPC', :Properties => {
      :GroupDescription => 'CoreOS SecurityGroup',
      :SecurityGroupIngress => [
          {
              :IpProtocol => 'tcp',
              :FromPort => '22',
              :ToPort => '22',
              :CidrIp => ref('AllowSSHFrom'),
          },
      ],
      :VpcId => ref('CoreOSVPC')
  }

  # For memcached services provided by the cluster
  resource 'Ingress11211', :Type => 'AWS::EC2::SecurityGroupIngress', :DependsOn => 'CoreOSSecurityGroup', :Properties => {
      :IpProtocol => 'tcp',
      :FromPort => '11211',
      :ToPort => '11211',
      :GroupId => get_att('CoreOSSecurityGroup', 'GroupId'),
      :SourceSecurityGroupId => get_att('CoreOSSecurityGroup', 'GroupId'),
  }

  # For etcd cluster communication
  resource 'Ingress4001', :Type => 'AWS::EC2::SecurityGroupIngress', :DependsOn => 'CoreOSSecurityGroup', :Properties => {
      :IpProtocol => 'tcp',
      :FromPort => '4001',
      :ToPort => '4001',
      :GroupId => get_att('CoreOSSecurityGroup', 'GroupId'),
      :SourceSecurityGroupId => get_att('CoreOSSecurityGroup', 'GroupId'),
  }

  # For etcd cluster communication
  resource 'Ingress7001', :Type => 'AWS::EC2::SecurityGroupIngress', :DependsOn => 'CoreOSSecurityGroup', :Properties => {
      :IpProtocol => 'tcp',
      :FromPort => '7001',
      :ToPort => '7001',
      :GroupId => get_att('CoreOSSecurityGroup', 'GroupId'),
      :SourceSecurityGroupId => get_att('CoreOSSecurityGroup', 'GroupId'),
  }

  # An etcd cluster requires at least 3 nodes at all times
  resource 'CoreOSServerAutoScale', :Type => 'AWS::AutoScaling::AutoScalingGroup', :Properties => {
      :AvailabilityZones => [
        join("", aws_region, "a"),
        join("", aws_region, "b"),
        join("", aws_region, "c")
      ],
      :LaunchConfigurationName => ref('CoreOSServerLaunchConfig'),
      :MinSize => '3',
      :MaxSize => '12',
      :DesiredCapacity => ref('ClusterSize'),
      :Tags => [
          {
              :Key => 'Name',
              :Value => aws_stack_name,
              :PropagateAtLaunch => true,
          },
      ],
      :VPCZoneIdentifier => [
        ref('PublicSubnetA'),
        ref('PublicSubnetB'),
        ref('PublicSubnetC'),
      ]
  }

  cloud_config_user_data = %Q(
    #cloud-config

    coreos:
      etcd:
        discovery: {{ref('DiscoveryURL')}}
        addr: {{ref('AdvertisedIPAddress')}}_ipv4:4001
        peer-addr: {{ref('AdvertisedIPAddress')}}_ipv4:7001
      fleet:
        public-ip: {{ref('AdvertisedIPAddress')}}_ipv4
        metadata: region={{aws_region}},instance_type={{ref('InstanceType')}}
      units:
      - name: etcd.service
        command: start
      - name: fleet.service
        command: start
      users:
      - name: core
        coreos-ssh-import-github: {{ref('GithubUser')}}
      write_files:
      - path: /etc/ssh/sshd_config
        permissions: 0600
        owner: root:root
        content: |
          # Use most defaults for sshd configuration.
          UsePrivilegeSeparation sandbox

          PermitRootLogin no
          AllowUsers core
          PasswordAuthentication no
          ChallengeResponseAuthentication no
  )

  resource 'CoreOSServerLaunchConfig', :Type => 'AWS::AutoScaling::LaunchConfiguration', :Properties => {
      :ImageId => find_in_map('RegionMap', aws_region, 'AMI'),
      :InstanceType => ref('InstanceType'),
      :KeyName => ref('KeyPair'),
      :SecurityGroups => [ ref('CoreOSSecurityGroup') ],
      :UserData => base64(interpolate(cloud_config_user_data))
  }

end.exec!

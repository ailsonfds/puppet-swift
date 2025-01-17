Team and repository tags
========================

[![Team and repository tags](https://governance.openstack.org/tc/badges/puppet-swift.svg)](https://governance.openstack.org/tc/reference/tags/index.html)

<!-- Change things from this point on -->

swift
=======

#### Table of Contents

1. [Overview - What is the swift module?](#overview)
2. [Module Description - What does the module do?](#module-description)
3. [Setup - The basics of getting started with swift](#setup)
4. [Usage - The classes, defines,functions and facts available in this module](#reference)
5. [Implementation - An under-the-hood peek at what the module is doing](#implementation)
6. [Limitations - OS compatibility, etc.](#limitations)
7. [Development - Guide for contributing to the module](#development)
8. [Contributors - Those with commits](#contributors)

Overview
--------

The swift module is a part of [OpenStack](https://git.openstack.org), an effort by the OpenStack infrastructure team to provide continuous integration testing and code review for OpenStack and OpenStack community projects as part of the core software.  The module itself is used to flexibly configure and manage the object storage service for OpenStack.

Module Description
------------------

The swift module is a thorough attempt to make Puppet capable of managing the entirety of swift.  This includes manifests to provision such things as keystone, storage backends, proxies, and the ring.  Types are shipped as part of the swift module to assist in manipulation of configuration files.  A custom service provider built around the swift-init tool is also provided as an option for enhanced swift service management. The classes in this module will deploy Swift using best practices for a typical deployment.

This module is tested in combination with other modules needed to build and leverage an entire OpenStack software stack. In addition, this module requires Puppet's [exported resources](http://docs.puppetlabs.com/puppet/3/reference/lang_exported.html).

Setup
-----

**What the swift module affects**

* [Swift](https://docs.openstack.org/swift/latest/), the object storage service for OpenStack.

### Installing swift

    puppet module install openstack/swift

### Beginning with swift

You must first setup [exported resources](http://docs.puppetlabs.com/puppet/3/reference/lang_exported.html).

To utilize the swift module's functionality you will need to declare multiple resources. This is not an exhaustive list of all the components needed, we recommend you consult and understand the [core openstack](http://docs.openstack.org) documentation.

**Defining a swift storage node**

```puppet
class { 'swift':
  swift_hash_path_suffix => 'swift_secret',
}

swift::storage::loopback { ['1', '2']:
 require => Class['swift'],
}

class { 'swift::storage::all':
  storage_local_net_ip => $ipaddress_eth0
}

@@ring_object_device { "${ipaddress_eth0}:6000/1":
  region => 1, # optional, defaults to 1
  zone   => 1,
  weight => 1,
}
@@ring_container_device { "${ipaddress_eth0}:6001/1":
  zone   => 1,
  weight => 1,
}
@@ring_account_device { "${ipaddress_eth0}:6002/1":
  zone   => 1,
  weight => 1,
}

@@ring_object_device { "${ipaddress_eth0}:6000/2":
  region => 2,
  zone   => 1,
  weight => 1,
}
@@ring_container_device { "${ipaddress_eth0}:6001/2":
  region => 2,
  zone   => 1,
  weight => 1,
}
@@ring_account_device { "${ipaddress_eth0}:6002/2":
  region => 2,
  zone   => 1,
  weight => 1,
}

Swift::Ringsync<<||>>
```

Usage
-----

### Class: swift

Class that will set up the base packages and the base /etc/swift/swift.conf

```puppet
class { 'swift': swift_hash_path_suffix => 'shared_secret', }
```

####`swift_hash_path_suffix`
The shared salt used when hashing ring mappings.

### Swift storage policies
### Define: swift::storage::policy

A defined type that is used to configure swift storage policies as defined by swift:
https://docs.openstack.org/swift/latest/overview_policies.html
It is important for the operator to have a solid understanding of storage policies so they understand which parts of this module are needed for the result they seek.

swift::storage::policy is a wrapper to a new swift type/provider called "swift_storage_policy".
Swift storage policies are found in /etc/swift/swift.conf.
ex from swift.conf:
```puppet
[storage-policy:0]
name = Policy-0
aliases = gold, silver, bronze
policy_type = replication
default = true


[storage-policy:1]
name = policy-other
aliases = a, b, c
policy_type = replication
deprecated = No
default = false
```

The swift_storage_policy provider will manage one or more storage policy sections that can be created in swift.conf.
This provider will also enforce the following rules for swift storage policies as defined by the swift project:
https://docs.openstack.org/swift/latest/overview_policies.html#configuring-policies
 - No duplicate names or aliases used across all policies.
 - There is at least one policy that is marked as the default policy.
 - Policy name/alias case/content.
 - Policy-0 specifics.
 - Deprecated and default can not be declared on the same policy.
 - Storage policy policy_type.
 - Policy indexes must be unique


#### How to add Policy-0 plus another policy to swift.conf
In this example we have an existing swift ring that is configured to store 1 replica of object data.
This existing ring will be considered "storage-policy:0".
The operator wants to add another storage policy to the cluster for a ring that will be configured to store 3 replicas of object data using 3 different storage devices.
The operator will need to first define storage-policy:0 to match what exists already, then the operator will need to define the new 3 replica storage policy called "storage-policy:1"


Using /spec/acceptance/basic_swift_spec.rb as an example:
The existing storage node and ringbuilder manifest will be:
```puppet
{
# Create storage policy 0 in swift.conf
  swift::storage::policy { '0':
    policy_name    => 'Policy-0',
    policy_aliases => 'basic, single, A',
    default_policy => true,
    policy_type    => 'replication'
  }

# Build the existing ring
  class { '::swift::ringbuilder':
    part_power     => '14',
    replicas       => '1',
    min_part_hours => 1,
   }

  swift::storage::node { '0':
    mnt_base_dir         => '/srv/node',
    weight               => 1,
    zone                 => '2',
    storage_local_net_ip => '127.0.0.1',
    require              => Swift::Storage::Loopback['2', '3', '4'] ,
  }

```


To add the new ring and storage-policy:1 to swift.conf
```puppet

 # Create storage policy 1 in swift.conf
  swift::storage::policy { '1':
    policy_name    => '3-Replica-Policy',
    policy_aliases => 'extra, triple, B',
    default_policy => false,
    deprecated     => 'No',
  }

  # Create an object ring for nodes using policy 1
  swift::ringbuilder::policy_ring { '1':
    part_power     => '18',
    replicas       => '3',
    min_part_hours => 1,
  }

  # ring_object_devices for a storage policy start with the policy id.
  # Create 3 ring_object_device starting with "1:" to be
  # added to an object-1 ring for storage policy 1.
  ring_object_device { "1:127.0.0.1:6000/2":
    zone         => 2,
    weight       => 1,
    require      => Swift::Storage::Loopback['2'],
  }
  ring_object_device { "1:127.0.0.1:6000/3":
    zone         => 2,
    weight       => 1,
    require      => Swift::Storage::Loopback['3'] ,
  }
  ring_object_device { "1:127.0.0.1:6000/4":
    zone         => 2,
    weight       => 1,
    require      => Swift::Storage::Loopback['4'] ,
  }
```

To remove any section from a storage policy, just set its value to undef.
To remove a storage policy section completely set it to ensure => absent
This will remove the section AND section header.
ex:
```puppet
  # Purge storage policy 1 entirely from swift.conf
  swift::storage::policy { '1':
    ensure         => absent,
    policy_name    => '3-Replica-Policy',
    policy_aliases => 'extra, triple, B',
    default_policy => false,
    deprecated     => 'No',
  }
```
See swift::storage::policy for additional parameters to set.
#### Storage policies and erasure code support.
Support for erasure code using storage policies is supported using swift::storage::policy.
A future change will enable the swift-object-reconstructor process that is needed for a
cluster that runs erasure code.

### Class swift::proxy

Class that installs and configures the swift proxy server.

```puppet
class { 'swift::proxy':
  account_autocreate => true,
  proxy_local_net_ip => $ipaddress_eth1,
  port               => '11211',
}
```

####`account_autocreate`
Specifies if the module should manage the automatic creation of the accounts needed for swift.  This should also be set to true if tempauth is being used.

####`proxy_local_net_ip`
This is the ip that the proxy service will bind to when it starts.

####`port`
The port for which the proxy service will bind to when it starts.

### Class swift::proxy::dlo

Configures [DLO middleware](https://docs.openstack.org/swift/latest/middleware.html#module-swift.common.middleware.dlo) for swift proxy.

```puppet
class { '::swift::proxy::dlo':
  rate_limit_after_segment    => '10',
  rate_limit_segments_per_sec => '1',
  max_get_time                => '86400'
}
```

####`rate_limit_after_segment`
Start rate-limiting DLO segment serving after the Nth segment of a segmented object.

####`rate_limit_segments_per_sec`
Once segment rate-limiting kicks in for an object, limit segments served to N per second.
0 means no rate-limiting.

####`max_get_time`
Time limit on GET requests (seconds).

### Class: swift::storage

Class that sets up all of the configuration and dependencies for swift storage server instances.

```puppet
class { 'swift::storage': storage_local_net_ip => $ipaddress_eth1, }
```

####`storage_local_net_ip`
This is the ip that the storage service will bind to when it starts.

### Class: swift::ringbuilder

A class that knows how to build swift rings.  Creates the initial ring via exported resources and rebalances the ring if it is updated.

```puppet
class { 'swift::ringbuilder':
  part_power     => '18',
  replicas       => '3',
  min_part_hours => '1',
}
```

####`part_power`
The number of partitions in the swift ring. (specified as a power of 2)

####`replicas`
The number of replicas to store.

####`min_part_hours`
Time before a partition can be moved.

### Define: swift::storage::server

Defined resource type that can be used to create a swift storage server instance.  If you keep the server names unique it is possible to create multiple swift servers on a single physical node.

This will configure an rsync server instance and a swift storage instance to
manage all the devices in the devices directory.

```puppet
swift::storage::server { '6010':
  type                 => 'object',
  devices              => '/srv/node',
  storage_local_net_ip => '127.0.0.1'
}
```

### Define: swift::storage::filter::recon
Configure the swift recon middleware on a swift:storage::server instance.
Can be configured on: account, container, object servers.

### Define: swift::storage::filter::healthcheck
Configure the swift healthcheck middleware on a swift:storage::server instance.
Can be configured on: account, container, object servers.

Declaring either the recon or healthcheck middleware in a node manifest is required when specifying the recon or healthcheck middleware in an (account|container|object)_pipeline.

example manifest:

```puppet
class { 'swift::storage::all':
  storage_local_net_ip => $swift_local_net_ip,
  account_pipeline     => ['healthcheck', 'recon', 'account-server'],
  container_pipeline   => ['healthcheck', 'recon', 'container-server'],
  object_pipeline      => ['healthcheck', 'recon', 'object-server'],
}
$rings = [
  'account',
  'object',
  'container']
swift::storage::filter::recon { $rings: }
swift::storage::filter::healthcheck { $rings: }
```

####`namevar`
The namevar/title for this type will map to the port where the server is hosted.

####`type`
The type of device, e.g. account, object, or container.

####`device`
The directory where the physical storage device will be mounted.

####`storage_local_net_ip`
This is the ip that the storage service will bind to when it starts.

### Define: swift::storage::loopback

This defined resource type was created to test swift by creating a loopback device that can be used a storage device in the absence of a dedicated block device.

It creates a partition of size [`$seek`] at basedir/[`$name`] using dd with [`$byte_size`], formats it to be an xfs filesystem which is then mounted at [`$mnt_base_dir`]/[`$name`].

Then, it creates an instance of defined class for the xfs file system that will eventually lead the mounting of the device using the swift::storage::mount define.

```puppet
swift::storage::loopback { '1':
  base_dir  => '/srv/loopback-device',
  mnt_base_dir => '/srv/node',
  byte_size => '1024',
  seek      => '25000',
}
```

####`base_dir`
The directory where the flat files will be stored that house the filesystem to be loopback mounted.

####`mnt_base_dir`
The directory where the flat files that store the filesystem to be loopback mounted are actually mounted at.

####`byte_size`
The byte size that dd uses when it creates the filesystem.

####`seek`
The size of the filesystem that will be created.  Defaults to 25000.

### Class: swift::objectexpirer
Class that will configure the swift object expirer service, for the scheduled deletion of objects.

```puppet
class { 'swift::objectexpirer': }
```

It is assumed that the object expirer service will be installed on a proxy node. On Red Hat-based distributions, if the class is included in a non-proxy node, the openstack-swift-proxy package will need to be installed.


##Swiftinit service provider

The 'swiftinit' provider is a custom provider of the service type.

"Swift services are generally managed with swift-init. the general usage is swift-init <service> <command>, where service is the swift service to manage (for example object, container, account, proxy)"
From https://docs.openstack.org/swift/latest/admin_guide.html#managing-services

This new provider is intended to improve puppet-swift deployments in the following ways:

* The default service provider for puppet-swift is to use distribution specific service providers such as systemd and upstart.  If distribution provided init scripts do not specify the full range of service commands, puppet will fall back to methods such as process name matching which is not very reliable.  For example, if you were to tail a log file with the same name as a swift process, puppet will interpret that process table match as the swift-proxy service running and fail to start the swift service.
* Minimize customer impact: Using the swiftinit service provider enables more specific and targeted control of swift services.  Swift-init provides graceful stop/start and reload/restart of swift services which will allow swift processes to finish any current requests before completely stopping the old processes.
* Specific control of services starting at boot is implemented by adding or removing
a templated init or services file. This is managed by this provider.  For EL and non Ubuntu Debian OS types, this provider will also make calls out to systemctl reload and systemctl enable/disable.
* Future use of the swiftinit provider is planned to allow for starting multiple servers using swift-init and multiple configuration files, to support a dedicated replication network.


### Using the swiftinit service provider
* To use the swiftinit service provider set "service_provider" on the supported components you have defined in your config manifest.

```puppet
  class { '::swift::storage::account':
    service_provider => 'swiftinit',
  }
  class { '::swift::storage::container':
    service_provider => 'swiftinit',
  }
  class { '::swift::storage::object':
    service_provider => 'swiftinit',
  }
  class {'::swift::objectexpirer':
    service_provider => 'swiftinit',
  }
  class { '::swift::proxy':
    service_provider => 'swiftinit',
  }
```

Moving from the default service providers to the swiftinit service provider is supported.  On the next puppet run after setting the swiftinit service provider swift services are stopped on the old provider and immediately started using swift-init.  This provides a supported upgrade path with no downtime.

The swiftinit service provider uses the following service type parameters to
manage swift services in a non standard way.

* `manifest` is used to pass in the config file the service should be
configured with. Ex `object-server.conf`
* `pattern` is used to pass in the debian/redhat osfamily specific service names as found in params.pp. Used to match names on services files as provided by distro packages.  Debian/Ubuntu service names already match names used by swift-init.

To aid with input validation to the swiftinit provider there is a defined type swift::service

### Class: swift::service

This is a wrapper defined type for the swift service providers.
It provides a centraziled location to manage and validate input for use to the default
and  swiftinit service providers.

####`namevar`
The namevar/title of swift::service must be one of the swift_init_service_names listed in swift::params.pp.
These names are parsed by the swiftinit provider to provide service management in addition to template boot files.

####`os_family_service_name`
The distribution specific service name from swift::params.  This name is passed to the default service provider.
This name is used by the swiftinit provider to match on default provider service names when moving from a default
provider to the swiftinit provider.  The swiftinit provider also uses the service_name to manage service and init files.

####`config_file_name`
The swift service configuration file name.  It must be one of the following:
object-server.conf, account-server.conf, container-server.conf, proxy-server.conf, object-expirer.conf.

####`service_ensure`
The state of the service to ensure, running or stopped.

####`enabled`
Whether the service should be enabled to start at boot.

####`service_provider`
To use the swiftinit service provider to manage swift services, set service_provider to "swiftinit".  When enable is true the provider
will populate boot files that start swift using swift-init at boot. Defaults to $::swift::params::service_provider.


### Verifying installation

This modules ships with a simple Ruby script that validates whether or not your swift cluster is functional.

The script can be run as:

`ruby $modulepath/swift/files/swift_tester.rb`

Implementation
--------------

### swift

puppet-swift is a combination of Puppet manifest and ruby code to deliver configuration and extra functionality through types and providers.

### Types

#### swift_config

The `swift_config` provider is a children of the ini_setting provider. It allows one to write an entry in the `/etc/swift/swift.conf` file.

```puppet
swift_config { 'DEFAULT/debug' :
  value => true,
}
```

This will write `debug=true` in the `[DEFAULT]` section.

##### name

Section/setting name to manage from `swift.conf`

##### value

The value of the setting to be defined.

##### secret

Whether to hide the value from Puppet logs. Defaults to `false`.

##### ensure_absent_val

If value is equal to ensure_absent_val then the resource will behave as if `ensure => absent` was specified. Defaults to `<SERVICE DEFAULT>`

#### swift_account_config

Same as `swift_config`, but path is `/etc/swift/account-server.conf`

#### swift_bench_config

Same as `swift_config`, but path is `/etc/swift/swift-bench.conf`

#### swift_container_config

Same as `swift_config`, but path is `/etc/swift/container-server.conf`

#### swift_dispersion_config

Same as `swift_config`, but path is `/etc/swift/dispersion.conf`

#### swift_object_config

Same as `swift_config`, but path is `/etc/swift/object-server.conf`

#### swift_proxy_config

Same as `swift_config`, but path is `/etc/swift/proxy-server.conf`

#### swift_container_sync_realms_config

Same as `swift_config`, but path is `/etc/swift/container-sync-realms.conf'

Use this file for specifying the allowable clusters and their information.

```puppet
swift_container_sync_realms_config { 'realm1/cluster_clustername1':
  value => 'https://host1/v1/'
}
```

Limitations
------------

* No explicit support external NAS devices (i.e. Nexenta and LFS) to offload the ring replication requirements.

Beaker-Rspec
------------

This module has beaker-rspec tests

To run:

```shell
bundle install
bundle exec rspec spec/acceptance
```

Development
-----------

Developer documentation for the entire puppet-openstack project.

* https://docs.openstack.org/puppet-openstack-guide/latest/

Contributors
------------

* https://github.com/openstack/puppet-swift/graphs/contributors

Release Notes
-------------

* https://docs.openstack.org/releasenotes/puppet-swift

Repository
----------

* https://git.openstack.org/cgit/openstack/puppet-swift

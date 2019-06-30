# Puppet-Solr module
[![Build Status](https://travis-ci.com/valentinsavenko/puppet-solr.svg?branch=master)](https://travis-ci.com/valentinsavenko/puppet-solr)

Solr module, very basic. Only tested on CentOS7 / RedHat7.

It downloads the version defined in hiera from http://archive.apache.org/dist/lucene/solr/, installs Solr following the offcial docu [here](https://lucene.apache.org/solr/guide/7_7/taking-solr-to-production.html#taking-solr-to-production) and starts Solr as a init.d Service.

For more info on design decisions check the [blog](https://valentinsavenko.github.io/puppet-module-ecosystem/) I wrote about this module.

## Setup

### Setup Requirements

This module expects Java to be present on the system e.g. 'puppetlabs-java'. The default solr version was tested with Oracle Java 1.8.

### Beginning with solr

The minimal code to make it run is simply:
```
include solr
```
It uses all the default values from hiera at [data/common.yaml](data/common.yaml)
If you need to change those, create your own hiera file and override those values.

## Usage / Reference

Check the hiera file at [data/common.yaml](data/common.yaml) for all possible inputs
The only tricky param is maybe *solr::zk_hosts*, you need to actually have Zookeeper running, for it to make sense, e.g.: 
```
  #------------------------------------------------------------------------------#
  # deric/puppet-zookeeper                                                       #
  # https://github.com/deric/puppet-zookeeper                                    #
  #------------------------------------------------------------------------------#
  class { 'zookeeper': 
    install_method  => 'archive',
    archive_dl_site => 'http://mirror.netcologne.de/apache.org/zookeeper',
    archive_version => '3.4.13',
    service_provider    => 'systemd',
    manage_service_file => true,
  }
```


    class { 'solr':
      version => '7.7.2',
      user => 'solr',
      manage_user => true,
      manage_group => true,
      group => 'solr',
      install_dir => '/soft',
      data_dir => '/data',
      service_name => 'S_solr_8983',
      memory => '-Xms2048m -Xmx2048m',
      jmx_remote => true,
      http_port => 8983,
      default_configsets => ['test'],
      slave => false,
    }


hiera with hash_map: 
```
profile::solr_hash:
  test3: |
    <!-- A request handler for the slave ---->
    <requestHandler name="/replication" class="solr.ReplicationHandler">
      <lst name="slave">
        <str name="masterUrl">http://master:8983/solr/CORENAME/replication</str>
        <str name="pollInterval">00:00:20</str>
      </lst>
    </requestHandler>
  test4: |
    <!-- A request handler for master -->
    <requestHandler name="/replication" class="solr.ReplicationHandler">
      <lst name="master">
        <str name="replicateAfter">optimize</str>
        <str name="backupAfter">optimize</str>
        <str name="confFiles">solrconfig_slave.xml:solrconfig.xml,x.xml,y.xml</str>
      </lst>
      <int name="maxNumberOfBackups">2</int>
      <lst name="invariants">
        <str name="maxWriteMBPerSec">10</str>
      </lst>
    </requestHandler>
```
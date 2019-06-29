
# Class: solr
# ===========================
#
# Full description of class solr here.
# Examples
# --------
#
# @example
#    class { 'solr':
#      version => '7.7.0',
#    }
#
# Authors
# -------
#
# Michael Strache <michael.strache@netcentric.biz>
# Valentin Savenko <valentin.savenko@netcentric.biz>
#
# Copyright
# ---------
#
# Copyright 2018 Michael Strache & Valentin Savenko, Netcentric
#

# TODO:
#   - Make download url configurable


class solr (
  String  $user,
  Boolean $manage_user,
  String  $group,
  Boolean $manage_group,
  String  $install_dir,
  String  $service_name,
  String  $version,
  String  $checksum_type = none,
  Integer $http_port,
  String  $memory,
  Boolean $jmx_remote,
  String  $data_dir,
  Array   $default_configsets,
  Boolean $slave,
  String  $master_url = none,

) {

  #------------------------------------------------------------------------------#
  # Code                                                                         #
  #------------------------------------------------------------------------------#
  # So far based on https://lucene.apache.org/solr/guide/7_1/taking-solr-to-production.html#taking-solr-to-production

  $root_instance_dir="${install_dir}/${service_name}"
  $root_data_dir="${data_dir}/${service_name}"
  $instance_dir="${install_dir}/${service_name}/solr-${$version}"
  #$instance_data_dir="${data_dir}/${service_name}"

  #################################################################
  if $manage_group {
    group { $group:
      ensure => 'present',
    }
  }

  if $manage_user {
    user { $user:
      ensure => 'present',
      gid    => $group,
    }
  }
  #################################################################


  # Download the installer archive and extract the install script
  $install_archive = "${install_dir}/solr-${$version}.tgz"

  archive { $install_archive:
    checksum_type => $checksum_type,
    checksum_url  => "http://archive.apache.org/dist/lucene/solr/${$version}/solr-${$version}.tgz.${checksum_type}",
    cleanup       => false,
    creates       => 'dummy_value', # extract every time. This is needed because archive has unexpected behaviour without it. (seems to be mandatory, instead of optional)
    extract       => true,
    extract_path  => $install_dir,
    source        => "http://archive.apache.org/dist/lucene/solr/${$version}/solr-${$version}.tgz",
  }

  #$install_archive = "${install_dir}/solr-${$version}.tar"

  #file { $install_archive:
   # ensure  => file,
   # source  => "puppet:///modules/solr/files/solr-${$version}.tar",
   #unless  => "/usr/bin/test -e ${install_dir}/${service_name}/.solr-${service_name}-${version}-installed-flag",
  #}

  #exec { 'untar-solr-${service_name}':
  # command     => '/bin/tar -xvf ${install_archive} -C ${install_dir}',
  # user        => 'solr',
  # creates     => '${install_dir}/extract.txt',
  # require     => File[$install_archive]
  #unless  => "/usr/bin/test -e ${install_dir}/${service_name}/.solr-${service_name}-${version}-installed-flag",
  #}

  # Create data/instance folder
  file { [$data_dir,$root_data_dir,$root_instance_dir]:
    ensure => 'directory',
    recurse => true,
    owner   => $user,
    group   => $group,
  }

  # Solr is extracted here
  $home_dir = "${install_dir}/solr-${$version}"

  # triggers install script as defined in the solr docu
  $install_command = "${home_dir}/bin/install_solr_service.sh ${install_archive} -n -i ${root_instance_dir} -d ${root_data_dir} -u ${user} -s ${service_name} -p ${http_port}"
  exec { "Solr install for Solr-${service_name}-${version}" :
        command => $install_command,
        timeout => 200,
        path    => '/usr/bin:/bin',
        unless  => "/usr/bin/test -e ${root_instance_dir}/.solr-${service_name}-${version}-installed-flag",
        notify  => Exec['Remove Solr install base dir'],
        require => [
          File[$root_instance_dir],
          File[$data_dir],
          Archive[$install_archive],
        ];
  }

  # Leave breadcrumbs/flags to indicate that the installation + restarts was already performed and should not be repeated next time!
  file { "Solr-${service_name}-${version} - Leave breadcrumbs to indicate that the Solr-${version} was already installed." :
    ensure  => present,
    path    => "${root_instance_dir}/.solr-${service_name}-${version}-installed-flag",
    owner   => $user,
    mode    => '0600',
    content => "This file indicates that solr was already installed in this version and doesn\'t need to be repeated on every puppet run!",
    require => [
      Exec["Solr install for Solr-${service_name}-${version}"],
    ];
  }

  # default solr config file 
  $config_file = "/etc/default/${service_name}.in.sh"

  file { $config_file:
    ensure  => present,
    path    => $config_file,
    require => [
      Exec["Solr install for Solr-${service_name}-${version}"],
    ];
  }

  if $memory {
    file_line { 'Append memory setting to the default config file for the solr service':
      notify  => Service[$service_name],
      path    => $config_file,
      line    => "SOLR_JAVA_MEM=\"${memory}\"",
      match   => '.*SOLR_JAVA_MEM=.*',
      require => File[$config_file],

    }
  }

  if $jmx_remote {
    file_line { 'Enable JMX remote':
      notify  => Service[$service_name],
      path    => $config_file,
      line    => "ENABLE_REMOTE_JMX_OPTS=\"true\"",
      match   => '.*ENABLE_REMOTE_JMX_OPTS=.*',
      require => File[$config_file],
    }
  }

each($default_configsets) |$value| {

  $file_created="${instance_dir}/server/solr/configsets/${value}"

  file { $file_created:
    ensure  => 'directory',
    path    => "${file_created}",
    recurse => true,
    source  => "${instance_dir}/server/solr/configsets/_default",
    notify  => Exec['create configsets ${value}']

  }

  exec { 'create configsets ${value}':
    command     => "${instance_dir}/bin/solr create -c $value -d $value -p $http_port -rf 3",
    user        => $user,
    refreshonly => true,
    require     => File[$file_created]
  }
  
}

  exec { "Remove Solr install base dir":
    command     => "/bin/rm -rf ${home_dir}",
    path    => '/bin/',
    user        => 'root',
    notify  => Exec['Remove Solr tar dir'],
    refreshonly => true,
  }

  exec { "Remove Solr tar dir":
    command     => "/bin/rm -rf ${install_archive}",
    path    => '/bin/',
    user        => 'root',
    refreshonly => true,
  }

  # start and enable solr service
  service { $service_name:
    ensure => running,
    enable => true,
  }

}

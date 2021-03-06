# Copyright © 2013 Diego Elio Pettenò <flameeyes@flameeyes.eu>
#
# Released under the Apache License 2.0

class gentoo::oldnet($iproute2 = true, $extra_modules = []) {
  $confd = "/etc/conf.d/net"
  concat { $confd: }

  if $iproute2 {
    package { 'sys-apps/iproute2':
      ensure => present
    }

    $modules = [ 'iproute2', $extra_modules ]
  } else {
    $modules = $extra_modules
  }

  concat::fragment { "oldnet_header":
    target => $confd,
    content => template("gentoo/oldnet.header.erb"),
    order => 01,
  }
}

define gentoo::oldnet::interface($addresses, $routes = [], $bridge = false, $bridge_interfaces = []) {
  if $bridge {
    if !defined(Package['net-misc/bridge-utils']) {
      package { 'net-misc/bridge-utils':
        ensure => present
      }
    }

    $extra_service_deps = Package['net-misc/bridge-utils']
  } else {
    $extra_service_deps = []
  }

  # these allow the user to provide a non-array through parameters.
  $all_addresses = [ $addresses ]
  $all_routes = [ $routes ]
  
  $confd = "/etc/conf.d/net"

  concat::fragment { "oldnet_${name}":
    target => $confd,
    content => template("gentoo/oldnet.interface.erb"),
    order => 10,
  }

  # This was broken in previous versions
  file { "/etc/init.d/${name}":
    ensure => absent
  }

  file { "/etc/init.d/net.${name}":
    ensure => link,
    target => "net.lo",
  }

  service { "net.${name}":
    ensure => running,
    enable => true,
    require => [ File["/etc/init.d/net.${name}"], $extra_service_deps ],
    subscribe => File[$confd],
    hasrestart => true,
  }
}

define gentoo::oldnet::ipv6tunnel($link, $remote_v4, $remote_v6, $local_v4, $local_v6, $source = '') {
  $confd = "/etc/conf.d/net"

  concat::fragment { "oldnet_${name}_ipv6tunnel":
    target => $confd,
    content => template("gentoo/oldnet.ipv6tunnel.erb"),
    order => 20,
  }

  if $source == '' {
    $src = $local_v6
  } else {
    $src = $source
  }

  gentoo::oldnet::interface { $name:
    addresses => "${local_v6}/64",
    routes => "default via ${remote_v6} src ${src}"
  }
}

define gentoo::oldnet::tuntap($type = tun, $addresses = [], $routes = []) {
  concat::fragment { "oldnet_${name}_tuntap":
    target => "/etc/conf.d/net",
    content => "tuntap_${name}=$type\n",
    order => 05
  }

  gentoo::oldnet::interface { $name:
    addresses => $addresses,
    routes => $routes,
  }
}

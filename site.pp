## site.pp ##

File { backup => false }

# DEFAULT NODE
# Node definitions in this file are merged with node data from the console. See
# http://docs.puppetlabs.com/guides/language_guide.html#nodes for more on
# node definitions.

# The default node definition matches any node lacking a more specific node
# definition. If there are no other nodes in this file, classes declared here
# will be included in every node's catalog, *in addition* to any classes
# specified in the console for that node.

node default {
  # This is where you can declare classes for all nodes.
  # Example:
  #   class { 'my_class': }

  $blog_name = 'my_blog'

  $ip = pick(
              $facts['networking'].dig('interfaces','eth1','ip'),
              $facts['networking'].dig('interfaces','enp0s8','ip')
            )

  class { 'nodejs' :
    repo_url_suffix           => '4.x',
  }
  ->
  class { 'ghost':
    include_nodejs => false,
  }
  ->
  ghost::blog { $blog_name :
    use_supervisor => false,
    host           => '0.0.0.0',
    url            => "http://${ip}",
  }

  class { 'nginx':}

  nginx::resource::upstream { "ghost_blog_${blog_name}":
    members => [
      'localhost:2368',
    ],
  }

  nginx::resource::server { $ip :
    proxy => "http://ghost_blog_${blog_name}",
  }

  #Add systemD service
  #https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-ghost-on-ubuntu-16-04
  file { '/etc/systemd/system/ghost.service' :
    ensure => file,
    content => '
[Unit]
Description=Ghost
After=network.target

[Service]
Type=simple

WorkingDirectory=/home/ghost/my_blog
User=ghost
Group=ghost

ExecStart=/usr/bin/npm start --production
ExecStop=/usr/bin/npm stop --production
Restart=always
SyslogIdentifier=Ghost

[Install]
WantedBy=multi-user.target'
  }

  service { 'ghost' :
    ensure => 'running',
    enable => true,
    require => [
                 File['/etc/systemd/system/ghost.service'],
                 Ghost::Blog[$blog_name],
               ]
  }
}

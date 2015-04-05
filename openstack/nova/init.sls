{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set qpid_host =  salt['pillar.get']('openstack:qpid_host', '127.0.0.1') %}
{% set qpid_port =  salt['pillar.get']('openstack:qpid_port', '5672') %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone:admin_password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':8774/v2/%(tenant_id)s' %}
{% set vnc_host = salt['pillar.get']('nova:vnc_host', '0.0.0.0') %}
{% set nova_password = salt['pillar.get']('nova:password', 'nova') %}
{% set netname = salt['pillar.get']('nova:netname', 'net10') %}
{% set flat_interface = salt['pillar.get']('nova:network:flat_interface_name', 'eth1') %}
{% set bridge_name = salt['pillar.get']('nova:network:bridge_name', 'br101') %}
{% set public_interface = salt['pillar.get']('nova:network:public_interface_name', 'eth0') %}
{% set home_dir = salt['pillar.get']('nova:home_dir', '/home/joe') %}
{% set key1 = salt['pillar.get']('nova:key1', '.ssh/id_rsa.pub') %}
{% set key1_name = salt['pillar.get']('nova:key1_name', 'MyKey') %}
{% set key2 = salt['pillar.get']('nova:key2', '.ssh/id_rsa2.pub') %}
{% set key2_name = salt['pillar.get']('nova:key2_name', 'MyKey2') %}
{% set key3 = salt['pillar.get']('nova:key3', '.ssh/id_rsa3.pub') %}
{% set key3_name = salt['pillar.get']('nova:key3_name', 'MyKey3') %}
{% set use_confdir = salt['pillar.get']('nova:use_confdir', False) %}

include:
  - mysql.server
  - mysql.python
  - qpid.server
  #- openstack.keystone
  #- openstack.glance
  #- epel
  #- mysql.python

nova-pkgs:
  pkg.installed:
    - names:
      - nova-api
      - nova-cert
      - nova-conductor
      - nova-consoleauth
      #
      #- nova-novncproxy
      - nova-spiceproxy
      - nova-scheduler
      - python-novaclient
      - python-qpid
      - nova-compute
      - nova-console
      - nova-network
      #- nova-objectstore
      #- nova-volume
      #- nova-api-metadata  # now included in nova-api

## stop & remove the sqlite db

nova-services-down:
  service.dead:
    - init-delay: 5
    - names:
      - nova-api
      - nova-cert
      - nova-compute
      - nova-conductor
      - nova-consoleauth
      - nova-console
      - nova-network
      - nova-scheduler
      #
      #- nova-novncproxy
      - nova-spiceproxy
      - libvirt-bin
    - require:
      - pkg: nova-pkgs

/var/lib/nova/nova.sqlite:
  file.absent:
    - require:
      - service: nova-services-down

# Nope, salt has no direct way to ensure directory is present but empty
#/var/log/nova/*:
#  file.absent:
#    - recurse: True
#    - require:
#      - service: nova-services-down
#
#/var/log/upstart/nova*:
#  file.absent:
#    - recurse: True
#    - require:
#      - service: nova-services-down

clean-logs:
  cmd.run:
    - cwd: /var/log
    - name: |
        rm -rf nova/*
        rm -rf upstart/nova*:
        rm -rf libvirt/libvirtd.lo*:
    - onlyif: grep rabbit upstart/nova*
    - require:
      - service: nova-services-down


## Create db first, then conf, then manage-db, then keystone entries

nova-db:
  mysql_database.present:
    - name: nova
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_charset: utf8
    - saltenv:
      - LC_ALL: "en_US.utf8"
    - require:
      - file: /var/lib/nova/nova.sqlite
  mysql_user.present:
    - name: nova
    - host: localhost
    - password: {{ nova_password }}
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - require:
      - file: /var/lib/nova/nova.sqlite
  mysql_grants.present:
    - grant: all privileges
    - database: nova.*
    - user: nova
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - require:
      - file: /var/lib/nova/nova.sqlite


## Conf: Put the dir there, basic conf files, and example fosskb files:

{% if use_confdir %}

/etc/nova/conf.d:
  file.recurse:
    - source: salt://openstack/nova/conf.d
    - template: jinja
    # Note: jinja templates are not currently used
    - require:
      - mysql_grants: nova-db

/etc/nova/conf.d/00-base.conf:
  file.symlink:
    - target: /etc/nova/nova.conf
    - require:
      - file: /etc/nova/conf.d

{% for conf in 'nova-api.conf',
    'nova-cert.conf',
    'nova-compute.conf',
    'nova-conductor.conf',
    'nova-console.conf',
    'nova-consoleauth.conf',
    'nova-network.conf',
    'nova-novncproxy.conf',
    'nova-scheduler.conf',
    'nova-spiceproxy.conf' %}

    # 'nova-api-metadata.conf',
    # 'nova-objectstore.conf',

/etc/init/{{ conf }}:
  file.replace:
    - pattern: '--config-file=/etc/nova/nova.conf'
    - repl: '--config-dir=/etc/nova/conf.d'

{% endfor %}

{% else %}

/etc/nova/nova.conf:
  ini.options_present:
    - sections:
        DEFAULT:
          #debug: True
          verbose: True
          logdir: /var/log/nova
          state_path: /var/lib/nova
          lock_path: /var/lock/nova

          # LIBVIRT
          connection_type: libvirt
          libvirt_use_virtio_for_bridges: True

          # MISC
          ec2_private_dns_show_ip: True
          api_paste_config: /etc/nova/api-paste.ini
          enabled_apis: ec2,osapi_compute,metadata

          # QPID
          rpc_backend: qpid
          qpid_hostname: {{ qpid_host }}
          qpid_tcp_nodelay: True

          # WORKERS
          metadata_workers: 3
          osapi_compute_workers: 3
          ec2_workers: 3

          # AUTH
          auth_strategy: keystone

          # IPs, VNC, Spice, Glance
          my_ip: {{ bind_host }}
          #
          vnc_enabled: False
          #vnc_port: 5900
          vncserver_listen: {{ vnc_host }}
          vncserver_proxyclient_address: {{ vnc_host }}
          novncproxy_base_url: http://{{ vnc_host }}:6080/vnc_auto.html
          #
          spicehtml5proxy_host: {{ vnc_host }}
          spicehtml5proxy_port: 6082
          glance_host: {{ bind_host }}
          remove_unused_base_images: True

          # JJW Networking & DHCP, 3/31/15
          #network_api_class: nova.network.api.API
          #security_group_api: nova
          network_size: 254
          network_manager: nova.network.manager.FlatDHCPManager
          #network_manager: nova.network.manager.FlatManager
          firewall_driver: nova.virt.libvirt.firewall.IptablesFirewallDriver
          #firewall_driver: nova.virt.firewall.NoopFirewallDriver
          allow_same_net_traffic: True
          multi_host: False
          share_dhcp_address: True
          force_dhcp_release: True
          # for flatDHCP:
          flat_interface: {{ flat_interface }}
          flat_network_bridge: {{ bridge_name }}
          flat_injected: True
          public_interface: {{ public_interface }}
          #fixed_range: 10.1.4.0/24
          dhcpbridge_flagfile: /etc/nova/nova.conf
          dhcpbridge: /usr/bin/nova-dhcpbridge

        conductor:
          workers: 3

        database:
          #connection: {{ salt['pillar.get']('keystone:sql:connection', 'mysql://keystone:keystone@localhost/keystone') }}
          connection: mysql://nova:{{ nova_password }}@{{ bind_host }}/nova

        #rdp:
        #  enabled: True
        #  html5_proxy_base_url: http://{{ vnc_host }}:6083/

        #
        spice:
          agent_enabled: True
          enabled: True
          html5proxy_base_url: http://{{ vnc_host }}:6082/spice_auto.html
          server_listen: {{ vnc_host }}
          server_proxyclient_address: {{ vnc_host }}

        keystone_authtoken:
          auth_uri: http://{{ bind_host }}:5000
          auth_host: {{ bind_host }}
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: nova
          admin_password: {{ nova_password }}
    - backupname: .bak
    - require:
      - mysql_grants: nova-db

/etc/libvirt/libvirtd.conf:
  ini.options_present:
    - sections:
        DEFAULT_IMPLICIT:
          listen_addr: '"127.0.0.1"'
          log_level: 1
          log_buffer_size: 0

{% endif %}

nova-manage:
  cmd.run:
      {% if use_confdir %}
    - name: nova-manage --config-dir /etc/nova/conf.d db sync
      {% else %}
    - name: nova-manage db sync
      {% endif %}
    - unless: mysql --password={{ mysql_root_password }} nova -e 'show tables;' |grep instance
    - require:
      {% if use_confdir %}
      - file: /etc/nova/conf.d/00-base.conf
      {% else %}
      - ini: /etc/nova/nova.conf
      {% endif %}

nova-keystone-user:
  keystone.user_present:
    - name: nova
    - password: {{ salt.pillar.get ('nova:password', 'nova') }}
    #- password: {{ salt['pillar.get']('keystone:nova_password', 'nova') }}
    - email: {{ salt['pillar.get']('keystone:nova_email', 'joe@eracks.com') }}
    - roles:
      - service:
        - admin
    - require:
      - cmd: nova-manage

nova-keystone-service:
  keystone.service_present:
    - name: nova
    - service_type: compute
    - description: OpenStack Compute
    - require:
      - keystone: nova-keystone-user

nova-keystone-endpoint:
  keystone.endpoint_present:
    - name: nova
    - region: regionOne
    - publicurl: {{ public_url }}
    - internalurl: {{ public_url }}
    - adminurl: {{ public_url }}
    - require:
      - keystone: nova-keystone-service

nova-support:
  service:
    - running
    - enable: True
    - init-delay: 3
    - names:
      - mysql
      - qpidd
      - libvirt-bin
      - dbus
    - require:
      - keystone: nova-keystone-service

nova-services-up:
  service:
    - running
    - enable: True
    - init-delay: 3
    - names:
      - nova-api
      - nova-cert
      - nova-compute
      - nova-conductor
      - nova-consoleauth
      - nova-console
      - nova-network
      - nova-scheduler
      #
      #- nova-novncproxy
      - nova-spiceproxy
      #- nova-objectstore
      #- nova-volume
      #- nova-api-metadata
    - require:
      - service: nova-support

nova-network-setup:
  cmd:
    - run
    - cwd: {{ home_dir }}
    - name: |
        source ostack-creds.source
        #export netname=net10
        {% if use_confdir %}
        echo nova-manage --config-dir /etc/nova/conf.d network create --fixed_range_v4 10.1.4.0/24 --network_size 254 --bridge {{ bridge_name }} --bridge_interface {{ flat_interface }} {{ netname }}
        nova-manage --config-dir /etc/nova/conf.d network create --fixed_range_v4 10.1.4.0/24 --network_size 254 --bridge {{ bridge_name }} --bridge_interface {{ flat_interface }} {{ netname }}
        {% else %}
        echo nova-manage network create --fixed_range_v4 10.1.4.0/24 --network_size 254 --bridge {{ bridge_name }} --bridge_interface {{ flat_interface }} {{ netname }}
        nova-manage network create --fixed_range_v4 10.1.4.0/24 --network_size 254 --bridge {{ bridge_name }} --bridge_interface {{ flat_interface }} {{ netname }}
        {% endif %}
        export netid=$(nova net-list | grep {{ netname }} | awk '{print $2}')
        echo nova network-associate-host $netid openstack14
        nova network-associate-host $netid openstack14
        #for i in {129..136}; do nova-manage floating create --ip_range 216.172.133.$i --pool=nova; done
    - unless: source ostack-creds.source && nova net-list | grep {{ netname }}
    - require:
      - service: nova-services-up

nova-keypair-setup:
  cmd:
    - run
    - cwd: {{ home_dir }}
    - name: |
        source ostack-creds.source
        echo nova keypair-add --pub-key {{ key1 }} {{ key1_name }}
        nova keypair-add --pub-key {{ key1 }} {{ key1_name }}
        echo nova keypair-add --pub-key {{ key2 }} {{ key2_name }}
        nova keypair-add --pub-key {{ key2 }} {{ key2_name }}
        echo nova keypair-add --pub-key {{ key3 }} {{ key3_name }}
        nova keypair-add --pub-key {{ key3 }} {{ key3_name }}
    - unless: source ostack-creds.source && nova keypair-list | grep {{ key1_name }}
    - require:
      - service: nova-services-up

nova-default-security-setup:
  cmd:
    - run
    - cwd: {{ home_dir }}
    - name: |
        source ostack-creds.source
        echo nova secgroup-add-default-rule icmp 0 0 0.0.0.0/0
        nova secgroup-add-default-rule icmp 0 0 0.0.0.0/0
        echo nova secgroup-add-default-rule udp 1 65535 0.0.0.0/0
        nova secgroup-add-default-rule udp 1 65535 0.0.0.0/0
        echo nova secgroup-add-default-rule tcp 1 65535 0.0.0.0/0
        nova secgroup-add-default-rule tcp 1 65535 0.0.0.0/0
    - unless: source ostack-creds.source && nova secgroup-list-default-rules | grep tcp
    - require:
      - service: nova-services-up

nova-boot-first-vm:
  cmd:
    - run
    - cwd: {{ home_dir }}
    - name: |
        source ostack-creds.source
        export netid=$(nova net-list | grep {{ netname }} | awk '{print $2}')
        echo using network {{ netname }} : $netid
        echo nova boot --flavor m1.small --image trusty --key-name joe-openstack14 --key-name mintstudio-maya --nic net-id=$netid,v4-fixed-ip=10.1.4.2 --user-data=cloud16.yaml --config-drive true trust2
        nova boot --flavor m1.small --image trusty --key-name joe-openstack14 --key-name mintstudio-maya --nic net-id=$netid,v4-fixed-ip=10.1.4.2 --user-data=cloud16.yaml --config-drive true trust2
    - unless: source ostack-creds.source && nova list| grep trust2
    - require:
      - service: nova-services-up

#nova-db-init:
#  cmd:
#    - run
#    - name: openstack-db --init --service nova --rootpw '{{ mysql_root_password }}'
#    - unless: echo '' | mysql nova --password='{{ mysql_root_password }}'
#    - require:
#      - pkg: openstack-nova
#      - ini: /etc/nova/nova.conf
#      - service: nova-support

#nova-keystone-creates:
#  cmd:
#    - run
#    - name: |
#        export OS_USERNAME=admin
#        export OS_PASSWORD={{ admin_password }}
#        export OS_AUTH_URL={{ admin_url }}
#        export OS_TENANT_NAME=admin
#        keystone user-create --name=nova --pass={{ salt['pillar.get']('keystone:nova_password', 'nova') }} --email={{ salt['pillar.get']('keystone:nova_email', 'joe@eracks.com') }}
#        keystone user-role-add --user=nova --tenant=service --role=admin
#        #keystone user-role-add --user=nova --tenant=service --role=admin
#        keystone service-create --name=nova --type=compute --description="OpenStack Compute"
#        keystone endpoint-create --service=nova --publicurl='{{ public_url }}' --internalurl='{{ public_url }}' --adminurl='{{ public_url }}'
#    - unless: keystone --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service compute
#    - require:
#      - pkg: openstack-nova
#      - ini: /etc/nova/nova.conf
#      - service: keystone-service


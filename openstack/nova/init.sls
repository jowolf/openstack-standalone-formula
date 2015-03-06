{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone:admin_password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':8774/v2/%(tenant_id)s' %}
{% set vnc_host = salt['pillar.get']('nova:vnc_host', '0.0.0.0') %}
{% set nova_password = salt['pillar.get']('nova:password', 'nova') %}


include:
  #- epel
  - mysql.server
  - mysql.python
  - qpid.server
  - openstack.keystone
  - openstack.glance

openstack-nova:
  pkg.installed:
    - names:
      - nova-api
      - nova-cert 
      - nova-conductor 
      - nova-consoleauth 
      - nova-novncproxy 
      - nova-spiceproxy 
      - nova-scheduler 
      - python-novaclient 
      #- python-mysqldb
      - python-qpid
      - nova-compute 
      - nova-console
      #- nova-volume
      - nova-network
      #- nova-api-metadata  # now included in nova-api
      - nova-objectstore

/etc/nova/nova.conf:
  ini.options_present:
    - sections:
        DEFAULT:
          # rabbit, fm fosskb: http://fosskb.wordpress.com/2014/10/18/openstack-juno-on-ubuntu-14-10/
          #rpc_backend = nova.rpc.impl_kombu
          #rabbit_host = 127.0.0.1
          #rabbit_password = rabbit

          rpc_backend: qpid
          qpid_hostname: localhost
          qpid_tcp_nodelay: True
          auth_strategy: keystone

          my_ip: {{ bind_host }}
          vncserver_listen: {{ vnc_host }}
          #vncserver_proxyclient_address: {{ vnc_host }}
          novncproxy_base_url: http://{{ vnc_host }}:6080/vnc_auto.html
          glance_host: {{ bind_host }}

          remove_unused_base_images: True
          # for controller node and compute node nova-network:
          network_api_class: nova.network.api.API
          security_group_api: nova
          # for compute node nova-network:
          firewall_driver: nova.virt.libvirt.firewall.IptablesFirewallDriver
          network_manager: nova.network.manager.FlatDHCPManager
          #network_size: 254

          # Neutron stuff from fosskb:
          #network_api_class=nova.network.neutronv2.api.API
          #neutron_url=http://10.0.0.1:9696
          #neutron_auth_strategy=keystone
          #neutron_admin_tenant_name=service
          #neutron_admin_username=neutron
          #neutron_admin_password=neutron_pass
          #neutron_metadata_proxy_shared_secret=openstack
          #neutron_admin_auth_url=http://10.0.0.1:35357/v2.0
          #linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
          #firewall_driver=nova.virt.firewall.NoopFirewallDriver
          #security_group_api=neutron

          # Also from fosskb:
          #iscsi_helper=tgtadm
          #connection_type=libvirt
          #root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf

          #vif_plugging_is_fatal: false
          #vif_plugging_timeout: 0

          # Old, from Salt Grizzly or Icehouse:
          #allow_same_net_traffic = False
          #multi_host = False
          #send_arp_for_ha = True
          #share_dhcp_address = True
          #force_dhcp_release = True
          #flat_network_bridge = br100
          #flat_interface = {{ salt['pillar.get']('nova:network:interface_name', 'eth0') }}
          #public_interface = {{ salt['pillar.get']('nova:network:interface_name', 'eth0') }}

        database:
          #connection: {{ salt['pillar.get']('keystone:sql:connection', 'mysql://keystone:keystone@localhost/keystone') }}
          connection: mysql://nova:{{ nova_password }}@{{ bind_host }}/nova

        keystone_authtoken:
          auth_uri: http://{{ bind_host }}:5000
          auth_host: {{ bind_host }}
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: nova
          admin_password: {{ nova_password }}
    - require:
      - pkg: openstack-nova
    - backupname: .bak


#/etc/nova/nova.conf:
#  file.append:
#    - text: |
#        rpc_backend = qpid
#        qpid_hostname = localhost
#        qpid_tcp_nodelay = True
#        auth_strategy = keystone
#        remove_unused_base_images = True
#        # for controller node and compute node nova-network:
#        network_api_class = nova.network.api.API
#        security_group_api = nova
#        # for compute node nova-network:
#        firewall_driver = nova.virt.libvirt.firewall.IptablesFirewallDriver
#        network_manager = nova.network.manager.FlatDHCPManager
#        network_size = 254
#        allow_same_net_traffic = False
#        multi_host = False
#        send_arp_for_ha = True
#        share_dhcp_address = True
#        force_dhcp_release = True
#        flat_network_bridge = br100
#        flat_interface = {{ salt['pillar.get']('nova:network:interface_name', 'eth0') }}
#        public_interface = {{ salt['pillar.get']('nova:network:interface_name', 'eth0') }}
#
#        [keystone_authtoken]
#        #auth_uri = http://127.0.0.1:5000
#        #auth_host = 127.0.0.1
#        #auth_port = 35357
#        #auth_protocol = http
#        #admin_tenant_name = service
#        #admin_user = nova
#        #admin_password = nova
#        #service_protocol = {{ salt['pillar.get']('nova:filter_authtoken:service_protocol', 'http') }}
#        #service_host = {{ salt['pillar.get']('nova:filter_authtoken:service_host', '127.0.0.1') }}
#        #service_port = {{ salt['pillar.get']('nova:filter_authtoken:service_port', '5000') }}
#        auth_uri = {{ salt['pillar.get']('nova:filter_authtoken:auth_uri', 'http://127.0.0.1:5000/') }}
#        auth_host = {{ salt['pillar.get']('nova:filter_authtoken:auth_host', '127.0.0.1') }}
#        auth_port = {{ salt['pillar.get']('nova:filter_authtoken:auth_port', '35357') }}
#        auth_protocol = {{ salt['pillar.get']('nova:filter_authtoken:auth_protocol', 'http') }}
#        admin_tenant_name = {{ salt['pillar.get']('nova:filter_authtoken:admin_tenant_name', 'service') }}
#        admin_user = {{ salt['pillar.get']('nova:filter_authtoken:admin_user', 'nova') }}
#        admin_password = {{ salt['pillar.get']('nova:filter_authtoken:admin_password', 'nova') }}
#
#    - template: jinja
#    - backups: minion
#    - require:
#      - pkg: openstack-nova
#    - watch_in:
#      - service: nova-services


nova-support:
  service:
    - running
    - enable: True
    - names:
      - mysql
      - qpidd
      - libvirt-bin
      - dbus

nova-services:
  service:
    - running
    - enable: True
    - names:
      - nova-api
      - nova-objectstore
      - nova-compute
      - nova-network
      #- nova-volume
      - nova-scheduler
      - nova-cert
      - nova-api-metadata
      - nova-novncproxy
      - nova-spiceproxy
    #- watch:
      #- cmd: nova-db-init
      #- cmd: keystone-db-init
      #- service: glance-services
    - require:
      - service: nova-support
      - ini: /etc/nova/nova.conf


nova-db-init:
  cmd:
    - run
    - name: openstack-db --init --service nova --rootpw '{{ mysql_root_password }}'
    - unless: echo '' | mysql nova --password='{{ mysql_root_password }}'
    - require:
      - pkg: openstack-nova
      - ini: /etc/nova/nova.conf
      - service: nova-support

nova-keystone-creates:
  cmd:
    - run
    - name: |
        export OS_USERNAME=admin
        export OS_PASSWORD={{ admin_password }}
        export OS_AUTH_URL={{ admin_url }}
        export OS_TENANT_NAME=admin
        keystone user-create --name=nova --pass={{ salt['pillar.get']('keystone:nova_password', 'nova') }} --email={{ salt['pillar.get']('keystone:nova_email', 'joe@eracks.com') }}
        keystone user-role-add --user=nova --tenant=service --role=admin
        #keystone user-role-add --user=nova --tenant=service --role=admin
        keystone service-create --name=nova --type=compute --description="OpenStack Compute"
        keystone endpoint-create --service=nova --publicurl='{{ public_url }}' --internalurl='{{ public_url }}' --adminurl='{{ public_url }}'
    - unless: keystone --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service compute
    - require:
      - pkg: openstack-nova
      - ini: /etc/nova/nova.conf
      - service: keystone-service



# JJW this is the wrong approach, blasting all the existing package-manager supplied files..
# need ini_manage - in the meantime, comment out
#
#/etc/nova:
#  file:
#    - recurse
#    - source: salt://openstack/nova/files
#    - template: jinja
#    - require:
#      - pkg: openstack-nova
#    - watch_in:
#      - service: nova-services


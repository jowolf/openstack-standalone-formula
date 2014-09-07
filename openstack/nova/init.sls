{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone:admin_password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':8774/v2/%(tenant_id)s' %}

include:
  #- epel
  - mysql.server
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
      - nova-scheduler 
      - python-novaclient 
      - python-mysqldb
      - python-qpid
      - nova-compute 
      - nova-console
      #- nova-volume
      - nova-network
      - nova-objectstore


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
        keystone service-create --name=nova --type=compute --description="OpenStack Compute"
        keystone endpoint-create --service=nova --publicurl={{ public_url }} --internalurl={{ public_url }} --adminurl={{ public_url }}
    - unless: keystone --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service compute
    - require:
      - pkg: openstack-glance
      - service: mysqld

nova-support:
  service:
    - running
    - enable: True
    - names:
      - mysql
      - qpidd
      - libvirt-bin
      - dbus

nova-db-init:
  cmd:
    - run
    - name: openstack-db --init --service nova --rootpw '{{ mysql_root_password }}'
    - unless: echo '' | mysql nova --password='{{ mysql_root_password }}'
    - require:
      - pkg: openstack-nova
      - service: mysql

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
    - watch:
      - cmd: nova-db-init
      - cmd: keystone-db-init
      - service: glance-services

/etc/nova:
  file:
    - recurse
    - source: salt://openstack/nova/files
    - template: jinja
    - require:
      - pkg: openstack-nova
    - watch_in:
      - service: nova-services

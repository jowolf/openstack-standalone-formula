{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}

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
      - nova-compute 
      - nova-console
      #- nova-volume
      - nova-network
      - nova-objectstore


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
      - nova-volume
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

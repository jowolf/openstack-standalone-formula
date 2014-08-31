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


nova-support:
  service:
    - running
    - enable: True
    - names:
      - mysqld
      - qpidd
      - libvirtd
      - messagebus

nova-db-init:
  cmd:
    - run
    - name: openstack-db --init --service nova --rootpw ''
    - unless: echo '' | mysql nova
    - require:
      - pkg: openstack-nova
      - service: mysqld

nova-services:
  service:
    - running
    - enable: True
    - names:
      - openstack-nova-api
      - openstack-nova-objectstore
      - openstack-nova-compute
      - openstack-nova-network
      - openstack-nova-volume
      - openstack-nova-scheduler
      - openstack-nova-cert
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

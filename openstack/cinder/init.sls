{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set qpid_host =  salt['pillar.get']('openstack:qpid_host', '127.0.0.1') %}
{% set qpid_port =  salt['pillar.get']('openstack:qpid_port', '5672') %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone.password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':9292' %}
{% set cinder_email = salt['pillar.get']('keystone:cinder_email', 'joe@eracks.com') %}
{% set cinder_password = salt['pillar.get']('keystone:cinder_password', 'cinder') %}
{% set cinder_vg = salt['pillar.get']('cinder:volume_group', 'cinder_volumes') %}

include:
  - mysql.server
  - qpid.server
  #- openstack.keystone


# do we need this, if we're using ceph? JJW
#include:
#  - iscsi

cinder-pkgs:
  pkg.installed:
    - pkgs:
        - cinder-api
        - cinder-scheduler
        - cinder-volume
        - lvm2
        - open-iscsi-utils
        - open-iscsi
        - iscsitarget
        - sysfsutils

cinder-services-down:
  service.dead:
    - init-delay: 2
    - names:
      - cinder-volume
      - cinder-api
      - cinder-scheduler
      - tgt
    - require:
      - pkg: cinder-pkgs

/var/lib/cinder/cinder.sqlite:
  file.absent:
    - require:
      - service: cinder-services-down


## Now put the dir there, and example fosskb files:

/etc/cinder/conf.d:
  file.recurse:
    - source: salt://openstack/cinder/conf.d
    - template: jinja
    - require:
      - service: cinder-services-down

/etc/cinder/conf.d/00-base.conf:
  file.symlink:
    - target: /etc/cinder/cinder.conf
    - require:
      - file: /etc/cinder/conf.d

/etc/cinder/conf.d/01-fromsalt.conf-present:
  file.touch:
    - name: /etc/cinder/conf.d/01-fromsalt.conf
    - require:
      - file: /etc/cinder/conf.d

/etc/cinder/conf.d/01-fromsalt.conf:
  ini.options_present:
    - sections:
        DEFAULT:
          #rpc_backend = cinder.openstack.common.rpc.impl_kombu
          #rabbit_host = 127.0.0.1
          #rabbit_port = 5672
          #rabbit_userid = guest
          #rabbit_password = rabbit
          glance_host: {{ bind_host }}
          osapi_volume_workers: 3
          rpc_backend: qpid
          qpid_hostname: " {{ qpid_host }}"
          qpid_port: " {{ qpid_port }}"
          volume_group: {{ cinder_vg }}
          verbose: True
          my_ip: 127.0.0.1
        database:
          connection: mysql://cinder:{{ cinder_password }}@{{ bind_host }}/cinder
        keystone_authtoken:
          admin_tenant_name: service
          admin_user: cinder
          admin_password: {{ cinder_password }}
          auth_host: {{ bind_host }}
          auth_port: {{ salt['pillar.get']('cinder:auth_port', '35357') }}
          auth_protocol: {{ salt['pillar.get']('cinder:auth_protocol', 'http') }}
          auth_uri: http://{{ bind_host }}:5000
          #/v2.0
          #signing_dirname: {{ salt['pillar.get']('cinder:signing_dirname', '/tmp/keystone-signing-cinder') }}
    - require:
      - file: /etc/cinder/conf.d


## Create db first, & manage db dync, then keystone, then pvcreate, vgcreate, services start

cinder-db:
  mysql_database.present:
    - name: cinder
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_charset: utf8
    - saltenv:
      - LC_ALL: "en_US.utf8"
  mysql_user.present:
    - name: cinder
    - host: localhost
    - password: {{ cinder_password }}
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
  mysql_grants.present:
    - grant: all privileges
    - database: cinder.*
    - user: cinder
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - require:
      - ini: /etc/cinder/conf.d/01-fromsalt.conf

cinder-manage:
  cmd.run:
    - name: cinder-manage --config-dir /etc/cinder/conf.d db sync
    - unless: mysql --password={{ mysql_root_password }} cinder -e 'show tables;' |grep volumes
    - require:
      - mysql_grants: cinder-db

cinder-keystone-user:
  keystone.user_present:
    - name: cinder
    - password: {{ salt.pillar.get ('cinder:password', 'cinder') }}
    - email: joe@eracks.com
    - roles:
      - service:
        - admin
    #- require:
    #  - keystone: Keystone tenants
    #  - keystone: Keystone roles
    - require:
      - cmd: cinder-manage

cinder-keystone-service:
  keystone.service_present:
    - name: cinder
    - service_type: volume
    - description: OpenStack Block Storage
    - require:
      - keystone: cinder-keystone-user

cinder-keystone-endpoint:
  keystone.endpoint_present:
    - name: cinder
    - region: regionOne
    - publicurl: http://{{ bind_host }}:8776/v1/%(tenant_id)s
    - internalurl: http://{{ bind_host }}:8776/v1/%(tenant_id)s
    - adminurl: http://{{ bind_host }}:8776/v1/%(tenant_id)s
    #...
    #keystone user-create --name=cinder --pass=cinder_pass --email=cinder@example.com
    #keystone user-role-add --user=cinder --tenant=service --role=admin
    #keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
    #keystone endpoint-create --service=cinder --publicurl=http://10.0.0.1:8776/v1/%\(tenant_id\)s --internalurl=http://10.0.0.1:8776/v1/%\(tenant_id\)s --adminurl=http://10.0.0.1:8776/v1/%\(tenant_id\)s
    #keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
    #keystone endpoint-create --service=cinderv2 --publicurl=http://10.0.0.1:8776/v2/%\(tenant_id\)s --internalurl=http://10.0.0.1:8776/v2/%\(tenant_id\)s --adminurl=http://10.0.0.1:8776/v2/%\(tenant_id\)
    - require:
      - keystone: cinder-keystone-service

cinder2-keystone-service:
  keystone.service_present:
    - name: cinderv2
    - service_type: volume2
    - description: OpenStack Block Storage v2
    - require:
      - keystone: cinder-keystone-endpoint

cinder2-keystone-endpoint:
  keystone.endpoint_present:
    - name: cinderv2
    - region: regionOne
    - publicurl: http://{{ bind_host }}:8776/v2/%(tenant_id)s
    - internalurl: http://{{ bind_host }}:8776/v2/%(tenant_id)s
    - adminurl: http://{{ bind_host }}:8776/v2/%(tenant_id)s
    - require:
      - keystone: cinder2-keystone-service

/etc/init/cinder-api.conf:
  file.replace:
    - pattern: '--config-file=/etc/cinder/cinder.conf'
    - repl: '--config-dir=/etc/cinder/conf.d'
    - require:
      - keystone: cinder2-keystone-endpoint

/etc/init/cinder-scheduler.conf:
  file.replace:
    - pattern: '--config-file=/etc/cinder/cinder.conf'
    - repl: '--config-dir=/etc/cinder/conf.d'

/etc/init/cinder-volume.conf:
  file.replace:
    - pattern: '--config-file=/etc/cinder/cinder.conf'
    - repl: '--config-dir=/etc/cinder/conf.d'

/etc/lvm/lvm.conf:
  file.replace:
    - pattern: 'filter = [ "a/.*/" ]'
    - repl: 'filter = [ "a/sda/", "a/sdb/", "r/.*/"]'

cinder-services-up:
  service.running:
    - enable: True
    - init-delay: 3
    - names:
      - cinder-volume
      - cinder-api
      - cinder-scheduler
      - tgt
    - require:
      - file: /etc/init/cinder-api.conf
      - file: /etc/init/cinder-scheduler.conf
      - file: /etc/init/cinder-volume.conf
      - file: /etc/lvm/lvm.conf
      - keystone: cinder2-keystone-endpoint

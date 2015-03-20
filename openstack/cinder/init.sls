{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone:admin_password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':9292' %}
{% set cinder_email = salt['pillar.get']('keystone:cinder_email', 'joe@eracks.com') %}
{% set cinder_password = salt['pillar.get']('keystone:cinder_password', 'cinder') %}
{% set qpid_host =  salt['pillar.get']('cinder:qpid_hostname', 'localhost') %}

include:
  - mysql.server
  - qpid.server


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


# Put the dir there, and example fosskb files:
/etc/cinder/conf.d:
  file.recurse:
    - source: salt://openstack/cinder/conf.d
    - template: jinja
    #- watch_in:
    #  - service: tgt

/etc/cinder/conf.d/00-base.conf:
  file.symlink:
    - target: /etc/cinder/cinder.conf

/etc/cinder/conf.d/01-fromsalt.conf-present:
  file.touch:
    - name: /etc/cinder/conf.d/01-fromsalt.conf

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
          qpid_hostname: {{ qpid_host }}
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
      #- pkg: cinder-pkgs
      - file: /etc/cinder/conf.d


# create db first, & manage-db, then keystone, then conf - 
# then manage db sync, pvcreate, vgcreate, services restart

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
      #mysql -u root -p
      #mysql> CREATE DATABASE cinder;
      #mysql> GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'cinder_dbpass';
      #quit;
    - require:
      - pkg: cinder-pkgs
      #- ini: /etc/cinder/cinder.conf.d/

cinder-manage:
  cmd.run:
    - name: cinder-manage db sync
    - unless: mysql --password={{ mysql_root_password }} cinder -e 'show tables;' |grep volumes
    - require:
      - mysql_database: cinder-db

    #- watch:
      #- pkg: cinder-pkgs
    # - mysql_grants: cinder-db
      #- file: /etc/cinder/cinder.conf

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
    - publicurl: http://{{ bind_host }}:8776/v2/%\(tenant_id\)s
    - internalurl: http://{{ bind_host }}:8776/v2/%\(tenant_id\)s
    - adminurl: http://{{ bind_host }}:8776/v2/%\(tenant_id\)s
    - require:
      - keystone: cinder2-keystone-service

/etc/init/cinder-api.conf:
  file.replace:
    - pattern: '--config-file=/etc/cinder/cinder.conf'
    - repl: '--config-dir=/etc/cinder/conf.d'

/etc/init/cinder-scheduler.conf:
  file.replace:
    - pattern: '--config-file=/etc/cinder/cinder.conf'
    - repl: '--config-dir=/etc/cinder/conf.d'

/etc/init/cinder-volume.conf:
  file.replace:
    - pattern: '--config-file=/etc/cinder/cinder.conf'
    - repl: '--config-dir=/etc/cinder/conf.d'

cinder-services:
  service.running:
    - names:
      - cinder-volume
      - cinder-api
      - cinder-scheduler
      - tgt
    - require:
      - file: /etc/init/cinder-api.conf
      - file: /etc/init/cinder-scheduler.conf
      - file: /etc/init/cinder-volume.conf
      - keystone: cinder2-keystone-endpoint

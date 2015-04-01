{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set qpid_host =  salt['pillar.get']('openstack:qpid_host', '127.0.0.1') %}
{% set qpid_port =  salt['pillar.get']('openstack:qpid_port', '5672') %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone.password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':9292' %}
{% set glance_email = salt['pillar.get']('keystone:glance_email', 'joe@eracks.com') %}
{% set glance_password = salt['pillar.get']('keystone:glance_password', 'glance') %}

include:
  - mysql.server
  - qpid.server

glance-pkgs:
  pkg:
    - name: glance
    - installed

glance-services-down:
  service.dead:
    - init-delay: 2
    - names:
      - glance-api
      - glance-registry
    - require:
      - pkg: glance-pkgs

{% for theid in 'glance-api.conf', 'glance-registry.conf' %}

etc-{{ theid }}-conf-absent:
  ini.options_absent:
    - name: /etc/glance/{{ theid }}
    - sections:
        database:
          - sqlite_db
    - require:
      - service: glance-services-down

etc-{{ theid }}-conf-present:
  ini.options_present:
    - name: /etc/glance/{{ theid }}
    #- names:
    #  - /etc/glance/glance-api.conf
    #  - /etc/glance/glance-registry.conf
    - sections:
        DEFAULT:
          rpc_backend: qpid
          qpid_hostname: {{ qpid_host }}
          workers: 3
        database:
          #connection:   {{ salt['pillar.get']('keystone:sql:connection', 'mysql://keystone:keystone@localhost/keystone') }}
          connection: mysql://glance:{{ glance_password }}@{{ bind_host }}/glance
        keystone_authtoken:
          auth_uri: http://{{ bind_host }}:5000/v2.0
          identity_uri: http://{{ bind_host}}:35357
          admin_tenant_name: service
          admin_user: glance
          admin_password: {{ glance_password }}
        paste_deploy:
          flavor: keystone
    - backupname: .bak
    - require:
      - service: glance-services-down

{% endfor %}

#glance-db-init:
#  cmd:
#    - run
#    # if it fails, run it again; that's what the or (||) is for:
#    - name: openstack-db --init --service glance --rootpw '{{ mysql_root_password }}' || openstack-db --init --service glance --rootpw '{{ mysql_root_password }}'
#    - unless: echo '' | mysql glance --password='{{ mysql_root_password }}'
#    - require:
#      #- pkg: openstack-glance
#      - service: mysqld
#      - service: glance-services

glance-db:
  mysql_database.present:
    - name: glance
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_charset: utf8
    - saltenv:
      - LC_ALL: "en_US.utf8"
  mysql_user.present:
    - name: glance
    - host: localhost
    - password: {{ glance_password }}
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
  mysql_grants.present:
    - grant: all privileges
    - database: glance.*
    - user: glance
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - require:
      - ini: etc-glance-api.conf-conf-present
      - ini: etc-glance-registry.conf-conf-present

glance-manage:
  cmd.run:
    - name: glance-manage db sync
    - unless: mysql --password={{ mysql_root_password }} glance -e 'show tables;' |grep volumes
    - require:
      - mysql_grants: glance-db

glance-keystone-creates:
  cmd:
    - run
    - name: |
        export OS_USERNAME=admin
        export OS_PASSWORD={{ admin_password }}
        export OS_AUTH_URL={{ admin_url }}
        export OS_TENANT_NAME=admin
        keystone user-create --name=glance --pass={{ glance_password }} --email={{ glance_email }}
        keystone user-role-add --user=glance --tenant=service --role=admin
        keystone service-create --name=glance --type=image --description="Glance Image Service"
        keystone endpoint-create --service=glance --publicurl={{ public_url }} --internalurl={{ public_url }} --adminurl={{ public_url }}
    - unless: keystone --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service image
    #- unless: unset OS_SERVICE_TOKEN; unset OS_SERVICE_ENDPOINT; unset OS_ENDPOINT; unset SERVICE_TOKEN; env; keystone --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service image
    #- unless: env -i - keystone --debug --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service image
    #- unless: env -i - keystone --debug --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin user-list |grep glance
    #- unless: echo Bypassing!
    - require:
      - cmd: glance-manage

glance-services-up:
  service.running:
    - init-delay: 3
    - enable: True
    - names:
      - glance-api
      - glance-registry
    - require:
      - cmd: glance-keystone-creates
    - watch:
      - ini: /etc/glance/glance-api.conf
      - ini: /etc/glance/glance-registry.conf


# JJW don't overwrite existing files - use ini_manage
#/etc/glance:
#  file:
#    - recurse
#    - source: salt://openstack/glance/files
#    - template: jinja
#    - require:
#      - pkg: openstack-glance


# Give up on salt's file.replace - too limited, can only do one replace (!)
#
#/etc/glance/glance-api.conf:
#  file:
#    - replace:
#      - pattern: "%SERVICE_TENANT%"
#      - repl: service
#    - replace:
#      - pattern: "%SERVICE_USER%"
#      - repl: glance
#    - replace:
#      - pattern: "%SERVICE_PASSWORD%"
#      - repl: {{ glance_password }}
#
#
#/etc/glance/glance-registry.conf:
#  file:
#    - replace
#      - pattern: "%SERVICE_TENANT%"
#      - repl: service
#    #- replace:
#      - pattern: "%SERVICE_USER%"
#      - repl: glance
#    #- replace:
#      - pattern: "%SERVICE_PASSWORD%"
#      - repl: {{ glance_password }}
#
# sheesh.  so do it manually with shell:

# JJW use ini-manage for Juno, salt Helium
#/etc/glance:
#  file:
#    - exists
#  cmd.run:
#    - cwd: /etc/glance
#    - name: |
#        cp glance-api.conf glance-api.conf.bak
#        cp glance-registry.conf glance-registry.conf.bak
#        replace %SERVICE_TENANT_NAME% service %SERVICE_USER% glance %SERVICE_PASSWORD% glance '#flavor=' 'flavor = keystone' -- glance-api.conf
#        replace %SERVICE_TENANT_NAME% service %SERVICE_USER% glance %SERVICE_PASSWORD% glance '#flavor=' 'flavor = keystone' -- glance-registry.conf
#        pass=glance  # { { glance_dbpass }}
#        host={{ bind_host }}
#        replace "sqlite_db = /var/lib/glance/glance.sqlite" "#sqlite_db = /var/lib/glance/glance.sqlite
#        connection = mysql://glance:$pass@$host/glance" -- glance-api.conf
#        replace "sqlite_db = /var/lib/glance/glance.sqlite" "#sqlite_db = /var/lib/glance/glance.sqlite
#        connection = mysql://glance:$pass@$host/glance" -- glance-registry.conf
#    - onlyif: grep %SERVICE_TENANT_NAME%  glance-registry.conf
#    - require:
#      - pkg: openstack-glance

glance-coreos-get:
  cmd:
    - run
    - cwd: /home/joe
    - name: |
        wget http://stable.release.core-os.net/amd64-usr/current/coreos_production_openstack_image.img.bz2
        bunzip2 coreos_production_openstack_image.img.bz2
    - creates: /home/joe/coreos_production_openstack_image.img

glance-ubuntu-core-get:
  cmd:
    - run
    - cwd: /home/joe
    - name: |
        wget http://cloud-images.ubuntu.com/ubuntu-core/devel/core/current/devel-core-amd64-disk1.img
        #wget http://cdimage.ubuntu.com/ubuntu-core/releases/14.04/release/ubuntu-core-14.04.2-core-amd64.tar.gz
        #tar zxvf ubuntu-core-14.04.2-core-amd64.tar.gz
    - creates: devel-core-amd64-disk1.img
    #/home/joe/ubuntu-core-14.04.2-core-amd64

glance-img-create:
  cmd:
    - run
    - name: |
        export OS_USERNAME=admin
        export OS_PASSWORD={{ admin_password }}
        export OS_AUTH_URL={{ admin_url }}
        export OS_TENANT_NAME=admin
        glance image-create --name Cirros --is-public true --container-format bare --disk-format qcow2 --location https://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
        glance image-create --name Trusty --is-public true --container-format bare --disk-format qcow2 --property hypervisor_type=kvm --property architecture=x86_64 --location https://cloud-images.ubuntu.com/releases/14.04.1/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
        glance image-create --name CoreOS   --container-format bare   --disk-format qcow2  --is-public True --property hypervisor_type=kvm --property architecture=x86_64 --file /home/joe/coreos_production_openstack_image.img
        glance image-create --name Snappy   --container-format bare   --disk-format qcow2  --is-public True --property hypervisor_type=kvm --property architecture=x86_64 --file /home/joe/devel-core-amd64-disk1.img
        glance image-list
    - unless: glance --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin image-list |grep Trusty
    - require:
      - service: glance-services-up
      - cmd: glance-coreos-get
      - cmd: glance-ubuntu-core-get
      - cmd: glance-coreos-get
      #- ini: /etc/glance/glance-api.conf
      #- ini: /etc/glance/glance-registry.conf

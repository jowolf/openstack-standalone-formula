{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}

#same as endpoint:
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}

{% set public_url = 'http://' ~ bind_host ~ ':5000/v2.0' %}
{% set admin_email = salt['pillar.get']('keystone:admin_email', 'joe@eracks.com') %}
{# % set admin_password = salt['pillar.get']('keystone:admin_password', 'keystone') % #}

{% set token = salt['pillar.get']('keystone.token', 'c195b883042b11f25916') %}
{% set password = salt['pillar.get']('keystone.password', 'keystone') %}

include:
  - mysql.server
  - mysql.python

keystone-pkgs:
  pkg.installed:
    - name: keystone

keystone-services-down:
  service.dead:
    - name: keystone
    - require:
      - pkg: keystone-pkgs

/var/lib/keystone/keystone.db:
  file.absent:
    - require:
      - service: keystone-services-down


## Create db first, & manage-db, then conf, keystone, services up

keystone-db:
  mysql_database.present:
    - name: keystone
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - connection_charset: utf8
    - saltenv:
      - LC_ALL: "en_US.utf8"
  mysql_user.present:
    - name: keystone
    - host: localhost
    - password: keystone
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
  mysql_grants.present:
    - grant: all privileges
    - database: keystone.*
    - user: keystone
    - connection_user: root
    - connection_pass: {{ mysql_root_password }}
    - require:
      - file: /var/lib/keystone/keystone.db

/etc/keystone/keystone.conf:
  ini.options_present:
    - sections:
        DEFAULT:
          bind_host:    {{ salt['pillar.get']('keystone:bind_host', '0.0.0.0') }}
          public_port:  {{ salt['pillar.get']('keystone:public_port', '5000') }}
          admin_port:   {{ salt['pillar.get']('keystone:admin_port', '35357') }}
          admin_token:  {{ token }}
          compute_port: {{ salt['pillar.get']('keystone:compute_port', '8774') }}
          verbose:      {{ salt['pillar.get']('keystone:verbose', 'True') }}
          debug:        {{ salt['pillar.get']('keystone:debug', 'False') }}
          #use_syslog:   {{ salt['pillar.get']('keystone:use_syslog', 'False') }}
          #log_file:     {{ salt['pillar.get']('keystone:log_file', '/var/log/keystone/keystone.log') }}
          idle_timeout: {{ salt['pillar.get']('keystone:sql:idle_timeout', '200') }}
          admin_workers: 3
          public_workers: 3
        token:
          expiration: {{ salt['pillar.get']('keystone:token:expiration', '86400') }}
        database:
          connection:   {{ salt['pillar.get']('keystone:sql:connection', 'mysql://keystone:keystone@localhost/keystone') }}
    - backupname: .bak
    - require:
      - mysql_grants: keystone-db

keystone-manage:
  cmd.run:
    - name: keystone-manage db_sync
    - unless: keystone --os-token {{ token }} --os-endpoint {{ admin_url }} service-list
    - require:
      - ini: /etc/keystone/keystone.conf

#keystone-support:
#  ...

keystone-services-up:
  service:
    - name: keystone
    - running
    - enable: True
    - init_delay: 3
    - require:
      - cmd: keystone-manage
    - watch:
      - ini: /etc/keystone/keystone.conf

#keystone-tenants:
#  keystone.tenant_present:
#    - names:
#      - admin
#      - demo
#      - service
#      - eRacks
#    - require:
      #- service: keystone-services
      #- ini: /etc/keystone/keystone.conf
#      - cmd: keystone-manage

#keystone-roles:
#  keystone.role_present:
#    - names:
#      - admin
#      - Member
#    - require:
      #- service: keystone-services
      #- ini: /etc/keystone/keystone.conf
#      - cmd: keystone-manage

#keystone-admin-user:
#  keystone.user_present:
#    - name: admin
#    - password: {{ password }}
#    - email: {{ admin_email }}
#    - tenant: admin
#    - roles:
#        admin:   # tenants
#          - admin  # roles
#        service:
#          - admin
#          - Member
#    - require:
#      - keystone: keystone-tenants
#      - keystone: keystone-roles

#keystone-demo-user:
#  keystone.user_present:
#    - name: demo
#    - password: {{ password }}
#    - email: {{ admin_email }}
#    - roles:
#        demo:
#          - Member
#    - require:
#      - keystone: keystone-tenants
#      - keystone: keystone-roles

#keystone-eracks-user:
#  keystone.user_present:
#    - name: eRacks
#    - password: {{ password }}
#    - email: {{ admin_email }}
#    - roles:
#        eRacks:
#          - Member
#    - require:
#      - keystone: keystone-tenants
#      - keystone: keystone-roles

keystone-admin-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        sleep 3
        keystone tenant-create --name=admin --description="Admin Tenant"
        keystone tenant-create --name=service --description="Service Tenant"
        keystone tenant-create --name=demo --description="Demo Tenant"
        keystone tenant-create --name=eRacks --description="eRacks Tenant"
        keystone user-create --name=admin --pass={{ password }} --email={{ admin_email }}
        keystone user-create --name=demo --pass={{ password }} --email={{ admin_email }}
        keystone user-create --name=eRacks --pass={{ password }} --email={{ admin_email }}
        keystone role-create --name=admin
        keystone role-create --name=_member_
        keystone user-role-add --user=admin --tenant=admin --role=admin
        keystone user-role-add --user=admin --tenant=service --role=_member_
        keystone user-role-add --user=demo --tenant=demo --role=_member_
        keystone user-role-add --user=eRacks --tenant=eRacks --role=_member_
    - unless: keystone --os-token {{ token }} --os-endpoint {{ admin_url }} user-list | grep admin
    - require:
      - service: mysqld
      - service: keystone-services-up
      #- ini: /etc/keystone/keystone.conf

keystone-service:
  keystone.service_present:
    - name: keystone
    - service_type: identity
    - description: Keystone Identity Service
    - require:
      - cmd: keystone-admin-create
      #- keystone: keystone-admin-user

keystone-endpoint:
  keystone.endpoint_present:
    - name: keystone
    - region: regionOne
    - publicurl: {{ public_url }}
    - internalurl: {{ public_url }}
    - adminurl: {{ admin_url }}
    - require:
      - keystone: keystone-service


#keystone-service-create:
#  cmd:
#    - run
#    - name: |
#        export OS_SERVICE_TOKEN= admin_token
#        export OS_SERVICE_ENDPOINT={{ admin_url }}
#        keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"
#    - unless: keystone --os-token admin_token  --os-endpoint {{ admin_url }} service-list | grep identity
#    - require:
#      #- pkg: openstack-keystone
#      - service: mysqld
#      - service: keystone-service
#      #- ini: /etc/keystone/keystone.conf
#      - cmd: keystone-admin-create

#keystone-endpoint-create:
#  cmd:
#    - run
#    - name: |
#        export OS_SERVICE_TOKEN= admin_token
#        export OS_SERVICE_ENDPOINT={{ admin_url }}
#        keystone endpoint-create --service=keystone --publicurl={{ public_url }} --internalurl={{ public_url }} --adminurl={{ admin_url }}
#    - unless: keystone --os-username admin --os-password admin_password --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service identity
#    - require:
#      #- pkg: openstack-keystone
#      - service: mysqld
#      - service: keystone-service
#      #- ini: /etc/keystone/keystone.conf
#      - cmd: keystone-service-create

#keystone-db-init:
#  cmd:
#    - run
#    # if it fails, run it again, that's what the || (or) is for:
#    - name: openstack-db --init --service keystone --rootpw '{{ mysql_root_password }}' || openstack-db --init --service keystone --rootpw '{{ mysql_root_password }}'
#    - unless: echo '' | mysql keystone --password='{{ mysql_root_password }}'
#    - require:
#      #- pkg: openstack-keystone
#      - service: mysqld
#      - service: keystone-service
#      #- ini: /etc/keystone/keystone.conf


{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone:admin_password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':9292' %}
{% set glance_email = salt['pillar.get']('keystone:glance_email', 'joe@eracks.com') %}
{% set glance_password = salt['pillar.get']('keystone:glance_password', 'glance') %}

include:
  - mysql.server

openstack-glance:
  pkg:
    - name: glance
    - installed

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
    - require:
      - pkg: openstack-glance
      - service: mysqld

glance-db-init:
  cmd:
    - run
    - name: openstack-db --init --service glance --rootpw '{{ mysql_root_password }}'
    - unless: echo '' | mysql glance --password='{{ mysql_root_password }}'
    - require:
      - pkg: openstack-glance
      - service: mysqld

glance-services:
  service:
    - running
    - enable: True
    - names:
      - glance-api
      - glance-registry
    - require:
      - pkg: openstack-glance
      - cmd: glance-db-init
    - watch:
      - file: /etc/glance

# JJW don't overwrite existing files - use ini_manage
#/etc/glance:
#  file:
#    - recurse
#    - source: salt://openstack/glance/files
#    - template: jinja
#    - require:
#      - pkg: openstack-glance

glance-api:
  file:
    - name: /etc/glance/glance-api.conf
      - replace: 
        - pattern: "%SERVICE_TENANT%"
        - repl: service
      - replace: 
        - pattern: "%SERVICE_USER%"
        - repl: glance
      - replace: 
        - pattern: "%SERVICE_PASSWORD%"
        - repl: {{ glance_password }}

glance-registry:
  file:
    - name: /etc/glance/glance-registry.conf
      - replace: 
        - pattern: "%SERVICE_TENANT%"
        - repl: service
      - replace: 
        - pattern: "%SERVICE_USER%"
        - repl: glance
      - replace: 
        - pattern: "%SERVICE_PASSWORD%"
        - repl: {{ glance_password }}

glance-img-create:
  cmd:
    - run
    - name: |
        glance image-create --name Cirros --is-public true --container-format bare --disk-format qcow2 --location https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
        glance index
    - require:
      - pkg: openstack-glance
      - cmd: glance-db-init
      - service: glance-services
      - file: /etc/glance/glance-registry.conf

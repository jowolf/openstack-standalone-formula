{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':9292' %}

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
        export OS_SERVICE_TOKEN={{ admin_token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        keystone user-create --name=glance --pass={{ salt['pillar.get']('keystone:glance_password', 'glance') }} --email={{ salt['pillar.get']('keystone:glance_email', 'joe@eracks.com') }}
        keystone user-role-add --user=glance --tenant=service --role=admin
        keystone service-create --name=glance --type=image --description="Glance Image Service"
        keystone endpoint-create --service=glance --publicurl={{ public_url }} --internalurl={{ public_url }} --adminurl={{ public_url }}
    - unless: keystone --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant admin endpoint-get --service image
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

/etc/glance:
  file:
    - recurse
    - source: salt://openstack/glance/files
    - template: jinja
    - require:
      - pkg: openstack-glance

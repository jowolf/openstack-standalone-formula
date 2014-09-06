{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':5000/v2.0' %}

keystone-db-init:
  cmd:
    - run
    - name: openstack-db --init --service keystone --rootpw '{{ mysql_root_password }}'
    - unless: echo '' | mysql keystone --password='{{ mysql_root_password }}'
    - require:
      - pkg: openstack-keystone
      - service: mysqld

keystone-db-sync:
  cmd:
    - run
    - name: keystone-manage db_sync
    - unless: keystone --os-token {{ admin_token }} --os-endpoint {{ admin_url }} service-list
    - require:
      - pkg: openstack-keystone
      - service: mysqld

keystone-admin-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ admin_token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        keystone tenant-create --name=admin --description="Admin Tenant"
        keystone tenant-create --name=service --description="Service Tenant"
        keystone user-create --name=admin --pass={{ salt['pillar.get']('keystone:admin_password', 'keystone') }} --email={{ salt['pillar.get']('keystone:admin_email', 'joe@eracks.com') }}
        keystone role-create --name=admin
        keystone user-role-add --user=admin --tenant=admin --role=admin
    - unless: keystone --os-token {{ admin_token }} --os-endpoint {{ admin_url }} user-get admin
    - require:
      - pkg: openstack-keystone
      - service: mysqld

keystone-service-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ admin_token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"
    - unless: keystone --os-token {{ admin_token }} --os-endpoint {{ admin_url }} service-list | grep identity
    - require:
      - pkg: openstack-keystone
      - service: mysqld

keystone-endpoint-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ admin_token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        keystone endpoint-create --service=keystone --publicurl={{ public_url }} --internalurl={{ public_url }} --adminurl={{ admin_url }}
    - unless: keystone --os-token {{ admin_token }} --os-endpoint {{ admin_url }} endpoint-list | grep keystone
    - require:
      - pkg: openstack-keystone
      - service: mysqld

openstack-keystone:
  service:
    - name: keystone
    - running
    - enable: True
    - require:
      - pkg: openstack-keystone
    - watch:
      - cmd: keystone-db-init
      - file: /etc/keystone
  pkg:
    - name: keystone
    - installed

/etc/keystone:
  file:
    - recurse
    - source: salt://openstack/keystone/files
    - template: jinja
    - require:
      - pkg: openstack-keystone

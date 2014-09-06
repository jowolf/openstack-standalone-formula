{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
#{{ salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') }}
#{{ salt['pillar.get']('keystone:bind_host', '0.0.0.0') }}

keystone-db-init:
  cmd:
    - run
    - name: openstack-db --init --service keystone --rootpw '{{ mysql_root_password }}'
    - unless: echo '' | mysql keystone --password='{{ mysql_root_password }}'
    - require:
      - pkg: openstack-keystone
      - service: mysqld

keystone-admin-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') }}
        export OS_SERVICE_ENDPOINT=http://{{ salt['pillar.get']('keystone:bind_host', '0.0.0.0') }}:35357/v2.0
        keystone tenant-create --name=admin --description="Admin Tenant"
        keystone tenant-create --name=service --description="Service Tenant"
        keystone user-create --name=admin --pass={{ salt['pillar.get']('keystone:admin_password', 'keystone') }} --email={{ salt['pillar.get']('keystone:admin_email', 'joe@eracks.com') }}
        keystone role-create --name=admin
        keystone user-role-add --user=admin --tenant=admin --role=admin
    - unless: keystone user-get admin
    - require:
      - pkg: openstack-keystone
      - service: mysqld

keystone-service-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') }}
        export OS_SERVICE_ENDPOINT=http://{{ salt['pillar.get']('keystone:bind_host', '0.0.0.0') }}:35357/v2.0
        keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"
        #keystone endpoint-create --service=keystone --publicurl=http://10.0.0.1:5000/v2.0 --internalurl=http://10.0.0.1:5000/v2.0 --adminurl=http://10.0.0.1:35357/v2.0
    - unless: keystone service-get keystone
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

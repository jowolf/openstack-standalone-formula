{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}
{% set bind_host = salt['pillar.get']('keystone:bind_host', '0.0.0.0') %}
{% set admin_token = salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') %}
{% set admin_password = salt['pillar.get']('keystone:admin_password', 'keystone') %}
{% set admin_url = 'http://' ~ bind_host ~ ':35357/v2.0' %}
{% set public_url = 'http://' ~ bind_host ~ ':5000/v2.0' %}
{% set admin_email = salt['pillar.get']('keystone:admin_email', 'joe@eracks.com') %}

openstack-keystone:
  pkg:
    - name: keystone
    - installed

/etc/keystone/keystone.conf:
  ini.options_present:
    - sections:
        DEFAULT:
          bind_host:    {{ salt['pillar.get']('keystone:bind_host', '0.0.0.0') }}
          public_port:  {{ salt['pillar.get']('keystone:public_port', '5000') }}
          admin_port:   {{ salt['pillar.get']('keystone:admin_port', '35357') }}
          admin_token:  {{ salt['pillar.get']('keystone:admin_token', 'c195b883042b11f25916') }}
          compute_port: {{ salt['pillar.get']('keystone:compute_port', '8774') }}
          verbose:      {{ salt['pillar.get']('keystone:verbose', 'True') }}
          debug:        {{ salt['pillar.get']('keystone:debug', 'True') }}
          #use_syslog:   {{ salt['pillar.get']('keystone:use_syslog', 'False') }}
          #log_file:     {{ salt['pillar.get']('keystone:log_file', '/var/log/keystone/keystone.log') }}
          connection:   {{ salt['pillar.get']('keystone:sql:connection', 'mysql://keystone:keystone@localhost/keystone') }}
          idle_timeout: {{ salt['pillar.get']('keystone:sql:idle_timeout', '200') }}
        token:
          expiration: {{ salt['pillar.get']('keystone:token:expiration', '86400') }}
    - require:
      - pkg: openstack-keystone
    - backupname: .bak

keystone-service:
  service:
    - name: keystone
    - running
    - enable: True
    - require:
      - pkg: openstack-keystone
      - ini: /etc/keystone/keystone.conf
    - watch:
      #- cmd: keystone-db-init
      - ini: /etc/keystone/keystone.conf

keystone-db-init:
  cmd:
    - run
    # if it fails, run it again, that's what the || (or) is for:
    - name: openstack-db --init --service keystone --rootpw '{{ mysql_root_password }}' || openstack-db --init --service keystone --rootpw '{{ mysql_root_password }}'
    - unless: echo '' | mysql keystone --password='{{ mysql_root_password }}'
    - require:
      #- pkg: openstack-keystone
      - service: mysqld
      - service: keystone-service
      #- ini: /etc/keystone/keystone.conf

keystone-db-sync:
  cmd:
    - run
    - name: keystone-manage db_sync
    - unless: keystone --os-token {{ admin_token }} --os-endpoint {{ admin_url }} service-list
    - require:
      #- pkg: openstack-keystone
      - service: mysqld
      - service: keystone-service
      #- ini: /etc/keystone/keystone.conf
      - cmd: keystone-db-init

keystone-admin-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ admin_token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        keystone tenant-create --name=admin --description="Admin Tenant"
        keystone tenant-create --name=service --description="Service Tenant"
        keystone user-create --name=admin --pass={{ admin_password }} --email={{ admin_email }}
        keystone role-create --name=admin
        keystone role-create --name=_member_
        keystone user-role-add --user=admin --tenant=admin --role=admin
        keystone user-role-add --user=admin --tenant=admin --role=_member_
    - unless: keystone --os-token {{ admin_token }} --os-endpoint {{ admin_url }} user-list | grep admin
    - require:
      #- pkg: openstack-keystone
      - service: mysqld
      - service: keystone-service
      #- ini: /etc/keystone/keystone.conf
      - cmd: keystone-db-sync

keystone-service-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ admin_token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        keystone service-create --name=keystone --type=identity --description="Keystone Identity Service"
    - unless: keystone --os-token {{ admin_token }} --os-endpoint {{ admin_url }} service-list | grep identity
    - require:
      #- pkg: openstack-keystone
      - service: mysqld
      - service: keystone-service
      #- ini: /etc/keystone/keystone.conf
      - cmd: keystone-admin-create

keystone-endpoint-create:
  cmd:
    - run
    - name: |
        export OS_SERVICE_TOKEN={{ admin_token }}
        export OS_SERVICE_ENDPOINT={{ admin_url }}
        keystone endpoint-create --service=keystone --publicurl={{ public_url }} --internalurl={{ public_url }} --adminurl={{ admin_url }}
    - unless: keystone --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin endpoint-get --service identity
    - require:
      #- pkg: openstack-keystone
      - service: mysqld
      - service: keystone-service
      #- ini: /etc/keystone/keystone.conf
      - cmd: keystone-service-create

# nope, this requires a binary, in the openstack-utils package, which is not on Debian / Ubuntu
#keystone-conf:
#  openstack_config.present:
#    - filename: /etc/keystone/keystone.conf
#    - section: DEFAULT
#    - parameter: connection  # (optional) The parameter to change. If the parameter is not supplied, the name will be used as the parameter.
#    - value: {{ salt['pillar.get']('keystone:sql:connection', 'mysql://keystone:keystone@localhost/keystone') }}


# this is now for the old examples only, and should be removed once testing is complete - JJW:
#/etc/keystone:
#  file:
#    - recurse
#    - source: salt://openstack/keystone/files
#    - template: jinja
#    - require:
#      - pkg: openstack-keystone

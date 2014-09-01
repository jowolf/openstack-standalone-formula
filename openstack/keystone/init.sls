{% set mysql_root_password = salt['pillar.get']('mysql:server:root_password', salt['grains.get']('server_id')) %}

keystone-db-init:
  cmd:
    - run
    - name: openstack-db --init --service keystone --rootpw '{{ mysql_root_password }}'
    - unless: echo '' | mysql keystone --password='{{ mysql_root_password }}'
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

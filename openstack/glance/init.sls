include:
  - mysql.server

openstack-glance:
  pkg:
    - name: glance
    - installed

glance-db-init:
  cmd:
    - run
    - name: openstack-db --init --service glance --rootpw ''
    - unless: echo '' | mysql glance
    - require:
      - pkg: openstack-glance
      - service: mysqld

glance-services:
  service:
    - running
    - enable: True
    - names:
      - openstack-glance-api
      - openstack-glance-registry
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

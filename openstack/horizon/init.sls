{% set pkg = salt['grains.filter_by']({
  'Debian': {
    'name': 'openstack-dashboard',
    'wsgi_conf': '/etc/apache2/conf.d/openstack-dashboard.conf',
  },
  'RedHat': {
    'name': 'openstack-dashboard',
    'wsgi_conf': '/etc/httpd/conf.d/openstack-dashboard.conf',
  },
}, merge=salt['pillar.get']('apache:lookup')) %}

include:
  - apache
  - apache.mod_wsgi

horizon:
  pkg.installed:
    - name: {{ pkg.name }}
    - watch_in:
      - service: apache

#/etc/openstack-dashboard/local_settings:
#  file.managed:
#    - source: salt://openstack/horizon/files/local_settings
#    - template: jinja
#    - require:
#      - pkg: horizon
#    - watch_in:
#      - service: apache

horizon-config:
  file:
    - managed
    - name: {{ pkg.wsgi_conf }}
    - source: salt://openstack/horizon/files/openstack-dashboard.conf
    - template: jinja
    - require:
      - pkg: horizon
    - watch_in:
      - service: apache

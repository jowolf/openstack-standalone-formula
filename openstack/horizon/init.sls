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

# TODO: make backup '.org' copy

/etc/openstack-dashboard/local_settings.py:
  cmd.run:
    - cwd: /etc/openstack-dashboard/
    - user: root
    - name: |
        ensure.py local_settings.py DEBUG=True
        ensure.py local_settings.py SECRET_KEY='"{{ salt['pillar.get']('horizon:secret_key', "'" + salt.random.get_str(64) + "'") }}"'
        ensure.py local_settings.py TIME_ZONE='"America/Los_Angeles"'
        ensure.py local_settings.py OPENSTACK_HOST='"127.0.0.1"'
        # EMAIL_HOST = 'smtp.my-company.com'
        # EMAIL_PORT = 25
        # EMAIL_HOST_USER = 'djangomail'
        # EMAIL_HOST_PASSWORD = 'top-secret!'
        ensure.py local_settings.py LOGIN_URL="'/auth/login/'"
        ensure.py local_settings.py LOGOUT_URL="'/auth/logout/'"
        ensure.py local_settings.py LOGIN_REDIRECT_URL="'/'"
    - require:
      - file: /usr/local/bin/ensure.py
      - pkg: horizon

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




# Nope, ini-manage doesn't work, as it munges other portions of the file,
# rather than taking a minimalistic approach:
#
#/etc/openstack-dashboard/local_settings.py:
#  ini.options_present:
#    - sections:
#        DEFAULT_IMPLICIT:
#          secret_key: {{ salt['pillar.get']('horizon:secret_key', 'My nifty boffo supersecret key xqzy25!!zz') }}
#    - require:
#      - pkg: horizon


# This is the wrong approach: It ignores package-maintainer's changes; and
# has to be re-checked every release, even minor ones:
#
#/etc/openstack-dashboard/local_settings:
#  file.managed:
#    - source: salt://openstack/horizon/files/local_settings
#    - template: jinja
#    - require:
#      - pkg: horizon
#    - watch_in:
#      - service: apache


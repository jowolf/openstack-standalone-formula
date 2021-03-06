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


# Give up on salt's file.replace - too limited, can only do one replace (!)
#
#/etc/glance/glance-api.conf:
#  file:
#    - replace: 
#      - pattern: "%SERVICE_TENANT%"
#      - repl: service
#    - replace: 
#      - pattern: "%SERVICE_USER%"
#      - repl: glance
#    - replace: 
#      - pattern: "%SERVICE_PASSWORD%"
#      - repl: {{ glance_password }}
#
#
#/etc/glance/glance-registry.conf:
#  file:
#    - replace
#      - pattern: "%SERVICE_TENANT%"
#      - repl: service
#    #- replace: 
#      - pattern: "%SERVICE_USER%"
#      - repl: glance
#    #- replace: 
#      - pattern: "%SERVICE_PASSWORD%"
#      - repl: {{ glance_password }}
#
# sheesh.  so do it manually with shell:

/etc/glance:
  file:
    - exists
  cmd.run:
    - cwd: /etc/glance
    - name: |
        cp glance-api.conf glance-api.conf.bak
        cp glance-registry.conf glance-registry.conf.bak
        replace %SERVICE_TENANT_NAME% service %SERVICE_USER% glance %SERVICE_PASSWORD% glance '#flavor=' 'flavor = keystone' -- glance-api.conf
        replace %SERVICE_TENANT_NAME% service %SERVICE_USER% glance %SERVICE_PASSWORD% glance '#flavor=' 'flavor = keystone' -- glance-registry.conf
        pass=glance  # { { glance_dbpass }}
        host={{ bind_host }}
        replace "sqlite_db = /var/lib/glance/glance.sqlite" "#sqlite_db = /var/lib/glance/glance.sqlite
        connection = mysql://glance:$pass@$host/glance" -- glance-api.conf
        replace "sqlite_db = /var/lib/glance/glance.sqlite" "#sqlite_db = /var/lib/glance/glance.sqlite
        connection = mysql://glance:$pass@$host/glance" -- glance-registry.conf
    - onlyif: grep %SERVICE_TENANT_NAME%  glance-registry.conf
    - require:
      - pkg: openstack-glance

glance-img-create:
  cmd:
    - run
    - name: |
        export OS_USERNAME=admin
        export OS_PASSWORD={{ admin_password }}
        export OS_AUTH_URL={{ admin_url }}
        export OS_TENANT_NAME=admin
        glance image-create --name Cirros --is-public true --container-format bare --disk-format qcow2 --location https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
        glance image-create --name Trusty --is-public true --container-format bare --disk-format qcow2 --property hypervisor_type=kvm --property architecture=x86_64 --location https://cloud-images.ubuntu.com/releases/14.04.1/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
        wget http://alpha.release.core-os.net/amd64-usr/current/coreos_production_openstack_image.img.bz2
        bunzip2 coreos_production_openstack_image.img.bz2 
        glance image-create --name CoreOS   --container-format bare   --disk-format qcow2  --is-public True --property hypervisor_type=kvm --property architecture=x86_64 --file /home/joe/coreos_production_openstack_image.img
        glance index
    - unless: glance --os-username admin --os-password {{ admin_password }} --os-auth-url {{ admin_url }} --os-tenant-name admin index |grep Trusty
    - require:
      - pkg: openstack-glance
      - cmd: glance-db-init
      - service: glance-services
      - file: /etc/glance

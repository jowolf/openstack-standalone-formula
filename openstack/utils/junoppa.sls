# Nope!  nfg, Salt can't handle 'cloud-archive' PPAs
#juno-ppa:
#  pkgrepo.managed:
#    - humanname: Juno PPA
#    #- name: 
#    - ppa: cloud-archive/juno
#    - dist: trusty
#    #- file: /etc/apt/sources.list.d/logstash.list
#    #- keyid: 28B04E4A
#    #- keyserver: keyserver.ubuntu.com

juno-ppa:
  cmd.run:
    - name: add-apt-repository -y cloud-archive:juno
    - require_in:
      - pkg: openstack-keystone
      - pkg: openstack-nova
      - pkg: openstack-glance
      - pkg: horizon
      - pkg: cinder-pkgs

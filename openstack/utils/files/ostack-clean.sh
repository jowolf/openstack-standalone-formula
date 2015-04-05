sudo apt-get -y purge mysql-server mysql-client mysql-common python-mysqldb \
    nova-common nova-volume nova-cert nova-api nova-api-metadata nova-compute nova-compute-kvm \
    nova-novncproxy nova-spiceproxy nova-compute-libvirt nova-network nova-conductor \
    nova-console nova-consoleauth nova-scheduler \
    keystone glance dnsmasq dnsmasq-base dnsmasq-utils openstack-dashboard \
    cinder-common glance-common \
    python-django-horizon python-ceilometerclient python-troveclient python-openstack-auth \
    python-heatclient python-novaclient python-nova python-cinderclient python-glanceclient \
    libvirt0 samba samba-common python-samba bind9

# rabbitmq-server qpid

sudo apt-get -y --purge autoremove

netstat -antp |grep dnsmasq
ps ax |grep dnsmasq

killall dnsmasq

netstat -antp |grep dnsmasq
ps ax |grep dnsmasq


sh restart_networking.sh

# ifconfig br100 down
# ifconfig br101 down

ifconfig


sudo ls -la /var/lib/mysql/
sudo ls -la /etc/mysql
sudo ls -la /etc/keystone
sudo ls -la /etc/glance
sudo ls -la /etc/nova
sudo ls -la /etc/neutron
sudo ls -la /etc/cinder
sudo ls -la /etc/libvirt

sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib/keystone
sudo rm -rf /var/lib/glance
sudo rm -rf /var/lib/nova
sudo rm -rf /var/lib/neutron
sudo rm -rf /var/lib/cinder
sudo rm -rf /var/lib/libvirt

sudo ls -la /var/lib/mysql
sudo ls -la /var/lib/keystone
sudo ls -la /var/lib/glance
sudo ls -la /var/lib/nova
sudo ls -la /var/lib/neutron
sudo ls -la /var/lib/cinder
sudo ls -la /var/lib/libvirt

sudo rm -rf /var/log/mysql
sudo rm -rf /var/log/keystone
sudo rm -rf /var/log/glance
sudo rm -rf /var/log/nova
sudo rm -rf /var/log/neutron
sudo rm -rf /var/log/cinder
sudo rm -rf /var/log/libvirt

sudo ls -la /var/log/mysql
sudo ls -la /var/log/keystone
sudo ls -la /var/log/glance
sudo ls -la /var/log/nova
sudo ls -la /var/log/neutron
sudo ls -la /var/log/cinder
sudo ls -la /var/log/libvirt

sudo rm -rf /etc/mysql
sudo rm -rf /etc/keystone
sudo rm -rf /etc/glance
sudo rm -rf /etc/nova
sudo rm -rf /etc/neutron
sudo rm -rf /etc/cinder
sudo rm -rf /etc/libvirt

sudo ls -la /etc/mysql
sudo ls -la /etc/keystone
sudo ls -la /etc/glance
sudo ls -la /etc/nova
sudo ls -la /etc/neutron
sudo ls -la /etc/cinder
sudo ls -la /etc/libvirt

sudo rm -rf /var/log/upstart/*
sudo rm -rf /var/log/apache2/*
sudo rm -rf /var/log/libvirt/*

sudo ls -la /var/log/upstart/*
sudo ls -la /var/log/apache2/*
sudo ls -la /var/log/libvirt/*

echo Done with $0

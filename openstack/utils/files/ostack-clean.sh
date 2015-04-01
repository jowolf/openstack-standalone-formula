sudo apt-get -y purge mysql-server mysql-client mysql-common python-mysqldb nova-common nova-volume \
    keystone glance dnsmasq dnsmasq-base dnsmasq-utils openstack-dashboard python-django-horizon \
    python-ceilometerclient python-troveclient python-openstack-auth python-heatclient \
    cinder-common glance-common

# rabbitmq-server qpid

sudo apt-get -y --purge autoremove

sudo ls -l /var/lib/mysql/
sudo ls -l /etc/mysql
sudo ls -l /etc/keystone
sudo ls -l /etc/glance
sudo ls -l /etc/nova
sudo ls -l /etc/neutron
sudo ls -l /etc/cinder

sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib/keystone
sudo rm -rf /var/lib/glance
sudo rm -rf /var/lib/nova
sudo rm -rf /var/lib/neutron
sudo rm -rf /var/lib/cinder

sudo rm -rf /var/log/mysql
sudo rm -rf /var/log/keystone
sudo rm -rf /var/log/glance
sudo rm -rf /var/log/nova
sudo rm -rf /var/log/neutron
sudo rm -rf /var/log/cinder

sudo rm -rf /etc/mysql
sudo rm -rf /etc/keystone
sudo rm -rf /etc/glance
sudo rm -rf /etc/nova
sudo rm -rf /etc/neutron
sudo rm -rf /etc/cinder

sudo rm -rf /var/log/upstart/*
sudo rm -rf /var/log/apache2/*



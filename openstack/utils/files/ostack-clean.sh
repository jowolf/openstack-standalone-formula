sudo apt-get purge mysql-server mysql-client mysql-common nova-common keystone glance dnsmasq dnsmasq-base dnsmasq-utils
sudo apt-get --purge autoremove
sudo ls -l /var/lib/mysql/
sudo ls -l /etc/mysql
sudo ls -l /etc/keystone
sudo ls -l /etc/glance
sudo ls -l /etc/nova
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/lib/keystone
sudo rm -rf /var/lib/nova
sudo rm -rf /var/lib/glance
sudo rm -rf /etc/mysql
sudo rm -rf /etc/keystone
sudo rm -rf /etc/glance
sudo rm -rf /etc/nova



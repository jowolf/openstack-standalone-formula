# now NFG as of 13.10 or 14.04:
# sudo /etc/init.d/networking restart
# sudo service networking restart

ifdown br100 && ifup br100
ifdown eth0 && ifup eth0
ifconfig

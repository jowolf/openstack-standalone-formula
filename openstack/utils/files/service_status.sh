#!/bin/sh

service nova-api status
#service nova-api-metadata status
service nova-cert status
service nova-compute status
service nova-conductor status
service nova-consoleauth status
service nova-console status
service nova-network status
service nova-novncproxy status
service nova-scheduler status
service nova-spiceproxy status

service glance-api status
service glance-registry status

service cinder-scheduler status
service cinder-api status
service cinder-volume status
service tgt status


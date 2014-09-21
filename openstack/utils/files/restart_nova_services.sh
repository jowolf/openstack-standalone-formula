#!/bin/sh

service nova-api restart
service nova-api-metadata restart
service nova-network restart

service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
service nova-compute restart
service nova-console restart

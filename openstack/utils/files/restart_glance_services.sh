#!/bin/sh

service glance-api status
service glance-registry status

service glance-api restart
service glance-registry restart

service glance-api status
service glance-registry status


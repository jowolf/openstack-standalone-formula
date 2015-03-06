#!/bin/sh

service cinder-scheduler status
service cinder-api status
service cinder-volume status
service tgt status

service cinder-scheduler restart
service cinder-api restart
service cinder-volume restart
service tgt restart

service cinder-scheduler status
service cinder-api status
service cinder-volume status
service tgt status

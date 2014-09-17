#!/bin/sh

echo keystone user-list
keystone user-list
echo keystone role-list
keystone role-list
echo keystone user-role-list
keystone user-role-list
echo keystone user-role-list --tenant service --user nova
keystone user-role-list --tenant service --user nova
echo keystone user-role-list --tenant service --user glance
keystone user-role-list --tenant service --user glance
keystone user-role-list --user nova
echo keystone tenant-list
keystone tenant-list
echo keystone endpoint-list
keystone endpoint-list
echo keystone service-list
keystone service-list

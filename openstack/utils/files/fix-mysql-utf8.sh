#!/bin/sh

mysql -u root -p glance <<EOF
alter table migrate_version convert to character set utf8 collate utf8_unicode_ci;
flush privileges;
quit
EOF

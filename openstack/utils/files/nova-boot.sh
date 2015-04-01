nova --debug boot --flavor m1.small --image trusty --key-name mintstudio-maya \
  --nic net-id=`nova net-list | grep net10 | awk '{print $2}'`,v4-fixed-ip=10.1.4.23 \
  --user-data=cloud15.yaml --config-drive true trust23

nova floating-ip-disassociate eracks-dev3 216.172.133.130

nova --debug boot --flavor m1.small --image trusty --key-name mintstudio-maya \
  --nic net-id=`nova net-list | grep net10 | awk '{print $2}'` \
  --user-data=cloud16.yaml --config-drive true --poll eracks-dev3

#   --nic net-id=`nova net-list | grep net10 | awk '{print $2}'`,v4-fixed-ip=10.1.4.3 \
# nope:  --meta hostname=eracks-dev3 --hint hostname=eracks-dev3

nova floating-ip-associate eracks-dev3 216.172.133.130

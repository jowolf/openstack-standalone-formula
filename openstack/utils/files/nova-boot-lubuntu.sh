hostname=lubuntu
ip=131

nova floating-ip-disassociate $hostname 216.172.133.$ip

nova boot --flavor m1.medium --image vivid --key-name mintstudio-maya \
  --nic net-id=`nova net-list | grep net10 | awk '{print $2}'` \
  --user-data=cloud17-lubuntu.yaml --config-drive true --poll $hostname

  #nope: Swap drive requested is larger than instance type allows.
  #--swap 4000 \

nova floating-ip-associate $hostname 216.172.133.$ip

#!/bin/sh
EXT_NAME="ext"
INT_NAME="mydemo"

neutron net-create "$EXT_NAME-net" --router:external True --provider:physical_network external --provider:network_type flat --os-username admin --os-password secret

neutron subnet-create "$EXT_NAME-net" --name "$EXT_NAME-subnet" --allocation-pool start=172.18.171.85,end=172.18.171.89   --disable-dhcp --gateway 172.18.171.1 172.18.171.0/25

neutron net-create "$INT_NAME-net"
neutron subnet-create "$INT_NAME-net" --name "$INT_NAME-subnet" --gateway 192.168.1.1 192.168.1.0/24

neutron router-create demo-router
neutron router-interface-add demo-router "$INT_NAME-subnet"
neutron router-gateway-set demo-router "$EXT_NAME-net"

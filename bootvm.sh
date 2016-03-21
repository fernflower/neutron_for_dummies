#!/bin/sh
INT_NAME="mydemoroot"
VM_NAME="vm"
IMG="cirros-0.3.4-x86_64-uec"

NET_ID=$(neutron net-list | grep "$INT_NAME-net" | awk '{print $2}')
nova boot "$VM_NAME-instance" --flavor m1.tiny --image "$IMG" --nic net-id=$NET_ID

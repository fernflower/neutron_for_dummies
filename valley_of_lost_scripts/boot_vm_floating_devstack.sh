#!/bin/sh

INCLUDED=1
OPENRC="/home/dev-user/devstack/openrc"
EXT="public"
INT="mydemo"
SECGROUP="sg_ovsfw"
ROUTER="demo-router"
INT_GATEWAY="20.10.0.1"
INT_CIDR="20.10.0.0/24"
VM="vm-$RANDOM"
IMG="cirros-0.3.5-x86_64-disk"
ETHERTYPE="ipv4"
KEY="testkey"
PUB_KEY_LOC="~/.ssh/id_rsa.pub"
IPERF_PORT="9999"

source boot_vm_floating.sh

#!/bin/sh

INCLUDED=1
OPENRC="/home/dev-user/devstack/openrc"
EXT="public"
INT="mydemo"
SECGROUP="sg_ovsfw"
ROUTER="demo-router"
EXT_POOL="start=172.18.171.86,end=172.18.171.90"
EXT_GATEWAY="172.18.171.1"
EXT_CIDR="172.18.171.0/25"
INT_GATEWAY="20.10.0.1"
INT_CIDR="20.10.0.0/24"
VM="vm-$RANDOM"
IMG="cirros-0.3.4-x86_64-uec"
ETHERTYPE="ipv4"
KEY="testkey"
PUB_KEY_LOC="~/.ssh/id_rsa.pub"
IPERF_PORT="9999"

source boot_vm_floating.sh

#!/bin/sh

NETNAME="admin_internal_net"
QDHCP="qdhcp-$(neutron net-list | grep $NETNAME | awk '{print $2}')"
OUTPUT="badips"
PING_ARGS="-c 1"
IMAGE_PASS="cubswin:)"

echo "" > $OUTPUT

all_ips=$(nova list | grep 'ACTIVE' | awk '{print $12}' | sed "s/$NETNAME=//g")

for ip in $all_ips; do
    for other_ip in $all_ips; do
        echo "ping $PING_ARGS $other_ip" | sudo ip netns e $QDHCP sshpass -p "$IMAGE_PASS" ssh cirros@$ip;
        if [ $? -eq 0 ]; then
            continue
        else
            echo "$other_ip can't be reached from $ip"
            echo "$ip->$other_ip" >> $OUTPUT
        fi
    done
done

echo "COULD NOT REACH: $(cat $OUTPUT)"

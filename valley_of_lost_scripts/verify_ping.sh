#!/bin/sh

NETNAME="admin_internal_net"
QDHCP="qdhcp-$(neutron net-list | grep $NETNAME | awk '{print $2}')"
OUTPUT="badips"
PING_ARGS="-c 1"

echo "" > $OUTPUT

for ip in $(nova list | grep 'ACTIVE' | awk '{print $12}' | sed "s/$NETNAME=//g"); do
    sudo ip netns e $QDHCP ping "$PING_ARGS" $ip
    if [ $? -eq 0 ]; then
        continue
    else
        echo "$ip can't be reached"
        echo "$ip" >> $OUTPUT
    fi
done

echo "COULD NOT REACH: $(cat $OUTPUT)"

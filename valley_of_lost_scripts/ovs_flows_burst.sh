#!/bin/sh

max_port=1025;
min_port=1023
remote_group=fake_sg_id;
SECURITY_GROUP_RULE_DATA="{'security_groups': [$SECURITY_GROUPS]}"
while true; do
    for pid in {tcp,udp}; 
    do
        echo "MAX PORT is $max_port";
        neutron security-group-rule-create --protocol=$pid fake_sg_id --port-range-max=$max_port --port-range-min=$min_port;
        if [ "$max_port" -lt "$min_port" ]; then
            echo "Finished!"
            exit;
        fi
        ((--max_port));
        echo "Total flows $(sudo ovs-ofctl dump-flows br-int | wc -l)";
    done
done

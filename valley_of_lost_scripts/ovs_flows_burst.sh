#!/bin/sh

max_port=1024;
min_port=512
remote_group=TESTIT;
SECURITY_GROUP_RULE_DATA="{'security_groups': [$SECURITY_GROUPS]}"
while true; do
    for pid in {tcp,udp}; 
    do
        echo "MAX PORT is $max_port";
        neutron security-group-rule-create --remote-group-id="$remote_group" --protocol=$pid fake_sg_id --port-range-max=$max_port --port-range-min=$min_port;
        if [ "$max_port" -lt "$min_port" ]; then
            echo "Finished!"
            return;
        fi
        ((--max_port));
        echo "Total flows $(sudo ovs-ofctl dump-flows br-int | wc -l)";
    done
done

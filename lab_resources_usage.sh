#!/bin/sh
# make sure that neutron-dev labs are present in /etc/hosts
# and can be sshed without password

# env name prefix to filter
ENVNAME="iv"
# a ci user who can ssh to SERVERS
USER="ivasilevskaya"
# a list of servers to gather data
SERVERS=(neutron-dev-1 neutron-dev-2 neutron-dev-3 neutron-dev-4)

# outputs data in csv format (server,env,vlans)
for s in "${SERVERS[@]}"; do
    for env in $(ssh "$USER@$s" "virsh list | grep $ENVNAME | awk '{print \$2}'"); do
        # filter out fuel-slaves
        if [[ "$env" =~ ^fuel-slave-* ]]; then
            continue;
        fi
        vlans=$(ssh "$USER@$s" "virsh dumpxml $env | xmllint --xpath \"/domain/devices/interface/vlan/tag/@id\" - 2>/dev/null | awk '{gsub(\"id=\",\"\",\$0); print \$0}' | xargs");
        macs=$(ssh "$USER@$s" "virsh dumpxml $env | xmllint --xpath \"//devices/interface/mac/@address\" - 2>/dev/null | awk '{gsub(\"address=\",\"\",\$0); print \$0}' | xargs");
        for mac in $macs; do
            # find first not none ip in broadcast messages
            mac_ok=$mac
            ip_ok=$(ssh "$USER@$s" "arp -an | grep $mac | grep -Po '\d+\.\d+\.\d+\.\d+'");
            if [[ $ip_ok ]]; then
                break
            fi
        done;
        if [[ $vlans ]]; then
            echo "$s (mac=$mac_ok, ip=$ip_ok, envname=$env, vlans=$vlans)";
        else
            echo "$s (mac=$mac_ok, ip=$ip_ok, envname=$env)";
        fi
    done;
done;


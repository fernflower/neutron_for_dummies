#!/bin/sh
# make sure that neutron-dev labs are present in /etc/hosts
# and can be sshed without password

# env name prefix to filter
ENVNAME="iv"
# a ci user who can ssh to SERVERS
USER="ivasilevskaya"
# a list of servers to gather data
SERVERS=(neutron-dev-3 neutron-dev-4)

# outputs data in csv format (server,env,vlans)
for s in "${SERVERS[@]}"; do
    for env in $(ssh "$USER@$s" "virsh list | grep $ENVNAME | awk '{print \$2}'"); do
        vlans=$(ssh "$USER@$s" "virsh dumpxml $env | xmllint --xpath \"/domain/devices/interface/vlan/tag/@id\" - 2>/dev/null | awk '{gsub(\"id=\",\"\",\$0); print \$0}' | xargs");
        echo "$s,$env,$vlans";
    done;
done;


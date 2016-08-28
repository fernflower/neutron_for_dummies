#!/bin/sh
# make sure that neutron-dev labs are present in /etc/hosts
# and can be sshed without password

# path to file with user configuration
USER_CONF="user.conf"

ENVNAME_PREFIX=$(awk -F "=" '/env_prefix/ {print $2}' $USER_CONF | xargs)
USER=$(awk -F "=" '/user/ {print $2}' $USER_CONF | xargs)
SERVERS=$(awk -F "=" '/dev_[0-9]/ {gsub("#","",$2); print $2}' $USER_CONF | xargs)

# outputs data in csv format (server,env,vlans)
for s in $SERVERS; do
    for env in $(ssh "$USER@$s" "virsh list | grep $ENVNAME_PREFIX | awk '{print \$2}'"); do
        # filter out fuel-slaves
        if [[ "$env" =~ ^fuel-slave-* ]]; then
            continue;
        fi
        # remove fuel-master prefix
        prefix="fuel-master-"
        name="$env"
        envname=${name#$prefix}

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
            echo "$s (ip=$ip_ok, envname=$envname, vlans=$vlans)";
        else
            echo "$s (ip=$ip_ok, envname=$envname)";
        fi
    done;
done;

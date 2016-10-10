#!/bin/sh
# make sure that neutron-dev labs are present in /etc/hosts
# and can be sshed without password

# If user config is not set as an argument to this script, then ci_cli directory is searched for user.conf
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
USER_CONF=${1:-"$DIR/user.conf"}

ENVNAME_PREFIX=$(awk -F "=" '/env_prefix/ {print $2}' $USER_CONF | xargs)
SSH_USER=$(awk -F "=" '/ssh_user/ {print $2}' $USER_CONF | xargs)
SERVERS=$(awk -F "=" '/dev_[0-9]/ {if (substr($1,1,1) == "#") {gsub("#","",$1); print $1;} else print $2}' $USER_CONF | xargs)

TMP_DIR="$DIR/.tmpenv"
REMOTE_TMP_DIR="/home/$SSH_USER/$TMP_DIR"

rm -rf $TMP_DIR;

# outputs data in csv format (server,env,vlans)
for s in $SERVERS; do
    for env in $(ssh "$SSH_USER@$s" "virsh list | grep $ENVNAME_PREFIX | awk '{print \$2}'"); do
        # filter out fuel-slaves
        if [[ "$env" =~ ^fuel-slave-* ]]; then
            continue;
        fi
        # remove fuel-master prefix
        prefix="fuel-master-"
        name="$env"
        envname=${name#$prefix}

        ssh "$SSH_USER@$s" "mkdir -p $REMOTE_TMP_DIR && virsh dumpxml $env > $REMOTE_TMP_DIR/dumpxml && virsh snapshot-list $env > $REMOTE_TMP_DIR/snapshot_list";
        scp -r "$SSH_USER@$s:$REMOTE_TMP_DIR" "$TMP_DIR" > /dev/null;

        vlans=$(cat $TMP_DIR/dumpxml | xmllint --xpath "/domain/devices/interface/vlan/tag/@id" - 2>/dev/null | awk '{gsub("id=","",$0); print $0}' | xargs);
        macs=$(cat $TMP_DIR/dumpxml | xmllint --xpath "//devices/interface/mac/@address" - 2>/dev/null | awk '{gsub("address=","",$0); print $0}' | xargs);
        snapshots=$(cat $TMP_DIR/snapshot_list | awk '{if (NR>=3) {print $1}}' | xargs | sed 's/ /,/g');
        for mac in $macs; do
            # find first not none ip in broadcast messages
            mac_ok=$mac
            ip_ok=$(ssh "$SSH_USER@$s" "arp -an | grep $mac | grep -Po '\d+\.\d+\.\d+\.\d+'");
            if [[ $ip_ok ]]; then
                break
            fi
        done;
        if [[ $vlans ]]; then
            echo "$s (ip=$ip_ok, envname=$envname, vlans=$vlans, snapshots=[$snapshots])";
        else
            echo "$s (ip=$ip_ok, envname=$envname, snapshots=[$snapshots])";
        fi
        # remove temp dir
        rm -rf $TMP_DIR;
    done;
done;

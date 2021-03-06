#USER=admin
#PASSWORD=admin
#HOST=172.16.55.195
#KEYSTONE_ENDPOINT=http://192.168.0.2:35357/v2.0
#TENANT_ID=bda495b375024c8eafbe4c671a964285
#REMOTE_SEC_GROUP_ID=e36a10cb-e654-4fdc-81c0-60841c507126
#SEC_GROUP_ID=c4293567-04f0-465d-af8f-af857eee0235
#START_PORT=${1:-42}
#INTERVAL=${2:-5}

#export http_proxy=10.20.0.5:8888
#export https_proxy=10.20.0.5:8888

USER=admin
PASSWORD=secretrabbit
HOST=172.18.171.22
KEYSTONE_ENDPOINT=http://172.18.171.22:35357/v2.0
TENANT_ID=$(openstack project list | grep '\sadmin' | awk '{print $2}')
REMOTE_SEC_GROUP_ID=$(neutron security-group-list | grep all_allowed_sg_id | awk '{print $2}')
SEC_GROUP_ID=$(neutron security-group-list | grep fake_sg_id | awk '{print $2}')
START_PORT=${1:-42}
INTERVAL=${2:-5}
IMG="cirros-0.3.4-x86_64-uec"
NETWORK_NAME="admin_internal_net"

function run {
    # form body
    python gen_sec_group_rules.py $SEC_GROUP_ID --min-port $START_PORT --max-port $(($START_PORT+$INTERVAL)) --protocol tcp --tenant-id $TENANT_ID --remote-group-id $REMOTE_SEC_GROUP_ID > body;
    BODY=$(cat body)

    # fetch token
    TOKEN_JSON=$(curl -O -X POST "$KEYSTONE_ENDPOINT/tokens" -H "Content-Type:application/json"  -d "{\"auth\":{\"passwordCredentials\":{\"username\": \"$USER\", \"password\": \"$PASSWORD\"}, \"tenantName\":\"admin\"}}");
    TOKEN=$(cat tokens | python -c "import sys, json; print json.load(open('tokens', 'r'))['access']['token']['id']");
    echo $TOKEN > token;

    curl -i -X POST -H "X-Auth-Token:$TOKEN" -H "Content-Type:application/json" "http://$HOST:9696/v2.0/security-group-rules" -d "@body";
}

function check_vm_boot {
    name="a-test-vm-to-delete";
    nova boot --image $IMG --flavor 1 --nic net-name=$NETWORK_NAME --security-group=$SEC_GROUP_ID "$name" --poll
    nova delete $name;
}

function cleanup {
    for f in [body,tokens,token]; do
        rm $f;
    done
}

run
check_vm_boot

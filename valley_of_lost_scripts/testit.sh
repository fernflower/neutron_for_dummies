USER=admin
PASSWORD=secretrabbit
HOST=172.18.171.22
TENANT_ID=c58b21aadf1d43008d270ea5e4237302
REMOTE_SEC_GROUP_ID=b98d86ff-32b1-4c24-a96a-98f8664e6f1f
SEC_GROUP_ID=4447b95d-9b02-4107-85d8-53f7711622af
START_PORT=81
INTERVAL=20

function run {
    # form body
    python gen_sec_group_rules.py $SEC_GROUP_ID --min-port $START_PORT --max-port $(($START_PORT+$INTERVAL)) --remote-group-id $REMOTE_SEC_GROUP_ID --tenant-id $TENANT_ID --protocol tcp > body;
    BODY=$(cat body)

    # fetch token
    TOKEN_JSON=$(curl -O -X POST "http://$HOST:35357/v2.0/tokens" -H "Content-Type:application/json"  -d "{\"auth\":{\"passwordCredentials\":{\"username\": \"$USER\", \"password\": \"$PASSWORD\"}}}");
    TOKEN=$(cat tokens | python -c "import sys, json; print json.load(open('tokens', 'r'))['access']['token']['id']");
    echo $TOKEN > token;

    curl -i -X POST -H "X-Auth-Token:$TOKEN" -H "Content-Type:application/json" "http://$HOST:9696/v2.0/security-group-rules" -d "@body";
}

function cleanup {
    for f in [body,tokens,token]; do
        rm $f;
    done
}

run

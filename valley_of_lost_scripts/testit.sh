USER=admin
PASSWORD=secretrabbit
HOST=172.18.171.22
TENANT_ID=c58b21aadf1d43008d270ea5e4237302

function run {
    # form body
    python gen_sec_group_rules.py fake_sg_id --max-port 4 --remote-group-id all_allowed_sg_id > body;
    BODY=$(cat body)

    # fetch token
    TOKEN_JSON=$(curl -O -X POST "http://$HOST:35357/v2.0/tokens" -H "Content-Type:application/json"  -d "{\"auth\":{\"passwordCredentials\":{\"username\": \"$USER\", \"password\": \"$PASSWORD\"}}}");
    TOKEN=$(cat tokens | python -c "import sys, json; print json.load(open('tokens', 'r'))['access']['token']['id']");

    curl -i -X POST -H "X-Auth-Token:$TOKEN" -H "Content-Type:application/json" "http://$HOST:9696/v2.0/security-groups?tenant_id=$TENANT_ID" -d "$BODY";
}

function cleanup {
    for f in [body,tokens]; do
        rm $f;
    done
}

run

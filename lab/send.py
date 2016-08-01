import argparse
import ast
import json
import logging
import requests
import time

CI_URL = "networking-ci.vm.mirantis.net"
MANAGE_URL = "http://%(ci)s:8080/job/manage-%(type)s_%(server)s/build"
COOKIES_PATH = ("/home/ina/.mozilla/firefox/b6ocijug.default/"
                "sessionstore-backups/recovery.js")

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)


# TODO(iva) should be an easier way to perform sso authentication
def _get_auth_cookies():
    """
    This implementation fetches cookies from Mozilla's recovery.js file
    and requires at least one window to CI_URL with user authorized to be open.
    """
    with open(COOKIES_PATH) as f:
        data = f.read()
    replace_map = {'true': "True",
                   'false': "False",
                   'null': "None"}
    for k, v in replace_map.iteritems():
        data = data.replace(k, v)
    data_dicts = ast.literal_eval(data)
    cookies_list = []
    for w in data_dicts["windows"]:
        cookies_list.extend([e for e in [c for c in w["cookies"]]
                             if e["host"] == CI_URL])
    return {c["name"]: c["value"] for c in cookies_list}


def main():
    parser = argparse.ArgumentParser()
    # TODO(iva) use subparser?
    parser.add_argument("server", choices=["dev_1", "dev_2", "dev_3", "dev_4"],
                        help="Server name")
    parser.add_argument("command", choices=["backup", "revert", "cleanup"],
                        help="Action to perform")
    parser.add_argument("env", help="Environment name")
    parser.add_argument("--name", help="Backup name")
    parser.add_argument("--type", choices=["cluster", "vm"],
                        help="Environment type, default to cluster",
                        default="cluster")
    parsed = parser.parse_args()
    if parsed.command == "backup":
        backup(server=parsed.server, env=parsed.env, bkp=parsed.name,
               vm_type=parsed.type)


def backup(server, env, bkp, vm_type):
    params = {"delay": "0sec"}
    if bkp is None:
        bkp = "bkp_%s" % time.time()
    data = {"DOMAIN": env,
            "SNAP_NAME": bkp,
            # TODO(iva) optional storage pool?
            "STORAGE_POOL": "big",
            "OPERATION": "snapshot-cluster"}
    data["json"] = json.dumps({"parameter": [{"name": k, "value": v}
                                             for k, v in data.iteritems()]})
    url = MANAGE_URL % {"server": server, "ci": CI_URL, "type": vm_type}
    cookies = _get_auth_cookies()
    r = requests.post(url, data=data, params=params, cookies=cookies)
    if r.status_code == 201:
        LOG.info("Success! Backup for %(env)s (%(bkp)s) on %(server)s "
                 "successfully started" % {"server": server, "env": env,
                                           "bkp": bkp})
    else:
        LOG.info(r.text)


if __name__ == "__main__":
    main()

import argparse
import ast
import ConfigParser
import json
import logging
import os
import requests
import time

CI_URL = "networking-ci.vm.mirantis.net"
DEPLOY_URL = "http://%(ci)s:8080/job/deploy_%(type)s_%(server)s/build"
MANAGE_URL = "http://%(ci)s:8080/job/manage-%(type)s_%(server)s/build"
COOKIES_PATH = ("/home/ina/.mozilla/firefox/b6ocijug.default/"
                "sessionstore-backups/recovery.js")
PUBLIC_KEY_PATH = "%(home)s/.ssh/id_rsa.pub" % {"home": os.environ["HOME"]}

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)


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


def envnameString(s):
    if not s.startswith(('dev_1:', 'dev_2:', 'dev_3:', 'dev_4:')):
        raise argparse.ArgumentTypeError("Environment name should be in format"
                                         " name:server")
    return s


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["backup-cluster", "backup-vm",
                                            "revert-cluster", "revert-vm",
                                            "cleanup-cluster", "cleanup-vm",
                                            "deploy-vm"],
                        help="Action to perform")
    parser.add_argument("env", help="Environment name in format 'server:name'",
                        type=envnameString)
    parser.add_argument("--snapshot", help="Snapshot name")
    parser.add_argument("--user", help="Jenkins API user")
    parser.add_argument("--token", help="Jenkins API token")
    parser.add_argument("--config", help="Configuration file for deploy job")
    parsed = parser.parse_args()
    auth_data = None
    vm_type = parsed.command.split('-')[1]
    server, env = parsed.env.split(':')
    if parsed.user and parsed.token:
        auth_data = {"user": parsed.user, "token": parsed.token}
    if parsed.command.startswith("backup"):
        backup(server=server, env=env, bkp=parsed.snapshot,
               vm_type=vm_type, auth_data=auth_data)
    elif parsed.command.startswith("revert"):
        revert(server=server, env=env, bkp=parsed.snapshot,
               vm_type=vm_type, auth_data=auth_data)
    elif parsed.command.startswith("cleanup"):
        cleanup(server=server, env=env, vm_type=vm_type,
                auth_data=auth_data)
    elif parsed.command.startswith("deploy"):
        # validate deploy-* command to have config parameter set
        if not parsed.config:
            LOG.error("'Config' parameter must be set for deploy-* job")
            return
        deploy(server=server, env=env, vm_type=vm_type, config=parsed.config,
               auth_data=auth_data)
    else:
        raise NotImplemented("Command %s not implemented yet" % parsed.command)


def revert(server, env, bkp, vm_type, auth_data):
    if bkp is None:
        LOG.error("Backup snapshot 'bkp' must be set for revert command!")
        return
    data = {"DOMAIN": env,
            "SNAP_NAME": bkp,
            # TODO(iva) optional storage pool?
            "STORAGE_POOL": "big",
            "OPERATION": "revert-%s" % vm_type}
    url = MANAGE_URL % {"server": server, "ci": CI_URL, "type": vm_type}
    _send_request(url, data, auth_data)


def backup(server, env, bkp, vm_type, auth_data):
    if bkp is None:
        bkp = "bkp_%s" % time.time()
    data = {"DOMAIN": env,
            "SNAP_NAME": bkp,
            # TODO(iva) optional storage pool?
            "STORAGE_POOL": "big",
            "OPERATION": "snapshot-%s" % vm_type}
    url = MANAGE_URL % {"server": server, "ci": CI_URL, "type": vm_type}
    _send_request(url, data, auth_data)


def cleanup(server, env, vm_type, auth_data):
    data = {"DOMAIN": env,
            "OPERATION": "cleanup-%s" % vm_type}
    url = MANAGE_URL % {"server": server, "ci": CI_URL, "type": vm_type}
    _send_request(url, data, auth_data)


# TODO(iva) cluster deploy with configurations?
def deploy(server, env, vm_type, config, auth_data):
    if vm_type != "vm":
        raise NotImplemented("Cluster deployments not supported yet")
    data = _data_from_config(config, env)
    url = DEPLOY_URL % {"server": server, "ci": CI_URL, "type": vm_type}
    _send_request(url, data, auth_data)


def _data_from_config(config, env):
    cfg = ConfigParser.ConfigParser()
    cfg.read(config)
    data = {k.upper(): v for k, v in cfg.items('default')}
    # TODO(iva) allow unknows argparse parameters to override those set in
    # config?
    with open(PUBLIC_KEY_PATH) as f:
        data["PUBLIC_KEY"] = f.read()
    data["DOMAIN"] = env
    return data


def _send_request(url, data, auth_data):
    params = {"delay": "0sec"}
    data["json"] = json.dumps({"parameter": [{"name": k, "value": v}
                                             for k, v in data.iteritems()]})
    # if user provides a token -> use it, otherwise try to find some cookies in
    # FF sessions backup file
    if not auth_data:
        r = requests.post(url, data=data, params=params,
                          cookies=_get_auth_cookies())
    else:
        r = requests.post(url, data=data, params=params,
                          auth=requests.auth.HTTPBasicAuth(auth_data['user'],
                                                           auth_data['token']))
    if r.status_code == 201:
        LOG.info("Success!")
    else:
        LOG.info(r.text)


if __name__ == "__main__":
    main()

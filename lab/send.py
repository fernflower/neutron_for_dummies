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
# TODO(iva) make it configurable?
PUBLIC_KEY_PATH = "%(home)s/.ssh/id_rsa.pub" % {"home": os.environ["HOME"]}

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)


def _envnameString(s):
    if not s.startswith(('dev_1:', 'dev_2:', 'dev_3:', 'dev_4:')):
        raise argparse.ArgumentTypeError("Environment name should be in format"
                                         " name:server")
    return s


def parse_args():
    """Parses arguments by argparse. Returns a tuple (known, unknown"""
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["backup-cluster", "backup-vm",
                                            "revert-cluster", "revert-vm",
                                            "cleanup-cluster", "cleanup-vm",
                                            "deploy-vm"],
                        help="Action to perform")
    parser.add_argument("env", help="Environment name in format 'server:name'",
                        type=_envnameString)
    parser.add_argument("--snapshot", help="Snapshot name")
    parser.add_argument("--user", help="Jenkins API user", required=True)
    parser.add_argument("--token", help="Jenkins API token", required=True)
    parser.add_argument("--config", help="Configuration file for deploy job")
    return parser.parse_known_args()


def main():
    parsed, unknown = parse_args()
    vm_type = parsed.command.split('-')[1]
    server, env = parsed.env.split(':')
    # turn unknown args into optional arguments
    # args should be passed as --OVERRIDE_ARGUMENT=VALUE
    override = dict(tuple(arg.split('=', 1))
                    for arg in [u.replace('--', '') for u in unknown])
    override["DOMAIN"] = env
    auth_data = {"user": parsed.user, "token": parsed.token}
    # TODO(iva) make other jobs utilize config/override args?
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
        deploy(server=server, vm_type=vm_type, config=parsed.config,
               auth_data=auth_data, override=override)
    else:
        raise NotImplemented("Command %s not implemented yet" % parsed.command)


def revert(server, env, bkp, vm_type, auth_data):
    if bkp is None:
        LOG.error("Backup snapshot 'bkp' must be set for revert command!")
        return
    data = {"DOMAIN": env,
            "SNAP_NAME": bkp,
            "STORAGE_POOL": "big",
            "OPERATION": "revert-%s" % vm_type}
    url = MANAGE_URL % {"server": server, "ci": CI_URL, "type": vm_type}
    _send_request(url, data, auth_data)


def backup(server, env, bkp, vm_type, auth_data):
    if bkp is None:
        bkp = "bkp_%s" % time.time()
    data = {"DOMAIN": env,
            "SNAP_NAME": bkp,
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
def deploy(server, vm_type, config, auth_data, override):
    if vm_type != "vm":
        raise NotImplemented("Cluster deployments not supported yet")
    data = _data_from_config(config, override=override)
    url = DEPLOY_URL % {"server": server, "ci": CI_URL, "type": vm_type}
    _send_request(url, data, auth_data)


def _data_from_config(config, override=None):
    """Transfer config values in data to be submitted.

       If override dictionary is passed, then the values from it override those
       in config.
    """
    cfg = ConfigParser.ConfigParser()
    cfg.read(config)
    data = {k.upper(): v for k, v in cfg.items('default')}
    # TODO(iva) make public_key a usual parameter and pass with override?
    if "PUBLIC_KEY" in data:
        with open(PUBLIC_KEY_PATH) as f:
            data["PUBLIC_KEY"] = f.read()
    if not override:
        return data
    for param in {k: v for k, v in override.iteritems() if k in data}:
        data[param] = override[param]
    # TODO(iva) any validation?
    return data


def _send_request(url, data, auth_data):
    params = {"delay": "0sec"}
    data["json"] = json.dumps({"parameter": [{"name": k, "value": v}
                                             for k, v in data.iteritems()]})
    r = requests.post(url, data=data, params=params,
                      auth=requests.auth.HTTPBasicAuth(auth_data['user'],
                                                       auth_data['token']))
    if r.status_code == 201:
        LOG.info("Success!")
    else:
        LOG.info(r.text)


if __name__ == "__main__":
    main()

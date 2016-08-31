import argparse
import ConfigParser
import json
import logging
import os
import requests
import sys
import time

CI_URL = "http://networking-ci.vm.mirantis.net:8080/job/%(job)s/build"
DIR = os.path.dirname(os.path.realpath(__file__))
USER_CONFIG = os.path.join(DIR, "user.conf")
CONF_MAP = {op: "%(dir)s/configurations/%(op)s" % {"dir": DIR, "op": op}
            for op in ['revert', 'cleanup', 'backup']}

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)


def _envnameString(s):
    if not s.startswith(('dev_1:', 'dev_2:', 'dev_3:', 'dev_4:')):
        raise argparse.ArgumentTypeError("Environment name should be in format"
                                         " name:server")
    return s


def _formUrl(job, server, vm_type):
    job = job.format(vm_type=vm_type, server=server)
    return CI_URL % {'job': job}


def parse_args():
    """Parses arguments by argparse. Returns a tuple (known, unknown"""
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["backup-cluster", "backup-vm",
                                            "revert-cluster", "revert-vm",
                                            "cleanup-cluster", "cleanup-vm",
                                            "deploy-vm", "deploy-cluster"],
                        help="Action to perform")
    parser.add_argument("env", help="Environment name in format 'server:name'",
                        type=_envnameString)
    parser.add_argument("--snapshot", help="Snapshot name")
    parser.add_argument("--user", help="Jenkins API user")
    parser.add_argument("--token", help="Jenkins API token")
    parser.add_argument("--config", help="Configuration file for deploy job")
    parser.add_argument("--user-config", help="User config file",
                        default=USER_CONFIG)
    return parser.parse_known_args()


def _parse_user_config(config):
    # check user config file exists
    if not os.path.exists(config):
        LOG.error("User config file %s does not exist. "
                  "Create one from sample config." % config)
        sys.exit(1)
    cfg = ConfigParser.ConfigParser()
    cfg.read(config)
    return {k: v for k, v in cfg.items('default')}


def main():
    parsed, unknown = parse_args()
    user_config = _parse_user_config(parsed.user_config)
    vm_type = parsed.command.split('-')[1]
    server, env = parsed.env.split(':')
    # if alias/ip is set in user config then override server name
    server = user_config.get(server, server)

    # turn unknown args into optional arguments
    # args should be passed as --OVERRIDE_ARGUMENT=VALUE
    def _convert_arg(arg):
        return arg.replace('-', '_').upper()

    override = dict((_convert_arg(arg.split('=', 1)[0]), arg.split('=')[1])
                    for arg in [u.replace('--', '') for u in unknown])
    override["DOMAIN"] = env
    if parsed.snapshot:
        override["SNAP_NAME"] = parsed.snapshot
    auth_data = {"user": user_config.get('user') or parsed.user,
                 "token": user_config.get('token') or parsed.token}
    if not all(auth_data[k] for k in auth_data):
        LOG.error("Both 'user' and 'token' parameters must be set")
        sys.exit(1)
    if parsed.command.startswith("deploy"):
        # validate deploy-* command to have config parameter set
        if not parsed.config:
            LOG.error("'Config' parameter must be set for deploy-* job")
            sys.exit(1)
        if not os.path.exists(parsed.config):
            LOG.error("Config file %s does not exist" % parsed.config)
            sys.exit(1)
        deploy(server=server, vm_type=vm_type, config=parsed.config,
               auth_data=auth_data, override=override)
    else:
        manage(parsed.command, server, vm_type, auth_data, override)


def manage(cmd, server, vm_type, auth_data, override):
    # op comes in form operation-type (ex. revert-cluster, deploy-vm)
    op = cmd.split('-')[0]
    if not override.get('SNAP_NAME'):
        if op == 'revert':
            LOG.error("Backup snapshot 'bkp' must be set for revert command!")
            sys.exit(1)
        elif op == 'backup':
            override['SNAP_NAME'] = "bkp_%s" % time.time()
    data = _data_from_config(CONF_MAP[op], server, override=override)
    job = data.pop('JOB')
    # TODO(iva) generalize formatting?
    data['OPERATION'] = data['OPERATION'].format(vm_type=vm_type)
    url = _formUrl(job, server, vm_type)
    _send_request(url, data, auth_data)


def deploy(server, vm_type, config, auth_data, override):
    data = _data_from_config(config, server, override=override)
    job = data.pop('JOB')
    url = _formUrl(job, server, vm_type)
    _send_request(url, data, auth_data)


def _data_from_config(config, server, override=None):
    """Transfer config values in data to be submitted.

       If override dictionary is passed, then the values from it override those
       in config.
    """
    cfg = ConfigParser.ConfigParser()
    cfg.read(config)
    data = {k.upper(): v for k, v in cfg.items('default')}
    if not override:
        return data
    for param in {k: v for k, v in override.iteritems() if k in data}:
        data[param] = override[param]
    # substitute public key file name for its contents
    if data.get("PUBLIC_KEY"):
        pubkey_file = os.path.expanduser(data["PUBLIC_KEY"])
        if os.path.exists(pubkey_file):
            with open(pubkey_file) as f:
                data["PUBLIC_KEY"] = f.read()
    # validate and choose proper job by checking [jenkins] session
    try:
        jenkins_data = {k.upper(): v for k, v in cfg.items('jenkins')}
        servers = jenkins_data.get('SERVERS')
        if servers and not (server in [s.strip() for s in servers.split(',')]):
            LOG.error("This configuration file may be used for servers "
                      "%(servers)s only, not %(server)s" % {'servers': servers,
                                                            'server': server})
            sys.exit(1)
        if jenkins_data.get('JOB'):
            data['JOB'] = jenkins_data['JOB']

    except ConfigParser.NoSectionError:
        LOG.error("[jenkins] section not found in %s" % config)
        sys.exit(1)
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

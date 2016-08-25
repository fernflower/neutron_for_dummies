import argparse
import ConfigParser
import json
import logging
import os
import requests
import sys
import time

CI_URL = "http://networking-ci.vm.mirantis.net:8080/job/%(job)s/build"
DEPLOY_JOB = "deploy_%(type)s_%(server)s"
MANAGE_JOB = "manage-%(type)s_%(server)s"

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)


def _envnameString(s):
    if not s.startswith(('dev_1:', 'dev_2:', 'dev_3:', 'dev_4:')):
        raise argparse.ArgumentTypeError("Environment name should be in format"
                                         " name:server")
    return s


def _formUrl(job, server, vm_type):
    if vm_type == 'cluster' and job.startswith('deploy_9.x_'):
        # XXX special case until job names are unified
        server = server.replace('_', '')
        job = job.format(vm_type=vm_type, server=server)
    else:
        job = job % {'server': server, 'type': vm_type}
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
    def _convert_arg(arg):
        return arg.replace('-', '_').upper()

    override = dict((_convert_arg(arg.split('=', 1)[0]), arg.split('=')[1])
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
            sys.exit(1)
        if not os.path.exists(parsed.config):
            LOG.error("Config file %s does not exist" % parsed.config)
            sys.exit(1)
        deploy(server=server, vm_type=vm_type, config=parsed.config,
               auth_data=auth_data, override=override)
    else:
        raise NotImplemented("Command %s not implemented yet" % parsed.command)


def revert(server, env, bkp, vm_type, auth_data):
    if bkp is None:
        LOG.error("Backup snapshot 'bkp' must be set for revert command!")
        sys.exit(1)
    data = {"DOMAIN": env,
            "SNAP_NAME": bkp,
            "STORAGE_POOL": "big",
            "OPERATION": "revert-%s" % vm_type}
    url = _formUrl(MANAGE_JOB, server, vm_type)
    _send_request(url, data, auth_data)


def backup(server, env, bkp, vm_type, auth_data):
    if bkp is None:
        bkp = "bkp_%s" % time.time()
    data = {"DOMAIN": env,
            "SNAP_NAME": bkp,
            "STORAGE_POOL": "big",
            "OPERATION": "snapshot-%s" % vm_type}
    url = _formUrl(MANAGE_JOB, server, vm_type)
    _send_request(url, data, auth_data)


def cleanup(server, env, vm_type, auth_data):
    data = {"DOMAIN": env,
            "OPERATION": "cleanup-%s" % vm_type}
    url = _formUrl(MANAGE_JOB, server, vm_type)
    _send_request(url, data, auth_data)


def deploy(server, vm_type, config, auth_data, override):
    data = _data_from_config(config, server, override=override)
    job = data.pop('JOB', DEPLOY_JOB)
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
        servers = jenkins_data.get('servers')
        if servers and not (server in [s.strip() for s in
                                       jenkins_data['servers'].split(',')]):
            LOG.error("This configuration file may be used for servers"
                      "%(servers)s only, not %(server)s" % {'servers': servers,
                                                            'server': server})
            sys.exit(1)
        if jenkins_data.get('JOB'):
            data['JOB'] = jenkins_data['JOB']

    except ConfigParser.NoSectionError:
        # no section -> no validation
        pass
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

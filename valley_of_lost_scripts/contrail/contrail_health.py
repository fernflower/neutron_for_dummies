import subprocess
import sys


CMD = "contrail-status"
SERVICE_EXTRA_STATES = {'contrail-schema': 'backup',
                        'contrail-svc-monitor': 'backup',
                        'contrail-device-manager': 'backup'}

def check(output=sys.stdout):
    cmd = subprocess.check_output(CMD.split(' '))
    result = {}
    for l in [l.strip() for l in cmd.split('\n') if l.strip() != '']:
        if l.startswith('=='):
            # role detected
            role = l.strip('==').strip().replace(' ', '_')
            result[role] = []
        else:
            state_info = [a for a in l.split(' ') if a != '']
            service = state_info[0].split(':')[0]
            status = ("%s %s" % (state_info[1], " ".join(state_info[2:]))
                      if len(state_info) > 2 else state_info[1])
            if status != 'active' and SERVICE_EXTRA_STATES.get(service) != status:
                exit_code = 1
            else:
                exit_code = 0
            result[role].append({'service': service, 'status': status,
                                 'exit_code': exit_code})
    # output all collected info
    # NOTE(ivasilevskaya) ignore contrail database in favor of supervisor
    # database
    result.pop('Contrail_Database', None)
    for role, services in result.iteritems():
        for info in services:
            output.write(("%(workload)s,service=%(service)s "
                          "exit_code=%(exit_code)s role=%(role)s\n") %
                          {'workload': 'workload_contrail_health',
                           'service': info['service'],
                           'exit_code': info['exit_code'],
                           'role': role})
    return result


if __name__ == "__main__":
    check()
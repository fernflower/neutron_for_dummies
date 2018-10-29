import subprocess
import sys


CMD = "doctrail all contrail-status"
SERVICE_EXTRA_STATES = {'contrail-schema': 'backup',
                        'contrail-svc-monitor': 'backup',
                        'contrail-device-manager': 'backup'}


def check(output=sys.stdout):
    cmd = subprocess.check_output(CMD.split(' '))
    status_map = dict(tuple([s.strip() for s in l.split(':', 1)])
                      for l in cmd.split('\n') if l.rfind(':') >= 0)
    result = []
    for service, status in status_map.iteritems():
        if status != 'active' and SERVICE_EXTRA_STATES.get(service) != status:
            exit_code = 1
        else:
            exit_code = 0
        result.append({'service': service, 'status': status,
                       'exit_code': exit_code,
                       'workload': 'workload_contrail_health'})
    # output all collected info
    for r in result:
        output.write(("%(workload)s,service=%(service)s "
                      "exit_code=%(exit_code)s\n") % r)

if __name__ == "__main__":
    check()

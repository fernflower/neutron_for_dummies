import sys
from vnc_api import vnc_api


def check(output=sys.stdout):
    vnc_cli = vnc_api.VncApi(conf_file='/etc/contrail/vnc_api_lib.ini')
    try:
        out = vnc_cli._objects_list('global-vrouter-config')
        exit_code = 0 if len(out.get('global-vrouter-configs', [])) > 0 else 1
    # XXX FIXME narrow down exception type
    except Exception:
        exit_code = 1
    res = {'workload': 'workload_contrail_global_vrouter_config_present',
           'exit_code': exit_code}
    # output result
    output.write('%(workload)s,exit_code=%(exit_code)s\n' % res)


if __name__ == "__main__":
    check()

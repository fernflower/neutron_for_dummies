import argparse
import json
import sys


def _parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--min-port', type=int, default=1)
    parser.add_argument('--max-port', type=int, default=65535)
    parser.add_argument('--protocol', choices=['icmp', 'udp', 'tcp'])
    parser.add_argument('--remote-group-id')
    parser.add_argument('--direction', default='ingress')
    parser.add_argument('--tenant-id', default=None)
    parser.add_argument('security_group_id')
    args = parser.parse_args()
    if args.max_port < args.min_port:
        sys.exit("max_port should be greater than min_port, exiting")
    return args

def _create_sg(args):
    # create security group
    sg = {}
    sg['security_group'] = {'name': args.security_group_id,
                            'description': 'Flow flood security group',
                            'tenant_id': args.tenant_id}
    return sg

def _gen_body(args):
    rules = []
    for port_start in range(args.min_port, args.max_port + 1):
        for port_end in range(args.max_port, port_start - 1, -1):
            new_rule = {'security_group_rule': {}}
            new_rule['security_group_rule']['port_range_min'] = port_start
            new_rule['security_group_rule']['port_range_max'] = port_end
            if args.tenant_id:
                new_rule['security_group_id']['tenant_id'] = args.tenant_id
            for val in ['direction', 'protocol', 'remote_group_id',
                        'security_group_id']:
                new_rule['security_group_rule'][val] = getattr(args, val)
            rules.append(new_rule)
    data = {'security_group_rules': rules}
    return data


def main():
    args = _parse_args()
    body = _gen_body(args)
    print json.dumps(body, indent=2)


if __name__ == "__main__":
    main()

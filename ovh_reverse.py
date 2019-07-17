#!/usr/bin/env python
# -*- encoding: utf-8 -*-

'''
First, install the latest release of Python wrapper: $ pip install ovh
Usage: ovh_reverse IP FQDN
'''

import os
import sys
import json
import ovh

ip = sys.argv[1]
fqdn = sys.argv[2]

# Instanciate an OVH Client. use your ovh.conf
client = ovh.Client()

try:
    result = client.post('/ip/%s/reverse/' % ip,
                        ipReverse=ip,
                        reverse=fqdn)
    print json.dumps(result, indent=4) # Pretty print
except (ovh.exceptions.BadParametersError,
        ovh.exceptions.ResourceConflictError) as e:
    print e



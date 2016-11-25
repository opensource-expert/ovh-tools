#!/usr/bin/env python
# -*- encoding: utf-8 -*-

'''
First, install the latest release of Python wrapper: $ pip install ovh
#Call : ovh_snapshot.py <instanceId> <snapshotName>
'''

import os
import sys
import json
import ovh

# Instanciate an OVH Client.
# You can generate new credentials with full access to your account on
# the token creation page
client = ovh.Client(
    endpoint='ovh-eu',               # Endpoint of API OVH Europe (List of available endpoints)
    application_key=os.environ['OVH_APPLICATION_KEY'],    # Application Key
    application_secret=os.environ['OVH_APPLICATION_SECRET'], # Application Secret
    consumer_key=os.environ['OVH_CONSUMER_KEY'],       # Consumer Key
)

result = client.post('/cloud/project/'
                    + os.environ['OVH_SERVICE_NAME']
                    + '/instance/'
                    + sys.argv[1]
                    + '/snapshot',
                    snapshotName=sys.argv[2], # Snapshot name (type: string)
)

print json.dumps(result, indent=4) # Pretty print

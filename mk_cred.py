#!/usr/bin/python -tt
# -*- coding: utf-8 -*-
# vim: set et ts=2 sw=2 sts=2:
#
# Usage:
#   python mk_cred.py < copy_paste_credential.txt
#   python mk_cred.py update
#   python mk_cred.py new | init
#   python mk_cred.py update_key CONSUMER_KEY
#   python mk_cred.py bash_export
#
# actions:
#
# stdin parser
#   copy_paste_credential.txt is the text ouputed by:
#   https://eu.api.ovh.com/createApp/
#
# NO_ACTION    Displays help message
# new          Create a new credential file
# update       Request current credential update with the local ovh.conf
# update_key   Update the local ovh.conf with CONSUMER_KEY
# bash_export  Output ovh.conf as bash export VARIABLES

from __future__ import print_function

import sys
import re
import os
import fileinput
import ovh
from ovh import config

# pip install --user Jinja2
from jinja2 import Environment, FileSystemLoader

re.UNICODE
re.LOCALE

# Request full API access
access_rules = [
    {'method': 'GET', 'path': '/*'},
    {'method': 'POST', 'path': '/*'},
    {'method': 'PUT', 'path': '/*'},
    {'method': 'DELETE', 'path': '/*'}
]

def parse_input():
  d = {
    'application_key' : None,
    'application_secret' : None,
    'consumer_key' : None
  }

  # parse input
  # lines are all stored in a buffer for forward reading
  lines = sys.stdin.readlines()
  i = 0
  n = len(lines)
  while i < n:
    i += 1
    l = lines[i-1].rstrip()

    if l == '':
      # skip empty line
      next

    # TODO: make it DRY
    if re.search(r'Application Key', l):
      # key is on the next line
      d['application_key'] = lines[i+1].rstrip()
      i += 2

    if re.search(r'Application Secret', l):
      # key is on the next line
      d['application_secret'] = lines[i+1].rstrip()
      i += 2

    if re.search(r'Consumer Key', l):
      # key is on the next line
      d['consumer_key'] = lines[i+1].rstrip()
      i += 2

  return d

def update_consumer_key(conffile, consumer_key):
  for line in fileinput.FileInput(conffile, inplace=1):
      if re.match(r'consumer_key=', line):
        line = "consumer_key=%s\n" % consumer_key
      print(line, end='')
  print("updated in '%s'"%conffile)


def init_app():
  url = "https://eu.api.ovh.com/createApp/"
  print("go to '%s' and register your app, then copy/paste text here + CTRL-D" % url)

  d = parse_input()

  client = ovh.Client(
      endpoint='ovh-eu',
      application_key=d['application_key'],
      application_secret=d['application_secret'],
      consumer_key=None
  )

  # Request token
  d['consumer_key'] = generate_consumer_key(client)

  env = Environment(loader=FileSystemLoader('./templates'))
  template = env.get_template('ovh_t.conf')
  tmp = 'ovh_conf.tmp'
  f = open(tmp, 'w')
  f.write(template.render(d))
  f.close()
  print("file written '%s', you have to copy or rename to ovh.conf" % tmp)

def generate_consumer_key(client = None):
  if client == None:
    # log with current ovh.conf
    client = ovh.Client()

  # Request token
  try:
    validation = client.request_consumerkey(access_rules)
  except ovh.exceptions.APIError as e:
    print(e)
    return None

  print("Please visit %s to authenticate" % validation['validationUrl'])
  raw_input("and press Enter to continue...")

  # Print nice welcome message
  print("Welcome", client.get('/me')['firstname'])
  print("Here is your Consumer Key: '%s'" % validation['consumerKey'])

  return validation['consumerKey']


def bash_export(client = None):
  d = {
    'application_key' : None,
    'application_secret' : None,
    'consumer_key' : None
  }

  # format for https://github.com/toorop/ovh-cli
  for k in d.keys():
    print("export OVH_%s=%s" % (
        k.upper(),
        ovh.config.config.get('ovh-eu', k)
        )
      )

  print("# format fo https://github.com/denouche/ovh-api-bash-client")
  d = {
    'application_key' : 'AK',
    'application_secret' : 'AS',
    'consumer_key' : 'CK'
  }
  for k in d.keys():
    print("export %s=%s" % (
        d[k],
        ovh.config.config.get('ovh-eu', k)
        )
      )

################################## main
if __name__ == '__main__':
  if len(sys.argv) == 1:
    print("no arg, can be: update_key | update | new")
  elif sys.argv[1] == 'update_key':
    # simply write a key in local ovh.conf
    consumer_key = sys.argv[2]
    update_consumer_key('ovh.conf', consumer_key)
  elif sys.argv[1] == 'new' or sys.argv[1] == 'init':
    init_app()
  elif sys.argv[1] == 'update':
    consumer_key = generate_consumer_key()
    if consumer_key != None:
      update_consumer_key('ovh.conf', consumer_key)
    else:
      print('some error with application key, nothing changed')
  elif sys.argv[1] == 'bash_export':
    bash_export()


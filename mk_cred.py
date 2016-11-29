#!/usr/bin/python -tt
# -*- coding: utf-8 -*-
# vim: set et ts=2 sw=2 sts=2:
#
# Usage: python mk_cred.py < copy_paste_credential.txt
# copy_paste_credential.txt is the text ouputed by:
# https://eu.api.ovh.com/createApp/
#

import sys
import re
import os
import fileinput
import ovh

# pip install --user Jinja2
from jinja2 import Environment, FileSystemLoader

re.UNICODE
re.LOCALE

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



def main():
  url = "https://eu.api.ovh.com/createApp/"
  print "go to '%s' and register your app, then paste text here + CTRL-D" % url
  d = parse_input()
  env = Environment(loader=FileSystemLoader('./templates'))
  template = env.get_template('ovh_t.conf')

  # Request full API access
  access_rules = [
      {'method': 'GET', 'path': '/*'},
      {'method': 'POST', 'path': '/*'},
      {'method': 'PUT', 'path': '/*'},
      {'method': 'DELETE', 'path': '/*'}
  ]

  client = ovh.Client(
      endpoint='ovh-eu',
      application_key=d['application_key'],
      application_secret=d['application_secret'],
      consumer_key=None
  )

  # Request token
  validation = client.request_consumerkey(access_rules)

  print "Please visit %s to authenticate" % validation['validationUrl']
  raw_input("and press Enter to continue...")

  # Print nice welcome message
  print "Welcome", client.get('/me')['firstname']
  #print "Here is your Consumer Key: '%s'" % validation['consumerKey']

  d['consumer_key'] = validation['consumerKey']
  tmp = 'ovh_conf.tmp'
  f = open(tmp, 'w')
  f.write(template.render(d))
  f.close()
  print "file written '%s', you have to copy or rename to ovh.conf" % tmp


if __name__ == '__main__':
  main()


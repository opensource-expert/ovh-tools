#!/bin/bash

load_var() {
  awk -F= "/^$1=/ { print \$2 }" ovh.conf
}

export OVH_APPLICATION_KEY=$(load_var application_key)
export OVH_APPLICATION_SECRET=$(load_var application_secret)
export OVH_CONSUMER_KEY=$(load_var consumer_key)
export OVH_SERVICE_NAME=Your_cloud_proect_id


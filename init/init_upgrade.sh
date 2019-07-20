#!/bin/bash
# upgrade
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y > /root/upgrade.log
DEBIAN_FRONTEND=noninteractive apt-get install -y vim tree git less >> /root/install.log

#! /usr/bin/env bash

#
# Script for build the image. Used builder script of the target repo
# For build: docker run --privileged -it --rm -v /dev:/dev -v $(pwd):/builder/repo smirart/builder
#
# Copyright (C) 2018 Copter Express Technologies
#
# Author: Artem Smirnov <urpylka@gmail.com>
#

set -e # Exit immidiately on non-zero result

echo_stamp() {
  # TEMPLATE: echo_stamp <TEXT> <TYPE>
  # TYPE: SUCCESS, ERROR, INFO

  # More info there https://www.shellhacks.com/ru/bash-colors/

  TEXT="$(date '+[%Y-%m-%d %H:%M:%S]') $1"
  TEXT="\e[1m$TEXT\e[0m" # BOLD

  case "$2" in
    SUCCESS)
    TEXT="\e[32m${TEXT}\e[0m";; # GREEN
    ERROR)
    TEXT="\e[31m${TEXT}\e[0m";; # RED
    *)
    TEXT="\e[34m${TEXT}\e[0m";; # BLUE
  esac
  echo -e ${TEXT}
}

echo_stamp "Rename SSID"
NEW_SSID='RAW-WIFI-TX-'$(head -c 100 /dev/urandom | xxd -ps -c 100 | sed -e "s/[^0-9]//g" | cut -c 1-4)
sudo sed -i.OLD "s/RAW-WIFI-TX/${NEW_SSID}/" /etc/wpa_supplicant/wpa_supplicant-wlan1.conf
tx_rename ${NEW_SSID}

echo_stamp "Harware setup"
/root/hardware_setup.sh

# TODO: Find a normal solution to build it in chroot
echo_stamp "Build rtl8812au (!THIS WILL TAKE A WHILE!)"
cd /home/pi/rtl8812au \
&& git status \
&& ./dkms-install.sh \
|| (echo_stamp "Failed to build rtl8812au!" "ERROR"; exit 1)

echo_stamp "Register rtl8812au kernel module"
echo "88XXau" >> /etc/modules \
|| (echo_stamp "Failed to register rtl8812au kernel module!" "ERROR"; exit 1)

echo_stamp "Remove init scripts"
rm /root/init_rpi.sh /root/hardware_setup.sh

echo_stamp "End of initialization of the image"

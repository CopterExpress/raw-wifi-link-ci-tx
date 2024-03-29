#! /usr/bin/env bash

#
# Script for build the image. Used builder script of the target repo
# For build: docker run --privileged -it --rm -v /dev:/dev -v $(pwd):/builder/repo smirart/builder
#
# Copyright (C) 2019 Copter Express Technologies
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

##################################################
# Configure hardware interfaces
##################################################

# 1. Enable sshd
echo_stamp "#1 Turn on sshd"
touch /boot/ssh
# /usr/bin/raspi-config nonint do_ssh 0

# 2. Enable GPIO
echo_stamp "#2 GPIO enabled by default"

# 3. Enable I2C
echo_stamp "#3 Turn on I2C"
/usr/bin/raspi-config nonint do_i2c 0

# 4. Enable SPI
echo_stamp "#4 Turn on SPI"
/usr/bin/raspi-config nonint do_spi 0

# 5. Enable raspicam
echo_stamp "#5 Turn on raspicam"
/usr/bin/raspi-config nonint do_camera 0

# 6. Enable predictable network interface names
echo_stamp "#6 Enable predictable network interface names"
/usr/bin/raspi-config nonint do_net_names 0

# 7. Enable hardware UART
# echo_stamp "#7 Turn on UART"
# Temporary solution
# https://github.com/RPi-Distro/raspi-config/pull/75
# /usr/bin/raspi-config nonint do_serial 1
# /usr/bin/raspi-config nonint set_config_var enable_uart 1 /boot/config.txt
#/usr/bin/raspi-config nonint set_config_var dtoverlay pi3-disable-bt /boot/config.txt
systemctl disable hciuart.service

# After adding to Raspbian OS
# https://github.com/RPi-Distro/raspi-config/commit/d6d9ecc0d9cbe4aaa9744ae733b9cb239e79c116
#/usr/bin/raspi-config nonint do_serial 2

echo_stamp "#8 End of configure hardware interfaces"

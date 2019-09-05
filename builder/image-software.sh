#! /usr/bin/env bash

#
# Script for install software to the image.
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
  TEXT="\e[1m${TEXT}\e[0m" # BOLD

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

# https://gist.github.com/letmaik/caa0f6cc4375cbfcc1ff26bd4530c2a3
# https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/templates/header.sh
my_travis_retry() {
  local result=0
  local count=1
  while [ $count -le 3 ]; do
    [ $result -ne 0 ] && {
      echo -e "\n${ANSI_RED}The command \"$@\" failed. Retrying, $count of 3.${ANSI_RESET}\n" >&2
    }
    # ! { } ignores set -e, see https://stackoverflow.com/a/4073372
    ! { "$@"; result=$?; }
    [ $result -eq 0 ] && break
    count=$(($count + 1))
    sleep 1
  done

  [ $count -gt 3 ] && {
    echo -e "\n${ANSI_RED}The command \"$@\" failed 3 times.${ANSI_RESET}\n" >&2
  }

  return $result
}

echo_stamp "Update apt"
apt-get update
#&& apt upgrade -y

echo_stamp "Upgrade kernel"
apt-get install -y --only-upgrade raspberrypi-kernel raspberrypi-bootloader \
|| (echo_stamp "Failed to upgrade kernel!" "ERROR"; exit 1)

echo_stamp "Software installing"
apt-get install --no-install-recommends -y \
unzip \
zip \
screen \
byobu  \
lsof \
git \
dnsmasq \
tmux \
vim \
cmake \
ltrace \
build-essential \
pigpio python-pigpio \
i2c-tools \
ntpdate \
python-dev \
libxml2-dev \
libxslt-dev \
python-future \
python-lxml \
mc \
libboost-system-dev \
libboost-program-options-dev \
libboost-thread-dev \
libreadline-dev \
socat \
dnsmasq \
autoconf \
automake \
libtool \
python3-future \
libpcap-dev \
wiringpi \
libsodium-dev \
libopencv-dev \
libusb-1.0-0-dev \
libsystemd-dev \
libexiv2-dev \
libv4l-dev \
v4l2loopback-dkms \
gstreamer1.0-tools \
gstreamer1.0-plugins-good \
gstreamer1.0-plugins-bad \
gstreamer1.0-omx \
ntfs-3g \
raspberrypi-kernel-headers \
&& echo_stamp "Everything was installed!" "SUCCESS" \
|| (echo_stamp "Some packages wasn't installed!" "ERROR"; exit 1)

# echo_stamp "Updating kernel to fix camera bug"
# apt-get install --no-install-recommends -y raspberrypi-kernel=1.20190401-1

# Deny byobu to check available updates
sed -i "s/updates_available//" /usr/share/byobu/status/status
# sed -i "s/updates_available//" /home/pi/.byobu/status

echo_stamp "Installing pip"
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
rm get-pip.py
#my_travis_retry pip install --upgrade pip
#my_travis_retry pip3 install --upgrade pip

echo_stamp "Make sure both pip is installed"
pip --version

echo_stamp "Install usbmount"
cd /home/pi \
&& wget https://github.com/nicokaiser/usbmount/releases/download/0.0.24/usbmount_0.0.24_all.deb \
&& apt install --no-install-recommends -y ./usbmount_0.0.24_all.deb \
&& rm ./usbmount_0.0.24_all.deb \
|| (echo_stamp "Failed to install usbmount pymavlink!" "ERROR"; exit 1)

echo_stamp "Check MAVLink repository status"
cd /home/pi/mavlink && \
git status

echo_stamp "Build pymavlink"
my_travis_retry pip install -r /home/pi/pymavlink/requirements.txt && \
cd /home/pi/pymavlink && \
git status && \
MDEF=/home/pi/mavlink/message_definitions pip2 install . -v \
|| (echo_stamp "Failed to build pymavlink!" "ERROR"; exit 1)

# echo_stamp "Build mavlink-router"
# cd /home/pi/mavlink-router \
# && git status \
# && mkdir build \
# && ./autogen.sh \
# && ./configure CFLAGS='-g -O2' \
#   --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 \
#   --prefix=/usr \
# && make -j4 \
# && make install \
# || (echo_stamp "Failed to build mavlink-router!" "ERROR"; exit 1)

echo_stamp "Build raw-wifi-link"
cd /home/pi/raw-wifi-link \
&& git status \
&& mkdir build \
&& cd build \
&& cmake .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build raw-wifi-link!" "ERROR"; exit 1)

echo_stamp "Build spdlog"
cd /home/pi/spdlog \
&& git status \
&& mkdir build \
&& cd build \
&& cmake -DSPDLOG_BUILD_BENCH=OFF -DSPDLOG_BUILD_TESTS=OFF .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build spdlog!" "ERROR"; exit 1)

echo_stamp "Build yaml-cpp"
cd /home/pi/yaml-cpp \
&& git status \
&& mkdir build \
&& cd build \
&& cmake -DYAML_CPP_BUILD_TESTS=OFF .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build yaml-cpp!" "ERROR"; exit 1)

echo_stamp "Build cxxopts"
cd /home/pi/cxxopts \
&& git status \
&& mkdir build \
&& cd build \
&& cmake -DCXXOPTS_BUILD_EXAMPLES=OFF -DCXXOPTS_BUILD_TESTS=OFF .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build cxxopts!" "ERROR"; exit 1)

echo_stamp "Build libseek-thermal"
cd /home/pi/libseek-thermal \
&& git status \
&& mkdir build \
&& cd build \
&& cmake .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build libseek-thermal!" "ERROR"; exit 1)

echo_stamp "Build raspicam"
cd /home/pi/raspicam \
&& git status \
&& mkdir build \
&& cd build \
&& cmake .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build raspicam!" "ERROR"; exit 1)

echo_stamp "Build duocam-camera"
cd /home/pi/duocam-camera \
&& git status \
&& mkdir build \
&& cd build \
&& cmake .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build duocam-camera!" "ERROR"; exit 1)

echo_stamp "Build duocam-mavlink"
cd /home/pi/duocam-mavlink \
&& git status \
&& mkdir build \
&& cd build \
&& cmake -DNO_EXAMPLES=ON .. \
&& make -j4 \
&& make install \
|| (echo_stamp "Failed to build duocam-mavlink!" "ERROR"; exit 1)

echo_stamp "Reconfigure shared objects"
ldconfig \
|| (echo_stamp "Failed to reconfigure shared objects!" "ERROR"; exit 1)

echo_stamp "Register v4l2loopback kernel module"
echo "v4l2loopback" >> /etc/modules \
|| (echo_stamp "Failed to register v4l2loopback kernel module!" "ERROR"; exit 1)

echo_stamp "Add .vimrc"
cat << EOF > /home/pi/.vimrc
set mouse-=a
syntax on
autocmd BufNewFile,BufRead *.launch set syntax=xml
EOF

echo_stamp "Change default keyboard layout to US"
sed -i 's/XKBLAYOUT="gb"/XKBLAYOUT="us"/g' /etc/default/keyboard

echo_stamp "Enable services"

echo_stamp "End of software installation"

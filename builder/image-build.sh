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

SOURCE_IMAGE="http://director.downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-07-12/2019-07-10-raspbian-buster-lite.zip"

export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:='noninteractive'}
export LANG=${LANG:='C.UTF-8'}
export LC_ALL=${LC_ALL:='C.UTF-8'}

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

BUILDER_DIR="/builder"
REPO_DIR="${BUILDER_DIR}/repo"
SCRIPTS_DIR="${REPO_DIR}/builder"
IMAGES_DIR="${REPO_DIR}/images"
LIB_DIR="${REPO_DIR}/lib"

[[ ! -d ${SCRIPTS_DIR} ]] && (echo_stamp "Directory ${SCRIPTS_DIR} doesn't exist" "ERROR"; exit 1)
[[ ! -d ${IMAGES_DIR} ]] && mkdir ${IMAGES_DIR} && echo_stamp "Directory ${IMAGES_DIR} was created successful" "SUCCESS"

if [[ -z ${TRAVIS_TAG} ]]; then IMAGE_VERSION="$(cd ${REPO_DIR}; git log --format=%h -1)"; else IMAGE_VERSION="${TRAVIS_TAG}"; fi
# IMAGE_VERSION="${TRAVIS_TAG:=$(cd ${REPO_DIR}; git log --format=%h -1)}"
REPO_URL="$(cd ${REPO_DIR}; git remote --verbose | grep origin | grep fetch | cut -f2 | cut -d' ' -f1 | sed 's/git@github\.com\:/https\:\/\/github.com\//')"
REPO_NAME="ros_cs"
IMAGE_NAME="${REPO_NAME}_${IMAGE_VERSION}.img"
IMAGE_PATH="${IMAGES_DIR}/${IMAGE_NAME}"

get_image() {
  # TEMPLATE: get_image <IMAGE_PATH> <RPI_DONWLOAD_URL>
  local BUILD_DIR=$(dirname $1)
  local RPI_ZIP_NAME=$(basename $2)
  local RPI_IMAGE_NAME=$(echo ${RPI_ZIP_NAME} | sed 's/zip/img/')

  if [ ! -e "${BUILD_DIR}/${RPI_ZIP_NAME}" ]; then
    echo_stamp "Downloading original Linux distribution"
    wget --progress=dot:giga -O ${BUILD_DIR}/${RPI_ZIP_NAME} $2
    echo_stamp "Downloading complete" "SUCCESS" \
  else echo_stamp "Linux distribution already donwloaded"; fi

  echo_stamp "Unzipping Linux distribution image" \
  && unzip -p ${BUILD_DIR}/${RPI_ZIP_NAME} ${RPI_IMAGE_NAME} > $1 \
  && echo_stamp "Unzipping complete" "SUCCESS" \
  || (echo_stamp "Unzipping was failed!" "ERROR"; exit 1)
}

get_image ${IMAGE_PATH} ${SOURCE_IMAGE}

# Make free space
${BUILDER_DIR}/image-resize.sh ${IMAGE_PATH} max '7G'

# Temporary disable ld.so
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} exec ${SCRIPTS_DIR}'/image-ld.sh' disable

# Copy cloned repository to the image
# Include dotfiles in globs (asterisks)
shopt -s dotglob

${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${SCRIPTS_DIR}'/assets/init_rpi.sh' '/root/'
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${SCRIPTS_DIR}'/assets/hardware_setup.sh' '/root/'
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} exec ${SCRIPTS_DIR}'/image-init.sh' ${IMAGE_VERSION} ${SOURCE_IMAGE}

# Copy MAVLink repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/mavlink' '/home/pi/mavlink'
# Copy pymavlink repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/pymavlink' '/home/pi/pymavlink'
# Copy mavlink-router repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/mavlink-router' '/home/pi/mavlink-router'
# Copy cmavnode repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/cmavnode' '/home/pi/cmavnode'
# Copy yaml-cpp repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/yaml-cpp' '/home/pi/yaml-cpp'
# Copy spdlog repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/spdlog' '/home/pi/spdlog'
# Copy cxxopts repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/cxxopts' '/home/pi/cxxopts'
# Copy libseek-thermal repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/libseek-thermal' '/home/pi/libseek-thermal'
# Copy raspicam repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/raspicam' '/home/pi/raspicam'
# Copy mavlink-switch repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/mavlink-switch' '/home/pi/mavlink-switch'
# Copy raw-wifi-link repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/raw-wifi-link' '/home/pi/raw-wifi-link'
# Copy duocam-mavlink repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/duocam-mavlink' '/home/pi/duocam-mavlink'
# Copy duocam-camera repository contents to the image
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${LIB_DIR}'/duocam-camera' '/home/pi/duocam-camera'
# software install
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} exec ${SCRIPTS_DIR}'/image-software.sh'
# network setup
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} exec ${SCRIPTS_DIR}'/image-network.sh'

# If RPi then use a one thread to build a ROS package on RPi, else use all
[[ $(arch) == 'armv7l' ]] && NUMBER_THREADS=1 || NUMBER_THREADS=$(nproc --all)
# Add rename script
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} copy ${SCRIPTS_DIR}'/assets/tx_rename' '/usr/local/bin/tx_rename'
${BUILDER_DIR}/image-chroot.sh ${IMAGE_PATH} exec ${SCRIPTS_DIR}'/image-validate.sh'

${BUILDER_DIR}/image-resize.sh ${IMAGE_PATH}

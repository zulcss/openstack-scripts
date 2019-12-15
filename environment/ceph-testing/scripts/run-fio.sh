#!/bin/bash

WORKDIR="$(cd "$(dirname ${0})" && pwd)"
WORKSPACE="${WORKDIR}/workspace"
USER_NAME="${USER_NAME:-root}"
USER_PASS="${USER_PASS:-r00tme}"
REMOTE_HOST="${REMOTE_HOST:-172.20.9.15}"
STARTTIME=""
STOPTIME=""

function prepare() {
   local ec=0
   mkdir -p ${WORKSPACE}
   return $ec
}

function check_vol() {
  local volpath
  local retval
  local maxretry
  local counter
  retval=1
  counter=0
  maxretry=60
  volpath=${TARGET}
  while true
  do
    if [ -e ${volpath} ]; then
       retval=0
       break
    else
       continue
    fi
    counter=$(( count + 1 ))
    sleep 2
    if [ "${counter}" -ge "${maxretry}" ]; then
       break
    fi
  done
  return ${retval}
}

function run_fio() {
  local iodepth
  local bs
  local ioengine
  local direct
  local buffered
  local jobname
  local filename
  local size
  local readwrite
  local runtime
  bs="4k"
  direct=1
  buffered=0
  ioengine="libaio"
  jobname="$(hostname)_fio"
  iodepth="${IODEPTH}"
  filename="${TARGET}"
  size="--size=${SIZE}"
  readwrite="${RWMODE}"
  STARTTIME=$(date +%Y.%m.%d-%H:%M:%S)
  if [[ "${RUNMOD}" == "time" ]]; then runtime="--runtime=${RUNTIME} --time_based=1"; size='';fi
  sudo fio --ioengine=${ioengine} --direct=${direct} --buffered=${buffered} \
  --name=${jobname} --filename=${filename} --bs=${bs} --iodepth=${iodepth} ${size} \
  --readwrite=${readwrite} ${runtime} --output=${WORKSPACE}/"$(hostname)"_terse.out 2>&1 | tee ${WORKSPACE}/"$(hostname)"_raw_fio_terse.log
  STOPTIME="$(date +%Y.%m.%d-%H:%M:%S)"
  if [ "$(stat ${WORKSPACE}/"$(hostname)"_raw_fio_terse.log | grep -oP '(?<=(Size:))(.[0-9]+\s)')" -eq 0 ]; then
     rm ${WORKSPACE}/"$(hostname)"_raw_fio_terse.log
  fi
}

# Main
   
IODEPTH="${IODEPTH:-64}"
TARGET="${TARGET:-/dev/vdb}"
SIZE="${SIZE:-1G}"
RUNTIME="${RUNTIME:-60}" # 10min
RWMODE="${RWMODE:-randrw}"
RUNMOD="${RUNMOD}"
PARSEONLY="${PARSEONLY:-false}"

prepare || exit $?
check_vol || exit $?
run_fio

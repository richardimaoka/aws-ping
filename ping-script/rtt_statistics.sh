#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass the ping output as input stream, and this produecs JSON of the ping statistics.
# ----------------------------------------------------------------------------------------


# ping summary lines are like below. Extracting the line starting with "rtt min/...", 
#
# --- 10.116.4.5 ping statistics ---
# 30 packets transmitted, 30 received, 0% packet loss, time 29034ms ## <- this is the statistics line
# rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms
RTT_LINE=$(grep "$1" "rtt min/avg/max/mdev")

if [ -z "${RTT_LINE}" ]; then
  echo '"rtt min/avg/max/mdev ..." line is not found'
  exit 1
else
  # Parse the line (e.g.) "rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms"
  RTT_MIN=$(echo "${RTT_LINE}"  | awk '{print $4}' | awk -F'/' '{print $1}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MIN}" ]; then 
    echo "rtt min is empty or not a number"
    echo "> ${RTT_LINE}"
    exit 1
  fi
  
  RTT_AVG=$(echo "${RTT_LINE}"  | awk '{print $4}' | awk -F'/' '{print $2}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_AVG}" ]; then 
    echo "rtt avg is empty or not a number"
    echo "> ${RTT_LINE}"
    exit 1
  fi

  RTT_MAX=$(echo "${RTT_LINE}"  | awk '{print $4}' | awk -F'/' '{print $3}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MAX}" ]; then 
    echo "rtt max is empty or not a number"
    echo "> ${RTT_LINE}"
    exit 1
  fi

  RTT_MDEV=$(echo "${RTT_LINE}" | awk '{print $4}' | awk -F'/' '{print $4}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MDEV}" ]; then 
    echo "rtt mdev is empty or not a number"
    echo "> ${RTT_LINE}"
    exit 1
  fi

  RTT_UNIT=$(echo "${RTT_LINE}" | awk '{print $5}')
  case "$RTT_UNIT" in
    ms)
      RTT_UNIT="milliseconds"
      ;;
    s)
      RTT_UNIT="seconds"
      ;;
  esac
  
  # JSON like below in a single line
  # {
  #   "min": {
  #     "value": 97.749,
  #     "unit":"milliseconds"
  #   },
  #   "avg": {
  #     "value": 98.197,
  #     "unit":"milliseconds"
  #   },
  #   "max": {
  #     "value": 98.285,
  #     "unit":"milliseconds"
  #   },
  #   "mdev": {
  #     "value": 0.380,
  #     "unit":"milliseconds"
  #   }
  # }
  jo min="$(jo value="${RTT_MIN}" unit="${RTT_UNIT}")" \
     avg="$(jo value="${RTT_AVG}" unit="${RTT_UNIT}")" \
     max="$(jo value="${RTT_MAX}" unit="${RTT_UNIT}")" \
     mdev="$(jo value="${RTT_MDEV}" unit="${RTT_UNIT}")"
fi


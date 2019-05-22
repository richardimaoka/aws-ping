#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass the ping output as input stream, and this produecs JSON of the ping statistics.
# ----------------------------------------------------------------------------------------


# ping summary lines are like below. Extracting the line starting with "rtt min/...", 
#
# --- 10.116.4.5 ping statistics ---
# 30 packets transmitted, 30 received, 0% packet loss, time 29034ms ## <- this is the statistics line
# rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms
RTT_LINE=$(grep "rtt min/avg/max/mdev")

if [ -z "${RTT_LINE}" ]; then
  >&2 echo 'The RTT statistics line, which starts with "rtt min/avg/max/mdev = ..." is not found'
  exit 1
else
  # Parse the line (e.g.) "rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms"

  # part-by-part validation
  FIRST_PART=$(echo "${RTT_LINE}"  | awk '{print $1}') # "rtt"
  SECOND_PART=$(echo "${RTT_LINE}" | awk '{print $2}') # "min/avg/max/mdev"
  THIRD_PART=$(echo "${RTT_LINE}"  | awk '{print $3}') # "="
  FOURTH_PART=$(echo "${RTT_LINE}" | awk '{print $4}') # (e.g.) "97.749/98.197/98.285/0.380"
  FIFTH_PART=$(echo "${RTT_LINE}"  | awk '{print $5}') # (e.g.) "ms"

  if [ "${FIRST_PART}" = "rtt" ] ; then
    >&2 echo "'${FIRST_PART}' is not equal to 'rtt', from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
  elif [ "${SECOND_PART}" = "min/avg/max/mdev" ] ; then
    >&2 echo "'${SECOND_PART}' is not equal to 'min/avg/max/mdev', from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
  elif [ "${THIRD_PART}" = "=" ] ; then
    >&2 echo "'${THIRD_PART}' is not equal to '=', from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
  # FOURTH_PART to be validated later
  elif [ -z "$(echo "${FIFTH_PART}" | awk "/^\D{1,2}$/")" ]; then
    >&2 echo "'${FIFTH_PART}' is not two non-digit chars, from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
  fi

  # Validate and retrieve values from FOURTH_PART
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_MIN=$(echo "${FOURTH_PART}" | awk -F'/' '{print $1}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MIN}" ]; then 
    >&2 echo "Cannot retrieve the first number fron '/'-delimited '${FOURTH_PART}', from the below summary line:"
    >&2 echo "> ${RTT_LINE}"
    exit 1
  fi
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_AVG=$(echo "$FOURTH_PART" | awk -F'/' '{print $2}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_AVG}" ]; then 
    >&2 echo "Cannot retrieve the second number fron '/'-delimited '${FOURTH_PART}', from the below summary line:"
    echo "> ${RTT_LINE}"
    exit 1
  fi
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_MAX=$(echo "$FOURTH_PART" | awk -F'/' '{print $3}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MAX}" ]; then 
    >&2 echo "Cannot retrieve the third number fron '/'-delimited '${FOURTH_PART}', from the below summary line:"
    echo "> ${RTT_LINE}"
    exit 1
  fi
  # (e.g.) "97.749/98.197/98.285/0.380"
  RTT_MDEV=$(echo "$FOURTH_PART" | awk -F'/' '{print $4}'| awk '/^[+-]?([0-9]*[.])?[0-9]+$/')
  if [ -z "${RTT_MDEV}" ]; then 
    >&2 echo "Cannot retrieve the fourth number fron '/'-delimited '${FOURTH_PART}', from the below summary line:"
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


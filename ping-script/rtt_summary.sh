#!/bin/sh

# ----------------------------------------------------------------------------------------
# You pass the ping output as input stream, and this produecs JSON of the ping summary
# ----------------------------------------------------------------------------------------

# ping summary lines are like below. Extracting the line starting with "30 packets transmitted...", 
#
# > --- 10.116.4.5 ping statistics ---
# > 30 packets transmitted, 30 received, 0% packet loss, time 29034ms ## <- this is the summary line
# > rtt min/avg/max/mdev = 97.749/98.197/98.285/0.380 ms
SUMMARY_LINE=$(grep "packets transmitted, " | grep "received, " | grep " packet loss, " | grep "time ")

if [ -z "${SUMMARY_LINE}" ]; then
  >&2 echo 'ERROR: The summary line like "30 packets transmitted, 30 received, 0% packet loss, time 29034ms" is not found.'
  exit 1
elif [ "$(echo "${SUMMARY_LINE}" | wc -l )" -ne 1 ]; then
  >&2 echo 'ERROR: Multiple summary lines found, which are like "30 packets transmitted, 30 received, 0% packet loss, time 29034ms" is not found.'
  >&2 echo "${RTT_LINE}"
  exit 1
else
  # Parse the line (e.g.) "30 packets transmitted, 30 received, 0% packet loss, time 29034ms"
  
  # part-by-part validation
  FIRST_PART=$(echo "${SUMMARY_LINE}"  | awk -F',' '{print $1}') # (e.g.) "30 packets transmitted"
  SECOND_PART=$(echo "${SUMMARY_LINE}" | awk -F',' '{print $2}') # (e.g.) " 30 received"
  THIRD_PART=$(echo "${SUMMARY_LINE}"  | awk -F',' '{print $3}') # (e.g.) " 0% packet loss"
  FOURTH_PART=$(echo "${SUMMARY_LINE}" | awk -F',' '{print $4}') # (e.g.) " time 29034ms"

  if [ -z "$(echo "${FIRST_PART}" | awk "/^[0-9]+\spackets\stransmitted$/")" ] ; then
    >&2 echo "ERROR: '${FIRST_PART}' is not in the form of '** packets transmitted', from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  elif [ -z "$(echo "${SECOND_PART}" | awk "/^\s[0-9]+\sreceived$/")" ] ; then
    >&2 echo "ERROR: '${SECOND_PART}', is not in the form of ' ** received', from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  elif [ -z "$(echo "${THIRD_PART}" | awk "/^\s[0-9]+\%\spacket\sloss$/")" ] ; then
    >&2 echo "ERROR: '${THIRD_PART}', is not in the form of ' **% packet loss', from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  elif [ -z "$(echo "${FOURTH_PART}" | awk "/^\stime\s[0-9]+[a-z]{1,2}$/")" ]; then
    >&2 echo "ERROR: '${FOURTH_PART}', is not in the form of ' time **ms', from the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  fi

  # 1. Parse the "30 packets transmitted" part of the SUMMARY_LINE
  # (e.g.) "30 packets transmitted"
  PACKETS_TRANSMITTED=$(echo "${FIRST_PART}" | awk '{print $1}'| awk '/^[0-9]+$/')
  if [ -z "${PACKETS_TRANSMITTED}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the packets transmitted value from '${FIRST_PART}', in the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  fi
  # (e.g.) " 30 received"
  PACKETS_RECEIVED=$(echo "${SECOND_PART}" | awk '{print $1}'| awk '/^[0-9]+$/')
  if [ -z "${PACKETS_RECEIVED}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the packets received value from '${SECOND_PART}', in the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  fi
  # (e.g.) " 0% packet loss"
  PACKET_LOSS_PERCENTAGE=$(echo "${THIRD_PART}" | awk '{print $1}'| sed 's/%//')
  if [ -z "${PACKET_LOSS_PERCENTAGE}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the packet loss percentage from '${THIRD_PART}', in the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  fi
  # (e.g.)"time 29034ms"
  TIME_VALUE=$(echo "${FOURTH_PART}" | awk '{print $2}'| grep -o '^[0-9]*')
  if [ -z "${PACKETS_TRANSMITTED}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the time value from '${FOURTH_PART}', in the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  fi
  TIME_UNIT=$(echo "${FOURTH_PART}" | awk '{print $2}'| sed 's/^[0-9]*//')
  if [ -z "${PACKETS_TRANSMITTED}" ]; then 
    >&2 echo "ERROR: Cannot retrieve the time unit from '${FOURTH_PART}', in the below summary line:"
    >&2 echo ">${SUMMARY_LINE}"
    exit 1
  fi
  case "$TIME_UNIT" in
    ms)
      TIME_UNIT="milliseconds"
      ;;
    s)
      TIME_UNIT="seconds"
      ;;
  esac

  # JSON like below in a single line
  # {
  #   "packets_transmitted": 30,
  #   "packets_received": 30,
  #   "packet_loss_percentage": 0,
  #   "time": {
  #     "unit": "milliseconds",
  #     "value": 29034
  #   }
  # }
  echo "{"
  echo "  \"packets_transmitted\": ${PACKETS_TRANSMITTED},"
  echo "  \"packets_received\": ${PACKETS_RECEIVED},"
  echo "  \"packet_loss_percentage\": ${PACKET_LOSS_PERCENTAGE},"
  echo "  \"time\": {"
  echo "    \"unit\": \"${TIME_UNIT}\","
  echo "    \"value\": ${TIME_VALUE}"
  echo "  }"
  echo "}"
fi


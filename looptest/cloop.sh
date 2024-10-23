#!/bin/bash

# The script reads amf_sessions from Open5GS Prometheus, compares it to reference ranges and scales UPF accordingly

# Base scan time of the Prometheus in seconds
BASE_SCAN_TIME=30

# Current amespace
NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}'; echo)

#The value of amf_sessions read from Prometheus
amf_sessions=0

#scaling thresholds and CPU quotas for the number of amf sessions
AMFS0=0
CPU0="100m" # if AMFS0 <= amf_sessions < AMFS1
AMFS1=4
CPU1="150m" # if AMFS1 <= amf_sessions < AMFS2
AMFS2=8
CPU2="200m" # if AMFS2 <= amf_sessions < AMFS3
AMFS3=12
CPU3="250m" # if AMFS3 <= amf_sessions

MAX_ITER=-1
if [ $# -gt 0 ] ; then
  if [ "$1" == "help" ] ; then
    echo "Enter the preferred number of loop iterations and namespace. Otherwise infinite loop will be run in default namespace."
    exit
  else
    MAX_ITER=$1
    if [ $# -eq 2 ] ; then
      NAMESPACE=$2
    fi
    echo "Running $1 iterations in namespace $NAMESPACE"
  fi
else
  echo "Running infinite loop in namespace $NAMESPACE"
fi

iter=0
continue=true

while $continue ; do

  iter=$((iter+1))
#  echo "Iteration $iter"

  # read amf_sessions form Prometheus - choose the version with appropriate namespace
  amf_sessions="$(curl -s 10.0.0.3:9090/api/v1/query -G -d \
               'query=amf_session{service="open5gs-amf-metrics",namespace="$NAMESPACE"}' | \
               jq '.data.result[0].value[1]' | tr -d '"')"

  # scale the resource
  cpu=$CPU0
  if [ $amf_sessions -ge $AMFS1 ]
  then
    cpu=$CPU1
  fi

  if [ $amf_sessions -ge $AMFS2 ]
  then
    cpu=$CPU2
  fi

  if [ $amf_sessions -ge $AMFS3 ]
  then
    cpu=$CPU3
  fi

  echo "Iteration $iter, amf_sessions $amf_sessions, scale resource to $cpu"

  kubectl patch pod open5gs-upf-7485fbd69c-hljfz --patch \
          "{\"spec\":{\"containers\":[{\"name\":\"open5gs-upf\", \"resources\":{\"limits\":{\"cpu\":\"$cpu\"}}}]}}"

  # SLEEP TIME ============
  if [ $iter != $MAX_ITER ]
  then
    sleeptime=$BASE_SCAN_TIME
    echo "sleep $sleeptime sec."
    sleep $sleeptime
  else
    continue=false
  fi

done

echo "Exiting"

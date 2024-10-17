#!/bin/bash

# The script reads amf_sessions from Open5GS Prometheus, compares it to reference ranges and scales UPF accordingly

# Base scan time of the Prometheus in seconds
BASE_SCAN_TIME=30

# Namespace to be used
NAMESPACE="default"

#The value of amf_sessions read from Prometheus
amf_sessions=0

#scaling thresholds and CPU quotas for the number of amf sessions
AMFS0=0
CPU0="100M" # if AMFS0 <= amf_sessions < AMFS1
AMFS1=4
CPU1="150M" # if AMFS1 <= amf_sessions < AMFS2
AMFS2=8
CPU2="200M" # if AMFS2 <= amf_sessions < AMFS3
AMFS3=12
CPU3="250M" # if AMFS3 <= amf_sessions

#kubectl create namespace $NAMESPACE > /dev/null 2>&1    # > /dev/null 2>&1   - ignores command output

MAX_ITER=-1
if [ $# -gt 0 ] ; then
  if [ "$1" == "help" ] ; then
    echo "Enter the preferred number of loop iterations. Otherwise infinite loop will be run."
    exit
  else
    MAX_ITER=$1
  fi
fi

iter=0
continue=true

while $continue ; do

  iter=$((iter+1))
#  echo "Iteration $iter"

  # read amf_sessions form Prometheus
  amf_sessions="$(curl -s 10.0.0.3:9090/api/v1/query -G -d \
               'query=amf_session{service="open5gs-amf-metrics"}' | \
               jq '.[].data.result[0].value[1]' curl.json | tr -d '"')"

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

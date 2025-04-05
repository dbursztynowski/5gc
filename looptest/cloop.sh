#!/bin/bash

# New version - 2025.04.05

# The script reads amf_sessions from Open5GS Prometheus, compares it to reference ranges and scales UPF accordingly

# PARAMETERS
#########################

# Prometheus endpoint
PROMETHEUS_ADDR="10.0.0.3"

# Base scan time of the Prometheus in seconds
BASE_SCAN_TIME=30

# Scaled pod/container names (generic, without random suffix)
SCALED_POD_GENERIC_NAME="open5gs-upf"   # Pod name
SCALED_CONTAINER_NAME="open5gs-upf"     # Name of the container in the pod to scale

#########################
# SCRIPT CODE
#########################

# Current namespace
NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}'; echo)

#The value of amf_sessions read from Prometheus
amf_sessions=0

#scaling thresholds for the number of AMF sessions and respective CPU limits quotas
AMFS0=0
CPU0="100m" # if AMFS0 <= amf_sessions < AMFS1
AMFS1=4
CPU1="150m" # if AMFS1 <= amf_sessions < AMFS2
AMFS2=8
CPU2="200m" # if AMFS2 <= amf_sessions < AMFS3
AMFS3=12
CPU3="250m" # if AMFS3 <= amf_sessions

#===========================
# DETERMINE INPUT PARAMETERS
#===========================

MAX_ITER=-1

if [ $# -gt 0 ] ; then

  if [ $# -gt 2 ] ; then
    echo "Too many parameters." >&2; exit 1
  fi

  if [ $# -eq 1 ] ; then   # only one parameter specified
    if [ "$1" == "help" ] ; then
       echo -e "Enter the preferred number of loop iterations, or the namespace of your target deployment, or both (in this order).\nIf the numer of iterations is not specified an infinite loop will be run. If the namspace is not specified, the loop will run in current namespace."
       exit
    fi
    
    re='^[0-9]+$'
    if [[ $1 =~ $re ]] ; then
       MAX_ITER=$1   # only the number of iterations is specified
    else
       NAMESPACE=$1  # only the namespace is specified
       ns=$(kubectl get namespaces | grep $NAMESPACE | awk '{print $1}')
       if [[ ${ns} != ${NAMESPACE} ]] ; then
          echo "Error:  $NAMESPACE is not a valid number of iterations nor a valid namespace. Check help." >&2; exit 1
       fi
    fi

    # the number of iterations and namespace are determined
    if (( ${MAX_ITER} > 0 )) ; then
       echo "Running $MAX_ITER iterations in current namespace."
    else
       echo "Running infinite loop in namespace $NAMESPACE."
    fi

  else                     # two parameters are specified (more than two are rejected before)
    re='^[0-9]+$'          # the number of iterations must go first
    if ! [[ $1 =~ $re ]] ; then
       echo "Error: $1 is not integer. Check help." >&2; exit 1
    fi
    MAX_ITER=$1
    NAMESPACE=$2
    # check in $NAMESPACE exists in the cluster
    ns=$(kubectl get namespaces | grep $NAMESPACE | awk '{print $1}')
    if [[ ${ns} != ${NAMESPACE} ]] ; then
       echo "Error: Invalid namespace $NAMESPACE. Check help." >&2; exit 1
    fi
    echo "Running $MAX_ITER iterations in namespace $NAMESPACE."
  fi
else
  echo "Running infinite loop in namespace $NAMESPACE."
fi

#===========================
# RUN THE SCALING LOOP
#===========================

iter=0
continue=true

while $continue ; do

  iter=$((iter+1))

  # read the metric value: amf_sessions from Prometheus - choose the version with appropriate namespace
  query="query=amf_session{service=\"open5gs-amf-metrics\",namespace=\"$NAMESPACE\"}"
  echo -e "\nquery:" ${query}
  amf_sessions=$(curl -s ${PROMETHEUS_ADDR}:9090/api/v1/query -G -d \
               ${query} | jq '.data.result[0].value[1]' | tr -d '"')

  # derive the amount of resource needed
  cpu=$CPU0
  if [[ $amf_sessions -ge $AMFS1 ]]
  then
    cpu=$CPU1
  fi

  if [[ $amf_sessions -ge $AMFS2 ]]
  then
    cpu=$CPU2
  fi

  if [[ $amf_sessions -ge $AMFS3 ]]
  then
    cpu=$CPU3
  fi

  # scale the target

  podname=$(kubectl get pods -n $NAMESPACE | grep $SCALED_POD_GENERIC_NAME | awk '{print $1}')

  echo "Iteration $iter, amf_sessions $amf_sessions, pod $podname, scaling resource to $cpu"

  ## old version of patching
#  kubectl -n $NAMESPACE patch pod $podname --subresource resize --patch \
#          "{\"spec\":{\"containers\":[{\"name\":\"$SCALED_CONTAINER_NAME\", \"resources\":{\"requests\":{\"cpu\":\"50m\"}, \"limits\":{\"cpu\":\"$cpu\"}}}]}}"

  ## newer version of patching
  kubectl -n $NAMESPACE patch pod $podname --subresource resize --patch \
          "{\"spec\": \
              {\"containers\": \
                 [ \
                    {\"name\":\"open5gs-upf\", \"resources\": \
                        { \
                           \"requests\":{\"cpu\":\"50m\"}, \
                           \"limits\"  :{\"cpu\":\"$cpu\"} \
                        } \
                    } \
                 ] \
              } \
           }"

  ## or simpler form, equivalent to the old one (only limits is explicitly scaled)
#  kubectl -n $NAMESPACE patch pod $podname --subresource resize --patch \
#          "{\"spec\": \
#              {\"containers\": \
#                 [ \
#                    {\"name\":\"open5gs-upf\", \"resources\": \
#                        { \
#                           \"limits\"  :{\"cpu\":\"$cpu\"} \
#                        } \
#                    } \
#                 ] \
#              } \
#           }"

  # SLEEP TIME ============
  if (( ${iter} != ${MAX_ITER} ))
  then
    sleeptime=$BASE_SCAN_TIME
    echo "going asleep for $sleeptime sec."
    sleep $sleeptime
  else
    continue=false
  fi

done

echo -e "\nFinishing."

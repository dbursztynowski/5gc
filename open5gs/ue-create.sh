#!/bin/bash

#for i in {1..3}
#do
#  nr-ue -c myconfig.yaml -n 2
#done

nr-ue -c ue.yaml -n 1 -i imsi-999700000000006 &
child=$!
wait "$child"
;;

- jesli problemy z mongodb to:
  $ cat /proc/cpuinfo | grep avx
  jesli nie ma avx, to zmienic obraz mongodb w deploymencie na:
    image: docker.io/bitnami/mongodb:4.4.15-debian-10-r8
    
============================================
- install Open5GS + UERANSIM + correct mongodb image (quick version, to be improved later by changing the elm chart)
  below, it is assummed that avx instruction set extension is not supported

# ==> if $ cat /proc/cpuinfo | grep avx returns blank output on your host machine (so your host does not support avx
      instruction set extension ) then you have to change the mongodb image to be used
  - download open5gs helm chart
$ helm pull oci://registry-1.docker.io/gradiant/open5gs --version 2.2.0
  - unzip to directory ./open5gs (https://phoenixnap.com/kb/extract-tar-gz-files-linux-command-line)
$ tar -xvzf open5gs-2.2.0.tgz -C ./open5gs   # adjust *.tgz file name according to your case

  - adjust values for mongodb to use image docker.io/bitnami/mongodb:4.4.15-debian-10-r8
    In the values file open5gs/charts/mongodb/values.yaml change to (line 105):
image:
     registry: docker.io
     repository: bitnami/mongodb
     tag: 4.4.15-debian-10-r8
# <== end pf "change mongodb image"
    
  - install open5gs (decide if defauult or customized user set is to be created)
$ helm install open5gs ./open5gs --version 2.2.0 --values https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/5gSA-values.yaml
  - for custom UE list (update UEs consistently in 5gSA-values.yaml for 5gcore, and in gnb-ues-values.yaml to deploy UERANSIM)
$ helm install open5gs ./open5gs --version 2.2.0 --values ./5gSA-values.yaml

- install UERANSIM
$ helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/gnb-ues-values.yaml
  - for custom UE list
$ helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml

# now check the connectivity (see below)
....

- adjust the open5gs-populate deployment so that it starts properly on future cluster restarts (remove the whole init-containers section)
  $ kubectl get deployments open5gs-populate -o yaml > open5gs-populate-adjust.yaml
  $ nano open5gs-populate-adjust.yaml
    ==> remove whole section init-containers (so that init container is not run on cluster restarts in the future)
  $ kubectl delete deployments open5gs-populate
  $ kubectl apply -f open5gs-populate-adjust.yaml

--------------------------------------------
Check UE's connectivity

---

You have also deployed 2 ues. You can enter ues terminal with:

```
kubectl -n default exec -ti deployment/ueransim-gnb-ues -- /bin/bash
kubectl -n default exec -ti deployment/ueransim-ues-additional -- /bin/bash
```
There is a tun interface for each ue. 
You can bind your application to the interface to test ue connectivity.
Example:

```
ping -I uesimtun0 gradiant.org
traceroute -i uesimtun0 gradiant.org
curl --interface uesimtun0 https://www.gradiant.org/ 
```

You can also deploy more ues connected to this gnodeb with gradiant/ueransim-ues chart:

```
helm install -n default ueransim-ues gradiant/ueransim-ues --set gnb.hostname=ueransim-gnb

or

helm install -n default ueransim-ues-additional oci://registry-1.docker.io/gradiant/ueransim-ues \
--set gnb.hostname=ueransim-gnb \
--set count=2 \
--set initialMSISDN="0000000003"

helm install -n default ueransim-ues-additional oci://registry-1.docker.io/gradiant/ueransim-ues \
--set gnb.hostname=ueransim-gnb \
--set count=1 \
--set initialMSISDN="0000000004"

$ kubectl -n default exec -ti deployment/ueransim-ues-not-defined -- /bin/bash

```
--------------------------------------------
- complete guide, including adding UEs to the network
https://gradiant.github.io/5g-charts/open5gs-ueransim-gnb.html

- add single UE
$ kubectl exec deployment/open5gs-populate -ti -- bash
open5gs-dbctl add_ue_with_slice <imsi> <key> <opc> <apn> <sst> <sd>
$ open5gs-dbctl add_ue_with_slice 999700000000004 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111


============================================
Grafana/Prometheus

- port forwarding
$ kubectl port-forward -n monitoring service/grafana 3000:3000

- in case of errors as E0624 19:51:42.388119  430900 portforward.go:370] error creating forwarding stream for port 3000 -> 3000: Timeout occurred
  cancel current port forwarding and run $ kubectl port-forward ... again

============================================
in case of problems
============================================
- Details about the container's current condition (all containers in a pod).
$ kubectl get pods \
    -o custom-columns="POD:metadata.name,STATE:status.containerStatuses[*].state.waiting.reason"
  HINT: $ kubectl explain pod.status.containerStatuses.state
  
============================================
In-place scaling

https://medium.com/@karla.saur/trying-out-the-new-in-place-pod-resource-resizing-68a0b3c42b72
============================================
IPTABLES
- allow forwarding, incoming, outgoing
# iptables -A FORWARD -i all -o all -j ACCEPT
iptables -A FORWARD -j ACCEPT -m comment --comment "Accept all forwarded"
iptables -A INPUT -j ACCEPT -m comment --comment "Accept all incoming"
iptables -A OUTPUT -j ACCEPT -m comment --comment "Accept all outgoing"



- SOURCES:
https://github.com/Gradiant/5g-charts/tree/main/charts
******************************************************

- INSTALL Open5GS + UERANSIM + correct mongodb image (quick version, to be improved later by changing the Helm chart)
  below, it is assummed that avx instruction set extension is not supported

  Note: after cloning the repo and setting the cluster, 5gc/open5gs is your working 
        directory to install open5gs and UERANSIM.

==========================================
- check mongodb compatibility and correct if needed (fallback to lower release)

# ==> if $ cat /proc/cpuinfo | grep avx returns blank output on your host machine (so your host does not support avx
      instruction set extension ) then you have to change the mongodb image to be used
  - download open5gs helm chart (earlier we used version 2.2.0 and it worked fine)
$ helm pull oci://registry-1.docker.io/gradiant/open5gs --version 2.2.5
  - unzip to directory ./open5gs (https://phoenixnap.com/kb/extract-tar-gz-files-linux-command-line)
$ tar -xvzf open5gs-2.2.5.tgz -C ./open5gs   # adjust *.tgz file name according to your case

  - adjust values for mongodb to use image docker.io/bitnami/mongodb:4.4.15-debian-10-r8
    In the values file open5gs/charts/mongodb/values.yaml change to (line 105):
image:
     registry: docker.io
     repository: bitnami/mongodb
     tag: 4.4.15-debian-10-r8
# <== end pf "change mongodb image"

===========================================
OPEN5GS
-------------------------------------------
- install open5gs: decide if default or customized user set is to be created and follow appropriate option out of the two given below

  -------
  - for default UE list (two UEs will be created)
$ helm install open5gs ./open5gs --version 2.2.5 --values https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/5gSA-values.yaml

  -------
  - for custom UE list update UEs consistently in 5gSA-values.yaml for 5gcore, and in gnb-ues-values.yaml for the UEs to deploy UERANSIM correctly
    - downlowad and update the UE config file
$ wget https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/5gSA-values.yaml
$ nano 5gSA-values.yaml
$ cat 5gSA-values.yaml   <=== below, four UEs will be generated
...
populate:
  enabled: true
  initCommands:
  - open5gs-dbctl add_ue_with_slice 999700000000001 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
  - open5gs-dbctl add_ue_with_slice 999700000000002 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
  - open5gs-dbctl add_ue_with_slice 999700000000003 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
  - open5gs-dbctl add_ue_with_slice 999700000000004 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
$

- actual install
$ helm install open5gs ./open5gs --version 2.2.5 --values ./5gSA-values.yaml

- testing (dry run)
$ helm -n <namespace> install --debug --dry-run open5gs ./open5gs --version 2.2.5 --values ./5gSA-values.yaml

-------------------------------------------
Correcting OPEN5GS mongodb probes if mongodb crashes

Note: hints for Helm: https://www.alibabacloud.com/blog/helm-charts-and-template-basics---part-2_595490

- accordig to https://github.com/bitnami/charts/issues/10264 (other tweaks also presented there)
  Yet other tweaks possible
  - https://github.com/syndikat7/mongodb-rust-ping
  - or even replacement of mongodb possible but needs changing the charts:
    https://github.com/FerretDB/FerretDB

- (in open5gs/charts/mongodb/values.yaml change)
# startupProbe.enabled must be false (that is the default)
customStartupProbe:
  initialDelaySeconds: 5
  periodSeconds: 20
  timeoutSeconds: 10
  successThreshold: 1
  failureThreshold: 30
  exec:
    command:
      - sh
      - -c
      - |
        mongosh --eval 'disableTelemetry()'
        /bitnami/scripts/startup-probe.sh

- testing (dry run)
$ helm -n <namespace> install --debug --dry-run open5gs ./open5gs --version 2.2.5 --values ./5gSA-values.yaml

===========================================
Basic UERANSIM 
Note: an alternative to ueransim to generate traffic (but without any insight into UE-gNB signalling) is:
      https://github.com/my5G/my5G-RANTester/wiki/Usage
-------------------------------------------

---------
- install UERANSIM with default config
$ helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/gnb-ues-values.yaml

----------
- install UERANSIM with custom UE list
$ wget https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/gnb-ues-values.yaml
$ cat gnb-ues-values.yaml       <=== must be consistent with file 5gSA-values.yaml (# of UEs, and mcc/mnc and sd values)
amf:
  hostname: open5gs-amf-ngap

gnb:
  hostname: ueransim-gnb

mcc: '999'
mnc: '70'
sst: 1
sd: "0x111111"
tac: '0001'

ues:
  enabled: true
  count: 4
  initialMSISDN: '0000000001'
$
  - actual install
$ helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml

---------
# now check the connectivity (see below)
....

- adjust the open5gs-populate deployment so that it starts properly on future cluster restarts (remove the whole init-containers section)
  $ kubectl get deployments open5gs-populate -o yaml > open5gs-populate-adjust.yaml
  $ nano open5gs-populate-adjust.yaml
    ==> remove whole section init-containers (so that init container is not run on cluster restarts in the future)
  $ kubectl delete deployments open5gs-populate
  $ kubectl apply -f open5gs-populate-adjust.yaml

==========================================
UERANSIM placed on selected node/node type
------------------------------------------
$ helm pull oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6
$ mkdir ueransim-gnb-place
$ tar -xvzf ueransim-gnb-0.2.6.tgz -C ./ueransim-gnb-place

- update templates and values.yaml for both uearansim pods

  nodeSelector:
    db.5gnet/workload: ran-functions
   (db.5gnet/workload: core-functions)

- assign label(s) to node(s)
$ kubectl label nodes k3sworker db.5gnet/workload=ran-functions

- install uearnsim
$ helm install ueransim-gnb ./ueransim-gnb-place/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml

==========================================
Check UE's connectivity
------------------------------------------
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
generate traffic using nr-binder utility
$ kubectl -n default exec -ti deployment/ueransim-gnb-ues -- /bin/bash
# su   <=== to run as root if not already
# chmod 755 /usr/local/bin/nr-binder
# /usr/local/bin/nr-binder 10.45.0.2 curl http://www.google.com

can run multiple instances of nr-binder (multiple streams) in parallel
to verify, login to ueransim-gnb-ues pod from two separate terminals and run for different TUN interfaces, e.g.:
# /usr/local/bin/nr-binder 10.45.0.2 ping wp.pl
# /usr/local/bin/nr-binder 10.45.0.5 ping wp.pl
(10.45.0.2, 10.45.0.5 are IP addresses of the TUNs involved: # ip addr
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
- complete install guide, also including adding UEs to the network
https://gradiant.github.io/5g-charts/open5gs-ueransim-gnb.html

- UERANSIM usage guide, including nr-binder
https://github.com/aligungr/UERANSIM/wiki/Usage

- add single UE
$ kubectl exec deployment/open5gs-populate -ti -- bash
open5gs-dbctl add_ue_with_slice <imsi> <key> <opc> <apn> <sst> <sd>
$ open5gs-dbctl add_ue_with_slice 999700000000004 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111

- Wireshark dissector for UERANCJIM Radio Link protocol
https://github.com/nextmn/RLS-wireshark-dissector

- Other UERANSIM resources
https://github.com/aligungr/UERANSIM/wiki/Tutorials-and-Other-Resources

********************************************
********************************************
OTHER HINTS
********************************************
********************************************

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
In-place pod scaling

https://medium.com/@karla.saur/trying-out-the-new-in-place-pod-resource-resizing-68a0b3c42b72
============================================
IPTABLES
- allow forwarding, incoming, outgoing
# iptables -A FORWARD -i all -o all -j ACCEPT
iptables -A FORWARD -j ACCEPT -m comment --comment "Accept all forwarded"
iptables -A INPUT -j ACCEPT -m comment --comment "Accept all incoming"
iptables -A OUTPUT -j ACCEPT -m comment --comment "Accept all outgoing"

============================================
- Using ctr (containerd cli tool)
https://labs.iximiuz.com/courses/containerd-cli/ctr/image-management#what-is-ctr
https://labs.iximiuz.com/courses/containerd-cli/ctr/image-management#basics

============================================

COREDNS PROBLEMS (MONGODB CONNECTIVITY PROBLEMS, ADDRESS NOT FOUND BY PODS)

--------- Normal (correct) run ------------
- forced delete if needed
ubuntu@5gcore:~/5gc$ kubectl delete pod dnsutils --grace-period=0 --force
Warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the cluster indefinitely.
pod "dnsutils" force deleted

- run and use dnsutils pod
---------------------------
ubuntu@5gcore:~/5gc$ kubectl apply -f https://k8s.io/examples/admin/dns/dnsutils.yaml
pod/dnsutils created

ubuntu@5gcore:~/5gc$ watch kubectl get pods
ubuntu@5gcore:~/5gc$ kubectl exec -i -t dnsutils -- nslookup kubernetes.default
Server:		10.43.0.10
Address:	10.43.0.10#53

Name:	kubernetes.default.svc.cluster.local
Address: 10.43.0.1

ubuntu@5gcore:~/5gc$ kubectl exec -ti dnsutils -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.43.0.10
options ndots:5

ubuntu@5gcore:~/5gc$ kubectl get pods --namespace=kube-system -l k8s-app=kube-dns
NAME                      READY   STATUS    RESTARTS      AGE
coredns-6799fbcd5-m5pw6   1/1     Running   2 (19m ago)   6d

- btw. erroneous mongodb name:
ubuntu@5gcore:~/5gc$ kubectl exec -i -t dnsutils -- nslookup mongodb.default
Server:		10.43.0.10
Address:	10.43.0.10#53

** server can't find mongodb.default: NXDOMAIN
command terminated with exit code 1

- correct naming of mongodb
ubuntu@5gcore:~/5gc$ kubectl exec -i -t dnsutils -- nslookup open5gs-mongodb.default
Server:		10.43.0.10
Address:	10.43.0.10#53

Name:	open5gs-mongodb.default.svc.cluster.local
Address: 10.43.7.181

ubuntu@5gcore:~/5gc$

-------------- Failed run -------------------
ubuntu@k3smanager:~/5gc/k3subuntu$ kubectl exec -i -t dnsutils -- nslookup kubernetes.default
;; connection timed out; no servers could be reached

command terminated with exit code 1
ubuntu@k3smanager:~/5gc/k3subuntu$

**********************************************
iperf

- public iperf servers
https://iperf.fr/iperf-servers.php

- iperf3 - using multiple interfaces / multiple destinations
https://superuser.com/questions/1682859/how-to-run-iperf3-throughput-test-for-multiple-client-interfaces-on-same-machine
  additionally use the --bind-dev option: https://github.com/esnet/iperf/issues/1572

- iperf - install newest version on Ubuntu
https://iperf.fr/iperf-download.php#ubuntu
  files here: https://launchpad.net/ubuntu/+source/iperf3
  - but this is tricky for numerous dependencies;
    removing packages: https://askubuntu.com/questions/151941/how-can-you-completely-remove-a-package
  - packages needed:
    - (current to remove) https://launchpad.net/ubuntu/noble/amd64/libc6
      https://launchpad.net/ubuntu/noble/amd64/libc6/2.39-0ubuntu8.3
      apt-get install libc6=2.39-0ubuntu8.3
    - (current to remove) https://launchpad.net/ubuntu/noble/amd64/libsctp1/1.0.19+dfsg-2build1

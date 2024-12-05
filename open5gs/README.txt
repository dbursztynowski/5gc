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
# <== end of "change mongodb image"

===========================================
OPEN5GS
-------------------------------------------
- install open5gs: decide if default or customized user set is to be created and follow appropriate option out of the two given below

  -------
  - for default UE list (two UEs will be created)
$ helm install open5gs ./open5gs --version 2.2.5 --values https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/5gSA-values.yaml

  ------- @@@
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

---------------
NOTE: to enable metrics, above file should be updated as below:

$ cat 5gSA-values-enable-metrics.yaml
hss:
  enabled: false

mme:
  enabled: false

pcrf:
  enabled: false

smf:
  config:
    pcrf:
      enabled: false

sgwc:
  enabled: false

sgwu:
  enabled: false

amf:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels: {release: prometheus}
  config:
    guamiList:
      - plmn_id:
          mcc: "999"
          mnc: "70"
        amf_id:
          region: 2
          set: 1
    taiList:
      - plmn_id:
          mcc: "999"
          mnc: "70"
        tac: [1]
    plmnList:
      - plmn_id:
          mcc: "999"
          mnc: "70"
        s_nssai:
          - sst: 1
            sd: "0x111111"

pcf:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels: {release: prometheus}

upf:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels: {release: prometheus}

smf:
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      additionalLabels: {release: prometheus}
  config:
    pcrf:
      enabled: false

nssf:
  config:
    nsiList:
      - uri: ""
        sst: 1
        sd: "0x111111"

webui:
  ingress:
    enabled: false

populate:
  enabled: true
  initCommands:
  - open5gs-dbctl add_ue_with_slice 999700000000001 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
  - open5gs-dbctl add_ue_with_slice 999700000000002 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
  - open5gs-dbctl add_ue_with_slice 999700000000003 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
  - open5gs-dbctl add_ue_with_slice 999700000000004 465B5CE8B199B49FAA5F0A2EE238A6BC E8ED289DEBA952E4283B54E88E6183CA internet 1 111111
---------------

- actual install (adjust open5gs directory name to your case)
$ helm install open5gs ./open5gs<varsion> --version 2.2.5 --values ./5gSA-values.yaml
  helm install open5gs ./open5gs-225 --version 2.2.5 --values ./5gSA-values-enable-metrics.yaml

- testing (dry run) (adjust open5gs directory name to your case)
$ helm -n <namespace> install --debug --dry-run open5gs ./open5gs<version> --version 2.2.5 --values ./5gSA-values.yaml
  helm -n <namespace> install --debug --dry-run open5gs ./open5gs-225 --version 2.2.5 --values ./5gSA-values-enable-metrics.yaml

-------------------------------------------
Correcting OPEN5GS mongodb probes if mongodb crashes
- mongodb readiness probe crasher => kubectl describe pods <mongodb>:
  Readiness probe failed: command "/bitnami/scripts/readiness-probe.sh" timed out

Note: hints for Helm: https://www.alibabacloud.com/blog/helm-charts-and-template-basics---part-2_595490

- accordig to https://github.com/bitnami/charts/issues/10264 (other tweaks also presented there)
  Yet other tweaks possible
  - https://github.com/syndikat7/mongodb-rust-ping
  - or even replacement of mongodb possible but needs changing the charts:
    https://github.com/FerretDB/FerretDB

- in open5gs/charts/mongodb/values.yaml change enabling customStartupProbe as below to disable Telemetry
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

----------@@@
- install UERANSIM with custom UE list and gradiant/ueransim:dev-b68de9b image to have iperf3 ver. 3.17
-------------------------------------------------------------------------------------------------------

  - *** download Helm chars
$ helm pull oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6
$ mkdir ueransim-gnb-0.2.6
$ tar -xvzf ueransim-gnb-0.2.6.tgz -C ./ueransim-gnb-0.2.6

  - *** download values file to oadjust deployment
$ wget https://gradiant.github.io/5g-charts/docs/open5gs-ueransim-gnb/gnb-ues-values.yaml

  - *** initial values
$ cat gnb-ues-values.yaml       <=== must be consistent with file 5gSA-values.yaml (# of UEs not greater than declared in 5gSA, and mcc/mnc and sd values)
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

  - *** update values to use gradiant/ueransim:dev-b68de9b image to have iperf3 ver. 3.17
$ cat gnb-ues-values.yaml
## Adjusted for:
## - container image version gradiant/ueransim:dev-b68de9b (tag dev-b68de9b)
## - four UEs (must be consistent with gnb deployment)

image:
  registry: docker.io
  repository: gradiant/ueransim
  tag: dev-b68de9b
  pullPolicy: Always
  pullSecrets: []
  debug: false

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

#------------------------------
  - *** actual install
$ helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml
  from local files:
  helm install ueransim-gnb ueransim-gnb-0.2.6/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml

---------
# now check the connectivity (see below)
....

- in case of problems with populate adjust the open5gs-populate deployment so that it starts properly on future cluster restarts (remove the whole init-containers section)
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
Check UE's connectivity @@@
(nie trzeba wszystkiego, wystarczy example z ping)
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
  - configuration: https://github.com/aligungr/UERANSIM/wiki/Configuration
  - more detailed: https://github.com/aligungr/UERANSIM/wiki/Usage

- Examles
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
USING IPERF3
**********************************************
- https://github.com/aligungr/UERANSIM/discussions/474
  # ./nr-binder {PDU-IP-ADDRESS} iperf3 -c {IP-OF-CORE-NETWORK-MACHINE} -i 1 -t 2000
  # iperf3 -c {IP-OF-CORE-NETWORK-MACHINE} -i 1 -t 2000 -B ${PDU-IP-ADDRESS}

Adjusting iperf3 to work with multiple interfaces (iperf3 version higher than 3.9 is needed)
- to work with MULTIPLE INTERFACES use --bind-dev [itf_name] option in addition to --bind [itf_ip_address] option

-------
- public iperf servers
https://github.com/R0GGER/public-iperf3-servers?tab=readme-ov-file#servers-per-continent

- iperf3 - using multiple interfaces / multiple destinations
https://superuser.com/questions/1682859/how-to-run-iperf3-throughput-test-for-multiple-client-interfaces-on-same-machine
  additionally use the --bind-dev option: https://github.com/esnet/iperf/issues/1572

- iperf - install a newer version on Ubuntu
https://iperf.fr/iperf-download.php#ubuntu
  files here: https://launchpad.net/ubuntu/+source/iperf3

  maybe: sudo apt install iperf3=3.16-1build2 

  - but this is tricky for numerous dependencies;
    - listing istalled packages: https://www.cyberciti.biz/faq/apt-get-list-packages-are-installed-on-ubuntu-linux/
    - removing packages: https://askubuntu.com/questions/151941/how-can-you-completely-remove-a-package
  - packages (newer versions) needed:
    - (current to remove) https://launchpad.net/ubuntu/noble/amd64/libc6
      https://launchpad.net/ubuntu/noble/amd64/libc6/2.39-0ubuntu8.3
      apt-get install libc6=2.39-0ubuntu8.3
    - (current to remove) https://launchpad.net/ubuntu/noble/amd64/libsctp1/1.0.19+dfsg-2build1

-------
*** Install sequence of iperf3 v3.16 seemingly working on Ubuntu 22.04 ***
(Note1: sometimes --auto-deconfigure option is needed) ***
(Note2: most libraries are derived from Ubuntu 24.04 release; mayby 24.04 is preferable at all)
(Note3: the below stuff has to be converted onto a dockerized version (to be embedded somehow in dockerfile))

wget http://launchpadlibrarian.net/748295744/libgcc-s1_14.2.0-4ubuntu2~24.04_amd64.deb
sudo dpkg -i libgcc-s1_14.2.0-4ubuntu2~24.04_amd64.deb
wget http://launchpadlibrarian.net/742979756/libc6_2.39-0ubuntu8.3_amd64.deb
sudo dpkg -i --auto-deconfigure libc6_2.39-0ubuntu8.3_amd64.deb
wget http://launchpadlibrarian.net/748295524/gcc-14-base_14.2.0-4ubuntu2~24.04_amd64.deb
sudo dpkg -i gcc-14-base_14.2.0-4ubuntu2~24.04_amd64.deb
wget http://launchpadlibrarian.net/742979745/libc-bin_2.39-0ubuntu8.3_amd64.deb
sudo dpkg -i libc-bin_2.39-0ubuntu8.3_amd64.deb
wget http://launchpadlibrarian.net/723766393/libsctp1_1.0.19+dfsg-2build1_amd64.deb
sudo dpkg -i libsctp1_1.0.19+dfsg-2build1_amd64.deb
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl3t64_3.0.13-0ubuntu3.4_amd64.deb
sudo dpkg -i --auto-deconfigure libssl3t64_3.0.13-0ubuntu3.4_amd64.deb
wget http://launchpadlibrarian.net/722303177/iperf3_3.16-1build2_amd64.deb
wget http://launchpadlibrarian.net/722303180/libiperf0_3.16-1build2_amd64.deb
sudo dpkg -i iperf3_3.16-1build2_amd64.deb libiperf0_3.16-1build2_amd64.deb

*************************************
Alernative traffic generation option
-------------------------------------
- use Node.js as server and curl clients for UE
- Node.js
https://www.digitalocean.com/community/tutorials/how-to-build-a-node-js-application-with-docker
        https://www.digitalocean.com/community/tutorials/nodejs-how-to-use__dirname
https://www.docker.com/blog/getting-started-with-docker-using-node-jspart-i/===> https://www.digitalocean.com/community/tutorials/use-expressjs-to-deliver-html-files

- POST files with curl
https://superuser.com/questions/1054742/how-to-post-file-contents-using-curl

- ewentualnie (odpowiada jakimś "defaultem"). obraz do wyprodukowania
https://github.com/KSonny4/simple-docker-http-server/tree/master

- building - Docker ENTRYPOINT & COMMAND
https://www.cloudbees.com/blog/understanding-dockers-cmd-and-entrypoint-instructions
*************************************
Packetrusher

- Gradiant packetrusher
https://gradiant.github.io/5g-charts/open5gs-packetrusher.html

- check Chart.yaml at the end to verify the version (0.0.2 as of 2024.10.30)
$ helm install packetrusher ./packetrusher --version 0.0.2

- muli-ue mode
https://github.com/HewlettPackard/PacketRusher/discussions/132

*************************************
USING PROMETHEUS

- querying metrics
  - get the # of amf sessions (actually, for amf sessions only 'query=amf_session' below will be sufficient, but ...)
    browser: http://10.254.186.64:9090/api/v1/query?query=amf_session{service="open5gs-amf-metrics",namespace="default"}
    windows: curl 10.254.186.64:9090/api/v1/query -G -d "query=amf_session{service=\"open5gs-amf-metrics\",namespace=\"default\"}"
    linux:   as for windows (above) or 
             curl 10.254.186.64:9090/api/v1/query -G -d 'query=amf_session{service="open5gs-amf-metrics",namespace="default"}' | jq

*************************************
siege - http traffic generator
use in kubernetes: https://cloudyuga.guru/blogs/how-to-tcpdump-in-kubernetes/
parameters: https://linux.die.net/man/1/siege
original: https://github.com/JoeDog/siege

*************************************
*************************************
QUICK GUIDE: ue creation/deletion for UPF scaling
=====================================
Handling the network

- install
$ helm install open5gs ./open5gs-225 --version 2.2.5 --values ./5gSA-values-enable-metrics.yaml

$ helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml
  from local files:
  helm install ueransim-gnb ueransim-gnb-0.2.6/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml

- loging to pods
$ kubectl -n default exec -ti deployment/ueransim-gnb-ues -- /bin/bash

=====================================

Handling ues

- first check current state (current # of UEs)
  NOTE: we adopt a rule that MSISDN of UEs start form the value 0000000001 and subsequent UEs get subsequent MSISDN numbers

$ curl 10.254.186.64:9090/api/v1/query -G -d 'query=amf_session{service="open5gs-amf-metrics",namespace="default"}' | jq
  curl 10.254.186.64:9090/api/v1/query -G -d 'query=amf_session{service="open5gs-amf-metrics",namespace="5gsrusher"}' | jq

- create initial group of UEs (the number of UEs to create configured in file gnb-ues-values.yaml; currently equals 4)
  NOTE: here, we create UEs in groups, each group being implemented in a separate helm release
$ helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml

- create additional group of UEs (the number of UEs to create configured in the command as count=5, starting with MSIMSI=0000000005)
  Note1: more groups can be created in a similar way, but must not exceed the total number of UEs declared in Open%$GS core (mongodb)
  Note2: remember our rule that MSISDN of UEs start form the value 0000000001 and subsequent UEs get subsequent MSISDN numbers
$ helm install -n default ueransim-ues-additional oci://registry-1.docker.io/gradiant/ueransim-ues \
  --set gnb.hostname=ueransim-gnb --set count=5 --set initialMSISDN="0000000005"

- delete additional UEs from a given helm release
$ helm delete ueransim-ues-additional

- NOTE: if you suspect something goes wrong with UE registration, check amf logs:
$ kubectl get pods  <= use appropriate namespace, 
$ kubectl logs open5gs-amf-<amf-pod-suffix>

- from the host (without entering the pod)
  - create
$ kubectl exec deployment/ueransim-gnb-ues -- /bin/bash -c "nr-ue -c ue.yaml -n 1 -i imsi-999700000000011"
  - deregister (also deletes tun interface)
> nr-cli imsi-999700000000011 --exec "deregister switch-off"
$  kubectl exec deployment/ueransim-gnb-ues -- /bin/bash -c 'nr-cli imsi-999700000000004 --exec "deregister switch-off"'
### Perform a de-registration by the UE
### Usage:
###   deregister <normal|disable-5g|switch-off|remove-sim>
    more details on tahat: https://github.com/aligungr/UERANSIM/discussions/738#discussioncomment-11169926

================
- How to tcpdump in kubernetes
https://cloudyuga.guru/blogs/how-to-tcpdump-in-kubernetes/

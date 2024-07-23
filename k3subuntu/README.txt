*******************
PREPARE UBUNTU 22.04
- disable Wayland
https://linuxconfig.org/how-to-enable-disable-wayland-on-ubuntu-22-04-desktop
$ sudo nano /etc/gdm3/custom.conf
  WaylandEnable=false
$ sudo systemctl restart gdm3

- enable IP forwarding
  https://linuxconfig.org/how-to-turn-on-off-ip-forwarding-in-linux
$ sudo sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 0
$ sudo nano /etc/sysctl.conf
  net.ipv4.ip_forward = 1
$ sudo sysctl -p

$ sudo apt update
$ sudo apt upgrade

*******************
INSTALL KUBERNETES

- install k3s on ubuntu
https://www.digitalocean.com/community/tutorials/how-to-setup-k3s-kubernetes-cluster-on-ubuntu
(multinode k3s with Calico) https://docs.tigera.io/calico/latest/getting-started/kubernetes/k3s/multi-node-install

- simplest (no calico, etc.)
# $ curl -sfL https://get.k3s.io  | INSTALL_K3S_EXEC="--kube-apiserver-arg=feature-gates=InPlacePodVerticalScaling=true" sh -

- install control node with appropriate settings (no flannel and traefik, enable InPlacePodVerticalScaling)
$ curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-backend=none --cluster-cidr=10.42.0.0/16 --disable-network-policy --disable=traefik --kube-apiserver-arg=feature-gates=InPlacePodVerticalScaling=true" sh -

Note: to enable external access to the API (e.g., to use kubectl) when server IP address visible externally as <floating-ip-address> is different than server IP address valid within the cluster (e.g., when the server is exposed by floating IP in OpenStack) then additional option --tls-san=<floating-ip-address> should be included in the part INSTALL_K3S_EXEC="...". This will make x509 certificate for this address become valid. For example:
$ curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-backend=none --cluster-cidr=10.42.0.0/16 --disable-network-policy --disable=traefik --kube-apiserver-arg=feature-gates=InPlacePodVerticalScaling=true --tls-san=10.254.186.64" sh -
  ref. https://github.com/k3s-io/k3s/issues/1381#issuecomment-582013411
       https://docs.k3s.io/installation/configuration#registration-options-for-the-k3s-server

- install agent(s)
$ curl -sfL https://get.k3s.io | K3S_URL=https://<serverip>:6443 K3S_TOKEN=nodetoken sh -
  where K3S_TOKEN which is stored in /var/lib/rancher/k3s/server/node-token file in the main Node

- uninstall server: run on server
$ /usr/local/bin/k3s-uninstall.sh
- uninstall agents: run on agents
$ /usr/local/bin/k3s-agent-uninstall.sh

******************************
CALICO
https://docs.tigera.io/calico/latest/getting-started/kubernetes/k3s/quickstart

- install calico operator and custom resources
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
- install calico
#$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml <===== update CIDR in custom-resources.yaml according to your environment if needed - see a couple of lines below.
$ kubectl create -f calico-custom-resources.yaml
- final checks
$ watch kubectl get pods --all-namespaces
$ kubectl get nodes

Plik calico-custom-resources.yaml:
----------------------------------
# https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
# This section includes base Calico installation configuration.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    ipPools:
    - name: default-ipv4-ippool
      # blocks are smaller chunks that are associated with a particular node in the cluster. Each node in the cluster can
      # have one or more blocks associated with it. Here, the pool will comprise 8 blocks each containing 64 addresses.
      blockSize: 26
      # this cidr MUST be the same as the one used during k3s installatio in argument --cluster-cidr=10.42.0.0/16
      cidr: 10.42.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()

---

# This section configures the Calico API server.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.APIServer
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}

********************************

$ /usr/local/bin/k3s-uninstall.sh

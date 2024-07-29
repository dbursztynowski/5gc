*******************
(for Virtual Box)
PREPARE UBUNTU 22.04

- enable terminal
  https://www.youtube.com/watch?v=NvTMQBxGqDw
Settings -> Region and language -> change Language=English(UK) -> Reboot

- add user to the sudo group
$ su -
# sudo usermod -aG sudo <username>
# visudo ==> add:
  <username> ALL=(ALL) NOPASSWD:ALL
# exuit

- disable Wayland (if you experience problems with the display)
https://linuxconfig.org/how-to-enable-disable-wayland-on-ubuntu-22-04-desktop
$ sudo nano /etc/gdm3/custom.conf
  WaylandEnable=false
$ sudo systemctl restart gdm3

- enable VBoxGuestAdditions
VM -> Devices -> Mount image with Guest Additions -> cd /media/ubuntu/VBox_GAs_xyz (xyz according to your env) -> 
   sudo VBoxLinuxAdditions.run -> VM 

- enable IP forwarding
  https://linuxconfig.org/how-to-turn-on-off-ip-forwarding-in-linux <== also torubleshooting
  check if required
$ sudo sysctl net.ipv4.ip_forward
net.ipv4.ip_forward = 0   => required if 0
$ sudo nano /etc/sysctl.conf
  net.ipv4.ip_forward = 1
$ sudo sysctl -p

$ sudo apt update
$ sudo apt upgrade

$ sudo apt install git

- for any case (e.g. scp copy) enable PasswordAuthentication
$ sudo nano /etc/ssh/sshd_config
  PasswordAuthentication yes
$ sudo service ssh restart

*******************

OpenStack
- to lunch instance from image with password authentication enabled (here pwd=ubuntu)
  - insert the following into Configuration/Customization script pane in OpenStack Dashboard
#cloud-config
password: t6ygfr5
chpasswd: { expire: False }
ssh_pwauth: True

- more on this: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux_atomic_host/7/html/installation_and_configuration_guide/setting_up_cloud_init#setting_up_cloud_init

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

- SCTP enablement in the cluster:
  ------------------------------
  feature-gates: SCTPSupport=true => --kube-apiserver-arg=feature-gates=SCTPSupport=true
$ curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-backend=none --cluster-cidr=10.42.0.0/16 --disable-network-policy --disable=traefik --kube-apiserver-arg=feature-gates=InPlacePodVerticalScaling=true,SCTPSupport=true --tls-san=10.254.186.64" sh -

- install agent(s)
$ curl -sfL https://get.k3s.io | K3S_URL=https://<serverip>:6443 K3S_TOKEN=$(cat node-token) sh -
  where K3S_TOKEN=$(cat node-token) is stored in /var/lib/rancher/k3s/server/node-token file in the main Node
  (or one can copy-paste the token from the file directly into the command)

- uninstall server: run on server
$ /usr/local/bin/k3s-uninstall.sh
- uninstall agents: run on agents
$ /usr/local/bin/k3s-agent-uninstall.sh

******************************
Note1: in case of mongodb connectivity problems maybe flannel with IPSec backend can be a solution for CNI (still to be confirmed/checked)
Note2: on SCTP support in cilium: https://github.com/cilium/cilium/issues/20490

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
HELM
- install helm
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh

********************************

$ /usr/local/bin/k3s-uninstall.sh

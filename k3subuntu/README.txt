- install k3s on ubuntu
https://www.digitalocean.com/community/tutorials/how-to-setup-k3s-kubernetes-cluster-on-ubuntu

# $ curl -sfL https://get.k3s.io  | INSTALL_K3S_EXEC="--kube-apiserver-arg=feature-gates=InPlacePodVerticalScaling=true" sh -

- install with appropriate settings (no flannel and traefik, enable InPlacePodVerticalScaling)
$ curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-backend=none --cluster-cidr=10.42.0.0/16 --disable-network-policy --disable=traefik --kube-apiserver-arg=feature-gates=InPlacePodVerticalScaling=true" sh -

Note: to enable external access to the API (e.g., for kubectl) when server IP address visible externally as <floating-ip-address> is different than server IP address within the cluster (e.g., when the server is exposed by floating IP in OpenStack) add additional option --tls-san=<floating-ip-address> in the part INSTALL_K3S_EXEC="...". 


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
      blockSize: 26
      # this cidr MUST be thesame as the one used during k3s installatio in argument --cluster-cidr=10.42.0.0/16
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

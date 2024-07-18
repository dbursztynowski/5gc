- minikube with proper version, size, calico CNI, and feature-gate InPlacePodVerticalScaling enabled + settings to enable running kube-prometheus
$ minikube start --kubernetes-version=v1.30.0 --driver=docker --container-runtime=containerd --cpus=4 --memory=8g --disk-size=20g --feature-gates=InPlacePodVerticalScaling=true --cni=calico --bootstrapper=kubeadm --extra-config=kubelet.authentication-token-webhook=true --extra-config=kubelet.authorization-mode=Webhook --extra-config=scheduler.bind-address=0.0.0.0 --extra-config=controller-manager.bind-address=0.0.0.0

==============================================
- feature gates (FG)
  - checking which FG are enabled
  kubectl get --raw /metrics | grep kubernetes_feature_enabled
  - setting feature gate in minikube (this recreates the cluster from scratch - deletes existing workloads)
  minikube start --feature-gates=InPlacePodVerticalScaling=true

==============================================
- install kube-prometheus
https://github.com/prometheus-operator/kube-prometheus

$ kubectl apply --server-side -f manifests/setup
$ kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring
$ kubectl apply -f manifests/

- tear down the stack
$ kubectl delete --ignore-not-found=true -f manifests/ -f manifests/setup

  
  

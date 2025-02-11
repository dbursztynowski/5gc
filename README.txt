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
(check the compatibility matrix at this link and select the right varsion one for you to wget as shown below)

$ mkdir kube-prometheus
$ wget https://github.com/prometheus-operator/kube-prometheus/tree/main kube-prometheus

$ kubectl apply --server-side -f manifests/setup
$ kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring
$ kubectl apply -f manifests/

Note: you may need to follow the instructions from the SPIW lab k3s install guide (possible need to update Prometheus and Grafana cluster roles, services and network policies, and Grafana deployment (update readinessProbe and add livenessProbe)).

- tear down the stack
$ kubectl delete --ignore-not-found=true -f manifests/ -f manifests/setup

=================================================
- Setting Prometheus into the push mode by enabling the remoteWrite capability

To enable remoteWrite capability on Prometheus to push metrics to remote receiver without authentication, 
add the the following to the prometheus-prometheus.yaml file, section Prometheus.prometheusSpec. In case of 
authentication problems, refer to https://grafana.com/docs/grafana-cloud/monitor-infrastructure/kubernetes-monitoring/configuration/config-other-methods/prometheus/remote-write-helm-operator/.

For a more detailed tutorial on using remoteWrite, check also: https://developers.redhat.com/articles/2023/11/30/how-set-and-experiment-prometheus-remote-write#lab_setup. For a description of the remoteWrite/write_relabel options see https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write.

It can be more convinient to deploy kube-prometheus using Helm.

#  prometheusSpec:
    remoteWrite:
    - url: "<Your Metrics instance remote_write endpoint>"
#      basicAuth:
#          username:
#            name: kubepromsecret
#            key: username
#          password:
#            name: kubepromsecret
#            key: password



  
  

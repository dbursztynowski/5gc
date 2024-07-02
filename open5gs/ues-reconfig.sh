# re-run ueransim-gnb to patch ueransim-gnb-ues with sidecar container netshoot

echo -e "\n===> uninstalling ueransim-gnb ============>"
helm uninstall ueransim-gnb
#kubectl wait --for=jsonpath='{.status.phase}'=Running pod -n default --all
echo -e "\n===> uearnsim-gnb uninstalled, waiting for pods to get destoyd ============>"
kubectl wait --for=condition=Ready pod -n default --all
echo -e "\n===> uearnsim-gnb uninstalled, installing new instance ============>"
helm install ueransim-gnb oci://registry-1.docker.io/gradiant/ueransim-gnb --version 0.2.6 --values ./gnb-ues-values.yaml

echo -e "\n===> uearnsim-gnb installed, waiting for pods to get Ready ============>"
kubectl wait --for=condition=Ready pod -n default --all
echo -e "\n===> patching ueransim-gnb-ues deployment============>"
kubectl patch deployment ueransim-gnb-ues --patch-file patch-ues.yaml
echo -e "\n===> waiting for pod to get Ready ============>"
kubectl wait --for=condition=Ready pod -n default --all
echo -e "\n===> deployment patched ============>"

echo "\n===========================\n===========================\n===========================\n"
kubectl get deployment ueransim-gnb-ues -o yaml
echo -e "\n===========================\n===========================\n===========================\n"
kubectl describe deployment ueransim-gnb-ues 

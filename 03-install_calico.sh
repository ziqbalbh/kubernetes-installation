# Official Calico documentation :: https://docs.projectcalico.org
chmod +x /usr/local/bin/calicoctl

curl -O calicoctl -L  https://github.com/projectcalico/calico/releases/download/v3.25.0/calicoctl-linux-amd64
sudo mv calicoctl /usr/local/bin/calicoctl
sudo chown +x $(id -u):$(id -g) /usr/local/bin/calicoctl


vi calicoctl.cfg

apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "kubernetes"
  kubeconfig: "/home/rik/.kube/config"


sudo mkdir -p /etc/calico
sudo cp calicoctl.cfg /etc/calico




kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml

curl -L -O https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/custom-resources.yaml

apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 10.10.0.0/24
      encapsulation: None
      natOutgoing: Enabled
      nodeSelector: all()


kubectl create -f custom-resources.yaml

kubectl get pods -n calico-system

# To verify if your cluster is working fine or not with Calico

calicoctl version

sudo calicoctl node status

calicoctl get ippools default-ipv4-ippool -o yaml

calicoctl ipam show

calicoctl ipam show --show-blocks

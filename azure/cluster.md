https://blog.nillsf.com/index.php/2021/10/29/setting-up-kubernetes-on-azure-using-kubeadm/

$rg = "rgk8s"
$loc = "eastus2"
$vnet = "vnetk8s"
$snet = "cluster"
$nsg = "nsgk8s"
$un = "vmadmin"
$pw = "jQknL765Gsk7"
$pip = "pipcluster"
$lb = "lbcluster"
$bp = "masternodes"

az group create -n $rg -l $loc

az network vnet create --resource-group $rg --name $vnet --address-prefix 172.10.0.0/16 --subnet-name $snet --subnet-prefix 172.10.1.0/24

az network nsg create --resource-group $rg --name $nsg

az network nsg rule create --resource-group $rg --nsg-name $nsg --name ssh --protocol tcp --priority 1000 --destination-port-range 22 --access allow

az network nsg rule create --resource-group $rg --nsg-name $nsg --name kubeapi --protocol tcp --priority 1001 --destination-port-range 6443 --access allow

az network nsg rule create --resource-group $rg --nsg-name $nsg --name http --protocol tcp --priority 1002 --destination-port-range 80 --access allow

az network nsg rule create --resource-group $rg --nsg-name $nsg --name https --protocol tcp --priority 1003 --destination-port-range 443 --access allow

az network vnet subnet update -g $rg -n $snet --vnet-name $vnet --network-security-group $nsg

az vm create -n kubemaster1 -g $rg --image UbuntuLTS --vnet-name $nsg --subnet $snet --admin-username $un --admin-password $pw --size Standard_B2s --nsg $nsg --public-ip-sku Standard --no-wait

# az vm create -n kubemaster2 -g $rg --image UbuntuLTS --vnet-name $nsg --subnet $snet --admin-username $un --admin-password $pw --size Standard_B2s --nsg $nsg --public-ip-sku Standard --no-wait

az vm create -n kubeworker1 -g $rg --image UbuntuLTS --vnet-name $nsg --subnet $snet --admin-username $un --admin-password $pw --size Standard_B2s --nsg $nsg --public-ip-sku Standard --no-wait

# az vm create -n kubeworker2 -g $rg --image UbuntuLTS --vnet-name $nsg --subnet $snet --admin-username $un --admin-password $pw --size Standard_B2s --nsg $nsg --public-ip-sku Standard --no-wait



az network public-ip create --resource-group $rg --name $pip --sku Standard --dns-name zk8scluster

az network lb create --resource-group $rg --name $lb --sku Standard --public-ip-address $pip --frontend-ip-name $pip --backend-pool-name $bp

az network lb probe create --resource-group $rg --lb-name $lb --name kubeapi --protocol tcp --port 6443   

az network lb rule create --resource-group $rg --lb-name $lb --name kubeapi --protocol tcp --frontend-port 6443 --backend-port 6443 --frontend-ip-name $pip --backend-pool-name $bp --probe-name kubeapi --disable-outbound-snat true --idle-timeout 15 --enable-tcp-reset true

az network nic ip-config address-pool add --address-pool $bp --ip-config-name ipconfigkubemaster1 --nic-name kubemaster1VMNic --resource-group $rg --lb-name $lb

# az network nic ip-config address-pool add --address-pool $bp --ip-config-name ipconfigkubemaster2 --nic-name kubemaster2VMNic --resource-group $rg --lb-name $lb


$m1ip=$(az vm list-ip-addresses -g $rg -n kubemaster1 --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
$m2ip=$(az vm list-ip-addresses -g $rg -n kubemaster2 --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
$w1ip=$(az vm list-ip-addresses -g $rg -n kubeworker1 --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
$w2ip=$(az vm list-ip-addresses -g $rg -n kubeworker2 --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

ssh $un@$m1ip
ssh $un@$w1ip

sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install vim git curl wget kubelet kubeadm kubectl containerd

sudo apt-mark hold kubelet kubeadm kubectl

kubectl version --client && kubeadm version


cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system


sudo kubeadm init --control-plane-endpoint "zk8scluster.eastus2.cloudapp.azure.com:6443" --upload-certs


To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join zk8scluster.eastus2.cloudapp.azure.com:6443 --token np2ve0.jx3w2fnht0asy8nw \
        --discovery-token-ca-cert-hash sha256:103e0c7ce1bfe1283aa295c8845bbd756103f6ecfbb8e09847089bb2d678b39b \
        --control-plane --certificate-key 7883219766dc5f98533c5a197c5138cb4c3a945b02230359c1ce208f01a4372d

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join zk8scluster.eastus2.cloudapp.azure.com:6443 --token np2ve0.jx3w2fnht0asy8nw \
        --discovery-token-ca-cert-hash sha256:103e0c7ce1bfe1283aa295c8845bbd756103f6ecfbb8e09847089bb2d678b39b




kubectl create -f https://raw.githubusercontent.com/NillsF/blog/master/kubeadm/azure-vote.yml
kubectl port-forward service/azure-vote-front 8080:80        


curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O

kubectl apply -f calico.yaml

kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
ps -ef | grep "cluster-cidr"
kubectl cluster-info dump | grep -m 1 cluster-cidr
kubeadm config print init-defaults

kubeadm config print init-defaults | grep Subnet
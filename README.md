One click HDP


yum install yum-utils wget  -y
yum-config-manager --add-repo \
https://download.docker.com/linux/centos/docker-ce.repo

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yumdownloader --assumeyes --destdir=/root/k8_offline/yum --resolve yum-utils
yumdownloader --assumeyes --destdir=/root/k8_offline/dm --resolve device-mapper-persistent-data
yumdownloader --assumeyes --destdir=/root/k8_offline/lvm2 --resolve lvm2
yumdownloader --assumeyes --destdir=/root/k8_offline/docker-ce --resolve docker-ce
yumdownloader --assumeyes --destdir=/root/k8_offline/se --resolve container-selinux
yumdownloader --assumeyes --destdir=/root/k8_offline/k8 --resolve  kubeadm ebtables yum-utils kubelet kubectl
yumdownloader --assumeyes --destdir=/root/k8_offline/k8_worker --resolve  kubeadm 

yum install -y --cacheonly --disablerepo=* /root/k8_offline/yum/*.rpm
yum install -y --cacheonly --disablerepo=* /root/k8_offline/dm/*.rpm
yum install -y --cacheonly --disablerepo=* /root/k8_offline/lvm2/*.rpm

Execute the following command to install container-selinux:
yum install -y --cacheonly --disablerepo=* /root/k8_offline/se/*.rpm

Execute the following command to install Docker:
yum install -y --cacheonly --disablerepo=* /root/k8_offline/docker-ce/*.rpm

wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml





Start docker.
systemctl enable docker
systemctl start docker


docker pull k8s.gcr.io/kube-apiserver:v1.17.1
docker save k8s.gcr.io/kube-apiserver:v1.17.1     >  /root/k8_offline/kube-apiserver:v1.17.1.tar 

docker pull k8s.gcr.io/kube-controller-manager:v1.17.1
docker save k8s.gcr.io/kube-controller-manager:v1.17.1 >/root/k8_offline/kube-controller-manager:v1.17.1.tar

docker pull k8s.gcr.io/kube-scheduler:v1.17.1
docker save k8s.gcr.io/kube-scheduler:v1.17.1 >/root/k8_offline/kube-scheduler:v1.17.1.tar

docker pull k8s.gcr.io/kube-proxy:v1.17.1
docker save k8s.gcr.io/kube-proxy:v1.17.1 >/root/k8_offline/kube-proxy:v1.17.1.tar

docker pull k8s.gcr.io/pause:3.1
docker save k8s.gcr.io/pause:3.1 >/root/k8_offline/pause:3.1.tar

docker pull k8s.gcr.io/etcd:3.4.3-0
docker save k8s.gcr.io/etcd:3.4.3-0 >/root/k8_offline/etcd:3.4.3-0.tar

docker pull k8s.gcr.io/coredns:1.6.5
docker save k8s.gcr.io/coredns:1.6.5 >/root/k8_offline/coredns:1.6.5.tar

docker pull quay.io/coreos/flannel:v0.11.0-amd64
docker save  quay.io/coreos/flannel:v0.11.0-amd64 >/root/k8_offline/flannel-v0.11.0.tar





Execute the following commands to verify docker:
systemctl status docker
docker version

Prequisuite
Add below are on k8-master
vi /etc/sysctl.d/kubernetes.conf 
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
echo "kernel.sem = 250 32000 32 4096" >> /etc/sysctl.conf
echo "vm.max_map_count = 5242880" >> /etc/sysctl.conf

Run below commands.
modprobe br_netfilter IF iptables running.
sysctl --system
swapoff -a
sed -e '/swap/s/^/#/g' -i /etc/fstab

RUn all master and worker node.
Disabled firewalld
service firewalld stop
chkconfig firewalld off
iptables -F 
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config




yum install -y --cacheonly --disablerepo=* /root/k8_offline/k8/*.rpm

on worker node
yum install -y --cacheonly --disablerepo=* /root/k8_offline/k8_worker/*.rpm
kubeadm config images list


systemctl enable kubelet.service


docker load < /root/k8_offline/k8/kube-apiserver:v1.17.1.tar 
docker load < /root/k8_offline/k8/kube-controller-manager:v1.17.1.tar
docker load < /root/k8_offline/k8/kube-scheduler:v1.17.1.tar
docker load < /root/k8_offline/k8/kube-proxy:v1.17.1.tar
docker load < /root/k8_offline/k8/pause:3.1.tar
docker load < /root/k8_offline/k8/etcd:3.4.3-0.tar
docker load < /root/k8_offline/k8/coredns:1.6.5.tar
docker load < /root/k8_offline/k8/flannel-v0.11.0.tar

echo "kernel.sem = 250 32000 32 4096" >> /etc/sysctl.conf
echo "vm.max_map_count = 5242880" >> /etc/sysctl.conf
echo "source <(kubectl completion bash)" >> ~/.bashrc
sysctl -p
kubectl version


kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.17.2
kubeadm config images list
mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:
kubeadm join 172.20.99.21:6443 --token 1hxg55.44ka182nhd7addw8 \
    --discovery-token-ca-cert-hash sha256:7188ea371bc7a5579f3b0e14905e89d5690d60328f4dd4d1c0b76d5256058ee9


	grep -q "KUBECONFIG" ~/.bashrc || {
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc
    . ~/.bashrc
}


kubectl get nodes
kubectl apply -f /root/k8_offline/k8/kube-flannel.yml
kubectl get pods --all-namespaces



kubectl taint nodes --all node-role.kubernetes.io/master-


	
grep -q "KUBECONFIG" ~/.bashrc || {
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc
. ~/.bashrc
}




Node NotReady debugg
https://stackoverflow.com/questions/47107117/how-to-debug-when-kubernetes-nodes-are-in-not-ready-state
https://github.com/kubernetes/kubernetes/issues/32522


Installation
https://www.assistanz.com/steps-to-install-kubernetes-cluster-manually-using-centos-7/
https://docs.genesys.com/Documentation/GCXI/9.0.0/Dep/DockerOffline
https://www.tecmint.com/install-kubernetes-cluster-on-centos-7/


COmmands
kubectl api-versions
kubectl cluster-info
kubectl cluster-info dump
kubectl explain
kubectl api-resources
kubectl get pod pod_name -o yaml 
kubectl get pods pod_name -n kube-system  --server-print=false
kubectl get pods --sort-by=.metadata.name
kubectl get ds -n service-name
 kubectl get rc,services -n kube-system
 kubectl get pods --field-selector=spec.nodeName=server_name
 kubectl describe nodes node_name
 kubectl describe pods/<pod-name>
 # Display the details of all the pods that are managed by the replication controller named <rc-name>.
# Remember: Any pods that are created by the replication controller get prefixed with the name of the replication controller.
kubectl describe pods <rc-name>
kubectl describe pods
kubectl plugin list
kubectl config current-context
kubectl config set-cluster NAME
kubectl rollout undo deployment/tomcat

kubectl get node --no-headers -o custom-columns=NAME:.metadata.name


https://stackoverflow.com/questions/52860209/kubernetes-1-11-could-not-find-heapster-for-metrics
https://github.com/kubernetes-retired/heapster
https://github.com/kubernetes-sigs/metrics-server

https://stackoverflow.com/questions/56850650/reset-kubernetes-cluster

https://kubernetes.io/docs/reference/kubectl/cheatsheet/

Remove kubernetes
docker system prune -a
sudo docker rm `docker ps -a -q`
sudo docker rmi `docker images -q`
yum remove docker-ce -y

sudo kubeadm reset 
sudo yum remove kubeadm kubectl kubelet kubernetes-cni kube*    -y  
sudo yum autoremove -y 
sudo rm -rf ~/.kube


sudo kubeadm reset -f && 
 sudo systemctl stop kubelet && 
 sudo systemctl stop docker && 
 sudo rm -rf /var/lib/cni/ && 
 sudo rm -rf /var/lib/kubelet/* && 
 sudo rm -rf /etc/cni/ && 
 sudo ifconfig cni0 down && 
 sudo ifconfig flannel.1 down && 
 sudo ifconfig docker0 down && 
 sudo ip link delete cni0 && 
 sudo ip link delete flannel.1
 
 
 
 
CREATE USER 'mosaic'@'%' IDENTIFIED BY 'Mosaic123!';
grant all privileges on *.* to 'mosaic'@'%' identified by 'Mosaic123!';
grant all privileges on *.* to 'mosaic'@'localhost' identified by 'Mosaic123!';
grant all privileges on *.* to 'mosaic'@'10.70.30.85' identified by 'Mosaic123!';
grant all privileges on *.* to 'mosaic'@'mosaicweb.solar.com' identified by 'Mosaic123!';
FLUSH PRIVILEGES;
commit;




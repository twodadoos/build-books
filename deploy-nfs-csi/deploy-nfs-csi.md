# Deploy NFS Peristent Storage in Kubernetes

## Install and configure NFS services on Rocky Linux

### On NFS server

1.  Update system packages
```
sudo dnf -y update
```
2. Install NFS packages
```
sudo dnf -y install nfs-utils
```
3. Enable and start NFS related services
```
sudo systemctl enable --now nfs-server rpcbind
```
4. Configure firewall to allow NFS traffic
```bash
sudo firewall-cmd --permanent --add-service={nfs,rpc-bind,mountd}
sudo firewall-cmd --reload
```
5. Create NFS export directory
```
sudo mkdir -p /srv/nfs/share/example
```
6.  Set directory ownership and permissions
```
sudo chown -R nobody:nobody /srv/nfs/share/example
sudo chmod 755 /srv/nfs/share/example
```
7.  Configure NFS exports file
```
sudo vim /etc/exports
```
#### Example:
```
/srv/nfs/share/example   192.168.10.205/24(rw,sync,no_subtree_check)
/srv/nfs/backups         10.0.0.0/16(ro,sync,no_subtree_check)
/srv/nfs/media           172.16.50.25(rw,sync,no_root_squash,no_subtree_check)
```
8.  Apply export configuration
```
sudo exportfs -rav
```
9. Verify NFS exports are active
```
sudo exportfs -v
```

### On NFS clients (**Required on every Kubernetes node hosting pods meant to have NFS access**)

1.  Install NFS packages
#### On Rocky Linux or Red Hat
```
sudo dnf -y install nfs-utils
```
#### On Debian or Ubuntu
```
sudo apt install nfs-common
```
2. Create directory for mount point
```
sudo mkdir -p /mnt/nfs/share
```
3. Mount NFS share
```
sudo mount -t nfs 192.168.0.154:/srv/nfs/share/example /mnt/nfs/share
```
4. To make mount permanent edit /etc/fstab file and append
```
192.168.10.205:/srv/nfs/share/example /mnt/nfs/share nfs defaults,_netdev 0 0
```

## Deploy NFS CSI storage driver into Kubernetes

### Using kubectl
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/deploy/rbac-csi-nfs.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/deploy/csi-nfs-driverinfo.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/deploy/csi-nfs-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/deploy/csi-nfs-node.yaml
```
### Using Helm
```
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update

helm install nfs-csi csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system
```
##### Verify pods running
```
kubectl --namespace=kube-system get pods --selector="app.kubernetes.io/instance=nfs-csi"
```

### Create NFS StorageClass
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
provisioner: nfs.csi.k8s.io
parameters:
  server: <nfs server IP address>
  share: /example/exported/share
reclaimPolicy: Retain
volumeBindingMode: Immediate
mountOptions:
  - hard
  - nfsvers=4.1
```

#### [Optional] Make NFS StorageClass default
```
kubectl patch storageclass nfs-csi \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Create PersistentVolumeClaim
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-test-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-csi
  resources:
    requests:
      storage: 1Gi
```
##### Verify PVC is Bound
```
kubectl get pvc
```

Once Bound, there should now be a new, empty directory on the NFS server host, for example:
```
pvc-dbdbc367-fdd6-428a-8fa6-91204b55030e
```


# Install and configure NFS services on Rocky Linux

## On NFS server

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

**Ensure services start on boot**

```bash
sudo systemctl enable nfs-server
```

## On NFS clients
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
sudo mount -t nfs 192.168.0.0:/srv/nfs/share/example /mnt/nfs/share
```
4. To make mount permanent edit /etc/fstab file and append
```
192.168.10.205:/srv/nfs/share/example /mnt/nfs/share nfs defaults,_netdev 0 0
```
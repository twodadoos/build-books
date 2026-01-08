# Install local Kubernetes Cluster 

## Environment:
* Ubuntu 22.04.5 LTS
* libvirt 8.0.0
* QEMU 6.2.0

## Prerequisites:
* Fully provisioned and updated hosts
* Linux host root access
* Internet access

### Assumptions and preamble

While this approach is valid for cloud deployments (e.g. onto EC2 instances in AWS) it's also one that's been tested and refined within a local, libvirt environment; thus, it's assumed that's how you might try it first in hope it'll be easier to succeed again, elsewhere, sooner.

An even faster way forward is to utilize [this Bash script](provision-k8s-nodes-ubuntu.sh)
for all installation operations, up to the very first Control Plane and Worker node configuration steps on each target host.

This build book draws from commands in that script and offers additional guidance by sharing next steps for completing the installation, such that the final result ought to be a new, complete, and operational Kubernetes cluster.
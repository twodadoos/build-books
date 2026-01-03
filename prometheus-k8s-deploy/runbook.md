# Run Book - Deploy Prometheus & Grafana (kube-prometheus-stack) with SMTP into Kubernetes Cluster

## Prerequisites:
* Fully operational Kubernetes cluster
* Kubectl
* Helm
* SMTP credentials (e.g. Gmail App Password)

### Pre-deployment:

Persistent Storage configuration:

1. Run on node that will host Grafana:

```
sudo mkdir -p /data/grafana
sudo chown -R 472:472 /data/grafana
sudo chmod 755 /data/grafana
```

2. Create a PersistentVolume (PV)

Save as grafana-pv.yaml:

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: grafana-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  local:
    path: /data/grafana
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - <NODE_NAME>
```

3. Apply it:

```
kubectl apply -f grafana-pv.yaml
```


4.  Verify:

```
kubectl get pv
```

5. Create the PersistentVolumeClaim (PVC)

Save as grafana-pvc.yaml:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: kube-prometheus-stack
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: ""
  volumeName: grafana-pv
```

6. Apply it:

```
kubectl apply -f grafana-pvc.yaml
```

7.  Verify:

```
kubectl get pvc -n kube-prometheus-stack
```

Status should be Bound.

## Deployment

1. Add and or update Helm repository:

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm repo update
```

2. Select target Kubernetes cluster:

```
kubectl config use-context <target-cluster-context>
```

Verify with:

```
kubectl config current-context
```

3. Create new kube-prometheus-stack namespace:

```
kubectl create namespace kube-prometheus-stack
```

4. Create Kubernetes Secret for SMTP user and password:

```
kubectl create secret generic grafana-smtp-secret \
  --namespace kube-prometheus-stack \
  --from-literal=GF_SMTP_USER="example@gmail.com" \
  --from-literal=GF_SMTP_PASSWORD="abcd efgh ijkl mnop"
```

Verify with:

```
kubectl get secret grafana-smtp-secret -n kube-prometheus-stack

kubectl describe secret grafana-smtp-secret -n kube-prometheus-stack
```

5. Create Kubernetes Secret for Grafana admin user

```
kubectl create secret generic grafana-admin-secret \
  -n kube-prometheus-stack \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='StrongPasswordHere'
```

Verify with:

```
kubectl get secret grafana-admin-secret -n kube-prometheus-stack

kubectl describe secret grafana-admin-secret -n kube-prometheus-stack
```

5.  Create values-grafana.yaml file with:

```
grafana:
  # --- SMTP configuration (non-sensitive) ---
  env:
    GF_SMTP_ENABLED: "true"
    GF_SMTP_HOST: "smtp.gmail.com:587"
    GF_SMTP_FROM_ADDRESS: "example@gmail.com"
    GF_SMTP_FROM_NAME: "Grafana Alerts"
    GF_SMTP_SKIP_VERIFY: "true"
    GF_DATE_FORMATS_DEFAULT_TIMEZONE: browser
     GF_FEATURE_TOGGLES_ENABLE: ""

  # --- Sensitive values come from a Secret ---
  envFromSecret: grafana-smtp-secret

  # --- Expose Grafana ---
  service:
    type: NodePort
    nodePort: 32000

  admin:
    existingSecret: grafana-admin-secret
    userKey: admin-user
    passwordKey: admin-password
 
  nodeSelector:
    kubernetes.io/hostname: <node to host Grafana Persistent Storage>
    
  persistence:
    enabled: true
    existingClaim: grafana-pvc
    mountPath: /var/lib/grafana
  
  initChownData:
    enabled: false
``` 

6. Install Prometheus & Grafana with SMTP Enabled

Note: For kube-prometheus-stack ≥ 80.x, Grafana SMTP must be configured via environment variables (grafana.env.*).

```
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace kube-prometheus-stack \
  -f values-grafana.yaml
```

[OPTIONAL] Watch pods and deployment create:

```
kubectl get pods -n kube-prometheus-stack -w

kubectl rollout status deployment kube-prometheus-stack-grafana -n kube-prometheus-stack

kubectl exec -n kube-prometheus-stack deploy/kube-prometheus-stack-grafana -- env | grep GF_SMTP

kubectl -n kube-prometheus-stack get pods -l release=kube-prometheus-stack
```

All pods should be in Running state.

7. Verify Grafana SMTP Configuration (Authoritative Check)

```
kubectl exec -n kube-prometheus-stack \
  deploy/kube-prometheus-stack-grafana \
  -- env | grep GF_SMTP
```

Expected output includes:

GF_SMTP_ENABLED=true
GF_SMTP_HOST=...
GF_SMTP_USER=...

8. Obtain Grafana Admin Password:

```
kubectl -n kube-prometheus-stack get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Username: admin

9. Access Grafana UI

```
http://<any-node-ip>:32000
```

Log in using the admin credentials.

10. Validate SMTP Functionality

Navigate to:
Home → Alerting → Contact points

Create a new Email contact point

Click Test

Confirm the test email is successfully delivered

Notes:

### SMTP settings will not appear in grafana.ini on newer chart versions

### Grafana reads SMTP config only at startup

### To change SMTP later, run helm upgrade and ensure Grafana pods restart

End of Run Book


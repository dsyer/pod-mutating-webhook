# Kubernetes Mutating Admission Webhook for sidecar injection

This tutoral shows how to build and deploy a [MutatingAdmissionWebhook](https://kubernetes.io/docs/admin/admission-controllers/#mutatingadmissionwebhook-beta-in-19) that injects a nginx sidecar container into pod prior to persistence of the object.

## Prerequisites

Kubernetes 1.9.0 or above with the `admissionregistration.k8s.io/v1beta1` API enabled. Verify that by the following command:
```
kubectl api-versions | grep admissionregistration
```
The result should be:
```
admissionregistration.k8s.io/v1beta1
```

In addition, the `MutatingAdmissionWebhook` and `ValidatingAdmissionWebhook` admission controllers should be added and listed in the correct order in the admission-control flag of kube-apiserver.

## Build

Build and push docker image
   
```
./build
```

## Deploy

1. Create a signed cert/key pair and store it in a Kubernetes `secret` that will be consumed by sidecar deployment
```
./deployment/webhook-create-signed-cert.sh \
    --service sidecar-injector-webhook-svc \
    --secret sidecar-injector-webhook-certs \
    --namespace default
```

2. Patch the `MutatingWebhookConfiguration` by creating `ca.bundle` with correct value from Kubernetes cluster
```
kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' > deployment/base/ca.bundle
```

3. Deploy resources
```
kustomize build deployment/base | kubectl apply -f -
```

## Verify

1. The sidecar inject webhook should be running
```
$ kubectl get pods
NAME                                                  READY     STATUS    RESTARTS   AGE
sidecar-injector-webhook-deployment-bbb689d69-882dd   1/1       Running   0          5m
$ kubectl get deployment
NAME                                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
sidecar-injector-webhook-deployment   1         1         1            1           5m
```

2. Label the default namespace with `sidecar-injector=enabled`
```
kubectl label namespace default sidecar-injector=enabled
$ kubectl get namespace -L sidecar-injector
NAME          STATUS    AGE       SIDECAR-INJECTOR
default       Active    18h       enabled
kube-public   Active    18h
kube-system   Active    18h
```

3. Deploy an app in Kubernetes cluster, take `sleep` app as an example
```
$ cat <<EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      annotations:
        sidecar-injector-webhook.morven.me/inject: "yes"
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: tutum/curl
        command: ["/bin/sleep","infinity"]
EOF
```

4. Verify sidecar container injected
```
$ kubectl get pods
NAME                     READY     STATUS        RESTARTS   AGE
sleep-5c55f85f5c-tn2cs   2/2       Running       0          1m
$ kubectl port-forward pod/sleep-5db6c7c975-h9slk 8000:80
$ curl localhost:8000
<html>
...
</html>
```

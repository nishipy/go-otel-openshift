# About

This repo includes a sample go app and manifests for Red Hat build of OpenTelemetry on OpenShift.

Tested and expected versions of OpenShift and Red Hat build of OpenTelemetry is as follows:
- OpenShift: v4.14.20
- OpenTelemetry Operator: v0.93.0-3

The other versions would be OK as well since this is just a simple example.

## Usage

The container image for our go app is uploaded to the GHCR repo with the [workflow of GitHub Actions](.github/workflows/build-and-push.yml). All we need to do is installing the OpenTelemetry Operator and applying our manifests one by one for an OpenShift cluster.

### Installing OpenTelemetry Operator

[See the docs](https://docs.openshift.com/container-platform/4.14/observability/otel/otel-installing.html) and perform the given steps.

### Applying manifests

Apply the manifests in the [`manifests/`](./manifests/) directory with using `oc` client.

Let's start with create the Deployment for our app and the Route to expose it. 
```
oc apply -f deploy.yaml
oc apply -f expose.yaml 
```
```
$ oc get pod
NAME                                     READY   STATUS    RESTARTS   AGE
otel-sample-deployment-b8696df8d-7xkll   1/1     Running   0          39s
$ oc get route
NAME                HOST/PORT                                           PATH   SERVICES              PORT   TERMINATION   WILDCARD
otel-sample-route   otel-sample-route-otel-sample.apps.test.lab.local          otel-sample-service   8080                 None
$ curl -I otel-sample-route-otel-sample.apps.test.lab.local
HTTP/1.1 200 OK
date: Mon, 06 May 2024 14:34:48 GMT
content-length: 14
content-type: text/plain; charset=utf-8
set-cookie: 27c7a5203dbedf674a50081de44f4d21=f3ceec06cdf162006c6cd294f3279af3; path=/; HttpOnly
```

Next, we add OpenTelemetry Collector as a sidecar container to our pod. Let's apply the other YAML manifests. For more details, please see [this part](https://docs.openshift.com/container-platform/4.14/observability/otel/otel-sending-traces-and-metrics-to-otel-collector.html#sending-traces-and-metrics-to-otel-collector-with-sidecar_otel-sending-traces-and-metrics-to-otel-collector) of OpenShift documentation.

```
oc apply -f otel-rolebinding.yaml
oc apply -f otel-collector.yaml
```
```
$ oc get opentelemetrycollectors.opentelemetry.io otel 
NAME   MODE      VERSION   READY   AGE    IMAGE   MANAGEMENT
otel   sidecar   0.93.0            112s           managed
```

In order to inject the otel collector sidecar container, recreate the pod. Our Deployment will recreate it automatically once the pod is deleted.
```
$ oc get pod
NAME                                     READY   STATUS    RESTARTS   AGE
otel-sample-deployment-b8696df8d-7xkll   1/1     Running   0          8m31s
$ oc delete pod otel-sample-deployment-b8696df8d-7xkll
pod "otel-sample-deployment-b8696df8d-7xkll" deleted
$ oc get pod
NAME                                     READY   STATUS    RESTARTS   AGE
otel-sample-deployment-b8696df8d-gc6hg   2/2     Running   0          37s
```

Now, we can see the trace log is exported on the stdout of otel collector injected as a sidecar container:
```
$ curl -I otel-sample-route-otel-sample.apps.test.lab.local
$ oc logs otel-sample-deployment-b8696df8d-gc6hg otc-container
2024-05-06T14:45:02.667Z        info    TracesExporter  {"kind": "exporter", "data_type": "traces", "name": "debug", "resource spans": 1, "spans": 1}
2024-05-06T14:45:02.667Z        info    ResourceSpans #0
Resource SchemaURL: https://opentelemetry.io/schemas/1.24.0
Resource attributes:
     -> service.name: Str(unknown_service:otel-sample)
     -> telemetry.sdk.language: Str(go)
     -> telemetry.sdk.name: Str(opentelemetry)
     -> telemetry.sdk.version: Str(1.26.0)
ScopeSpans #0
ScopeSpans SchemaURL: 
InstrumentationScope http-server 
Span #0
    Trace ID       : a1964374ea412edf92ee5d4f843071ab
    Parent ID      : 
    ID             : 8fbada7e64abb4bf
    Name           : handleRequest
    Kind           : Internal
    Start time     : 2024-05-06 14:45:01.285150513 +0000 UTC
    End time       : 2024-05-06 14:45:01.385644776 +0000 UTC
    Status code    : Ok
    Status message : 
        {"kind": "exporter", "data_type": "traces", "name": "debug"}
```
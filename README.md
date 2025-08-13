## n4k Kyverno + Reports Server Demo

End-to-end demo for installing Kyverno n4k with the Reports Server, Prometheus/Grafana scraping via ServiceMonitors, and sample policies/load tests.

### Versions used
- Kyverno chart: 3.4.7 (Kyverno v1.14.3-n4k.nirmata.4)
- Reports Server chart: 0.2.3 (app v0.2.2)
- kube-prometheus-stack: latest (via prometheus-community)

### Prerequisites
- kind, kubectl, helm v3
- jq (for API queries), yq (optional)

### Quick start
1) Create KIND cluster
   - kind create cluster --config kind-config.yaml --wait 600s

2) Install kube-prometheus-stack (Prometheus NodePort 30000, Grafana NodePort 30001)
   - See installation.txt step 2 for the exact helm command
   - Get Grafana admin password:
     kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

3) Install Reports Server (must be before Kyverno n4k)
   - helm upgrade --install reports-server rs/reports-server --namespace kyverno --create-namespace --version 0.2.3

4) Install Kyverno n4k
   - helm upgrade --install kyverno nirmata/kyverno --namespace kyverno --create-namespace --version 3.4.7

5) Apply ServiceMonitors so Prometheus scrapes Kyverno and Reports Server
   - kubectl apply -f reports-server-servicemonitor.yaml
   - kubectl apply -f kyverno-servicemonitor.yaml

6) Apply baseline Pod Security policies
   - test -d kyverno-policies || git clone --depth 1 https://github.com/nirmata/kyverno-policies.git
   - kubectl kustomize kyverno-policies/pod-security/baseline | kubectl apply -f -

7) Verify
   - kubectl get polr -A
   - Prometheus UI: http://localhost:30000
   - Grafana UI: http://localhost:30001 (import a Kyverno dashboard if desired)

### Generate activity (optional)
- Apply a violating Pod to produce PolicyReports:
  - kubectl apply -f baseline-violations-pod.yaml
- Create a ClusterPolicy and two Namespaces to produce ClusterPolicyReports:
  - kubectl apply -f cpolr-demo.yaml
- Check:
  - kubectl get cpolr

### Load test (optional)
- Create 100 namespaces and 1 violating Pod each:
  - for i in $(seq 1 100); do kubectl create ns lt-$i; done
  - for i in $(seq 1 100); do kubectl -n lt-$i apply -f baseline-violations-pod.yaml; done
- Etcd sizes:
  - Kubernetes etcd (control plane): see installation.txt steps 3 and 7
  - Reports Server etcd (inside kyverno namespace):

    kubectl -n kyverno exec etcd-0 -c etcd -- etcdctl endpoint status --write-out=table

  - To know the primary etcd/ leader pod :
    kubectl -n kyverno exec etcd-<n> -c etcd -- etcdctl endpoint status --write-out=table | cat
    where n can be 0,1,2

 - To know the etcd size for all the endpoints:
 for i in 0 1 2; do kubectl -n kyverno exec etcd-$i -c etcd -- etcdctl endpoint status --write-out=json; done | jq -s 'map(.[0]) as $s | {perMember: ($s | map({endpoint: .Endpoint, bytes: .Status.dbSize})), logicalBytes: ($s | map(.Status.dbSize) | max), replicatedBytes: ($s | map(.Status.dbSize) | add), logicalMB: (($s | map(.Status.dbSize) | max)/1048576), replicatedMB: (($s | map(.Status.dbSize) | add)/1048576)}' | cat

 

### Monitoring
- Kyverno: import the bundled Grafana dashboard JSON (`kyverno-dashboard.json`) via Grafana → Dashboards → Import.
- etcd (Kubernetes control plane): use the etcdctl endpoint status commands in installation.txt (steps 3 and 7).
- Reports-Server etcd (Prometheus queries you can paste):
  - Quota per member (GiB):
    - etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"} / 1024^3
  - DB size per member (MiB):
    - etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"} / 1024 / 1024
  - Percent used per member:
    - 100 * (etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"} / on(pod) etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"})
  - Percent remaining per member:
    - 100 - (100 * (etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"} / on(pod) etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"}))
  - GiB remaining per member:
    - (etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"} - etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"}) / 1024^3
  - Cluster logical usage % (one copy):
    - 100 * max(etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"}) / max(etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"})
  - Cluster replicated usage % (3 copies):
    - 100 * sum(etcd_mvcc_db_total_size_in_bytes{namespace="kyverno",job="etcd"}) / sum(etcd_server_quota_backend_bytes{namespace="kyverno",job="etcd"})

### Repo contents
- kind-config.yaml: KIND 3-node cluster config
- installation.txt: complete step-by-step install with pinned versions
- reports-server-servicemonitor.yaml: scrapes reports-server metrics
- kyverno-servicemonitor.yaml: scrapes Kyverno controllers metrics
- baseline-violations-pod.yaml: sample Pod that violates baseline policies
- cpolr-demo.yaml: ClusterPolicy + compliant/non-compliant Namespaces

### References
- Kyverno monitoring: https://release-1-14-0.kyverno.io/docs/monitoring/
- Baseline policies: https://github.com/nirmata/kyverno-policies/tree/main/pod-security/baseline


<p align="center">
  <a href="https://devcloudlab.com"><strong>DevCloudLab</strong></a>
</p>

<h1 align="center">DevOps Projects using Kubernetes: course code and handouts</h1>

<p align="center">
  The companion repository for the Udemy course <strong>DevOps projects using Kubernetes: a hands-on guide</strong>.<br>
  Every file a lecture uses, and one written handout per lecture, with every command copyable.
</p>

---

## Layout

| Path | Lecture | What it holds |
|---|---|---|
| `s01/eks/cluster.yaml` | Kubernetes on AWS using EKS | The eksctl `ClusterConfig`: EKS 1.36, AL2023 managed nodes, access entries (`authenticationMode: API`) |
| `s01/kubeadm/kubernetes-ami/` | kubeadm (1): a golden AMI with Packer | `node.pkr.hcl` and the node provisioning script: containerd 2.3, kubelet/kubeadm/kubectl 1.36.4 |
| `s01/kubeadm/terraform/` | kubeadm (2): Terraform infrastructure | VPC, subnets, security groups, the API load balancer, launch templates, and IAM for the AWS cloud controller. `.terraform.lock.hcl` is committed |
| `s01/kubeadm/cluster/` | kubeadm (3): init, CNI and the AWS cloud controller | `init.yaml` and `join.yaml` (kubeadm `v1beta4`, `cloud-provider: external`) |
| `handouts/s01/` | every Section 1 lecture | The written study companion for each lecture |
| `s02/kustomize/` | App provisioning using Kustomize | A base and three overlays (`dev`, `qa`, `prod`) |
| `s02/helm/hello-chart/` | Helm: writing a chart | The chart written in the lecture |
| `s02/blue-green/blue-green/` | Blue/Green deployments using Helm | A chart that runs blue and green side by side and switches traffic with one value |
| `s02/operators/kubebuilder/` | Operator tooling in 2026 | The `NginxSite` API type, its controller and a sample, as written in the lecture (kubebuilder 4.16) |
| `s02/operators/mysql/` | Provisioning MySQL with an operator | Percona Operator for MySQL: values for S3 backups, a backup and a restore |
| `s02/operators/kro/` | Build your own operator | The kro `ResourceGraphDefinition` and an instance of it (kro 0.9.4) |
| `weatherapp/` | Section 3 (the Weather App) | The three services (Go, Node.js, Python), `compose.yaml` and the Helm chart, version 2.1.0 |
| `handouts/s02/`, `handouts/s03/`, `handouts/s04/` | every updated lecture in Sections 2 to 4 | The written study companion for each lecture |

The kOps lecture needs no files: every command is in its handout, `handouts/s01/s01-l03.md`.

## Versions

Everything is pinned and was tested end to end on AWS (us-east-1) in September 2026: Kubernetes 1.36.4, kOps 1.36.2,
eksctl 0.230.0, Packer 1.16.1, Terraform 1.16.4 with the AWS provider 6.x, Cilium 1.20.2, the AWS cloud controller 1.36.1
and Helm 4.3.0. Each handout lists the exact install commands.

## Cost

These lectures create real AWS resources: EC2 instances, load balancers, a NAT gateway and an EKS control plane. Every
handout ends with a **Cleaning up** section. Run it when you finish a lecture, so nothing keeps billing.

## Questions

Ask in the course's Q&A on Udemy.

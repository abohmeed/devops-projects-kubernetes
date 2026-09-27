# nginx-operator (kubebuilder) — S02-L06

This folder does not ship the whole generated project. It ships the three files the lecture
edits; everything else comes from the scaffold commands below.

## Toolchain (Linux x86_64)

```bash
curl -LO https://go.dev/dl/go1.26.8.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.26.8.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc && source ~/.bashrc
curl -L -o kubebuilder https://github.com/kubernetes-sigs/kubebuilder/releases/download/v4.16.0/kubebuilder_linux_amd64
chmod +x kubebuilder && sudo mv kubebuilder /usr/local/bin/
sudo apt-get install -y make
go version            # go version go1.26.8 linux/amd64
kubebuilder version   # KubeBuilder: v4.16.0
```

## Scaffold

```bash
mkdir nginx-operator && cd nginx-operator
kubebuilder init --domain devopsprojects.io --repo example.com/nginx-operator
kubebuilder create api --group web --version v1 --kind NginxSite --resource --controller
```

## The three edited files

| File | Edit |
|---|---|
| `api/v1/nginxsite_types.go` | in `NginxSiteSpec`, the example field `Foo *string` is replaced by `Message string` |
| `internal/controller/nginxsite_controller.go` | `Reconcile` gets the object, returns `client.IgnoreNotFound(err)`, and logs `reconciling` with the message |
| `config/samples/web_v1_nginxsite.yaml` | `spec.message` (the lecture applies "Hello from version 1", then "Hello from version 2") |

Copy them over the scaffold, then:

```bash
make manifests
make install
make run                                           # second terminal
kubectl apply -f config/samples/web_v1_nginxsite.yaml
kubectl get nginxsite
kubectl delete -f config/samples/web_v1_nginxsite.yaml
make uninstall                                      # after Ctrl+C in the make run terminal
```

The Go module and build caches this needs come to about 2.2 GB (690 MB of modules and 1.5 GB of
build cache, measured 2026-09-27). `go clean -modcache -cache` reclaims them.

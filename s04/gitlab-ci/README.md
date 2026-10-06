# Section 4: a GitLab CI/CD pipeline for the WeatherApp

These files go with the Section 4 lectures. The pipeline builds the three WeatherApp images, pushes them
to Docker Hub, deploys them to a `staging` namespace on every merge to `main`, and deploys a version tag
to `production` when you press the button. It stores **no AWS keys and no kubeconfig** in GitLab.

| File | Used in | What it is |
|---|---|---|
| `rbac.yaml` | CI access to any Kubernetes cluster; EKS access for CI | Namespaces `staging`, `production`, `cicd`; the `gitlab-ci` ServiceAccount; a RoleBinding to the built-in `edit` role in each target namespace |
| `trust-policy.json` | EKS access for CI; Preparing the pipeline | Who may assume the deploy role: only GitLab ID tokens for your project, on protected branches and tags |
| `deployer-policy.json` | EKS access for CI | The deploy role's only AWS permission: `eks:DescribeCluster` on our cluster |
| `.gitlab-ci.yml` | stages 1 to 3 | The finished pipeline. `snapshots/` holds the file as it stands at the end of each lecture |

**Never delete your GitLab project once its pipeline has run.** GitLab burns a deleted project's path for CI: a new project at the same path has its jobs refused (`id_token_burned_project_path`). To start over, reset the branch and tags instead.

Replace every `<...>` with your own value. `${ACCOUNT_ID}`, `${GITLAB_PROJECT_PATH}` and `${GITLAB_PROJECT_ID}`
in the JSON files are filled in by `envsubst` from the variables you export; the files themselves never hold them.
The Region is `us-east-1` and the cluster is `basic-cluster`, as in Section 1.

## Before you start: the cluster

Section 3 deleted the cluster. Bring it back with the same two files:

```bash
cd ~/devops-projects/s01-l04
export AWS_PROFILE=<your-profile>
eksctl create cluster -f cluster.yaml
eksctl create addon -f addons.yaml
```

Keep it for the whole section. If you pause for more than a day, delete it
(`eksctl delete cluster -f cluster.yaml --wait`) and run these commands again when you come back, then
re-apply `rbac.yaml` and re-create the access entry below. The IAM role and OIDC provider survive a cluster delete.

## CI access to any Kubernetes cluster (ServiceAccount token)

```bash
mkdir -p ~/devops-projects/s04 && cd ~/devops-projects/s04
kubectl apply -f rbac.yaml
TOKEN=$(kubectl create token gitlab-ci --namespace cicd --duration 720h)
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > ca.crt
kubectl config set-cluster basic-cluster --server="$SERVER" --certificate-authority=ca.crt --embed-certs --kubeconfig=gitlab-ci.kubeconfig
kubectl config set-credentials gitlab-ci --token="$TOKEN" --kubeconfig=gitlab-ci.kubeconfig
kubectl config set-context gitlab-ci --cluster=basic-cluster --user=gitlab-ci --namespace=staging --kubeconfig=gitlab-ci.kubeconfig
kubectl config use-context gitlab-ci --kubeconfig=gitlab-ci.kubeconfig
kubectl auth whoami --kubeconfig=gitlab-ci.kubeconfig
kubectl get pods --kubeconfig=gitlab-ci.kubeconfig
kubectl get pods --namespace kube-system --kubeconfig=gitlab-ci.kubeconfig    # Forbidden, as intended
```

On a cluster that is not EKS (kops, kubeadm), this kubeconfig is how the pipeline gets in: add it in GitLab as a
**File** variable named `KUBECONFIG`, protected, and drop the `aws eks update-kubeconfig` line from the deploy template.
The token asks for 30 days. EKS caps it at 24 hours (and prints a warning); kOps and kubeadm clusters grant the full 30 days. Create a new one before it runs out. To revoke it at once, delete the ServiceAccount.
Never commit the kubeconfig, and never print it: it contains the token. If GitLab's runners cannot reach your API
server (a private cluster), use the GitLab agent for Kubernetes instead.

On EKS we do not need the token, so delete the local copy: `rm gitlab-ci.kubeconfig ca.crt`.

## EKS access for CI (GitLab OIDC role + access entry)

```bash
cd ~/devops-projects/s04
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export GITLAB_PROJECT_PATH=<your-group>/weatherapp   # the course uses devops-projects-kubernetes/weatherapp
aws iam create-open-id-connect-provider --url https://gitlab.com --client-id-list https://gitlab.com
aws iam create-role --role-name gitlab-weatherapp-deployer \
  --assume-role-policy-document "$(envsubst < trust-policy.json)" --query Role.RoleName --output text
aws iam put-role-policy --role-name gitlab-weatherapp-deployer --policy-name eks-describe-cluster \
  --policy-document "$(envsubst < deployer-policy.json)"
aws eks create-access-entry --cluster-name basic-cluster \
  --principal-arn "arn:aws:iam::${ACCOUNT_ID}:role/gitlab-weatherapp-deployer" \
  --username 'gitlab-ci:{{SessionName}}' --kubernetes-groups cicd \
  --query 'accessEntry.[username,kubernetesGroups]'
kubectl apply -f rbac.yaml     # after adding the Group "cicd" subject to both RoleBindings
kubectl auth can-i create deployments --namespace production --as gitlab-ci:test --as-group cicd   # yes
kubectl auth can-i list pods --namespace kube-system --as gitlab-ci:test --as-group cicd           # no
```

Use the trust policy **without** the `project_id` line at this point: the project does not exist yet.
`envsubst` comes with the `gettext-base` package on Ubuntu.

## Preparing the pipeline: pin the trust to your project

Your project's ID is on its overview page (the three-dot menu, **Copy project ID**).

```bash
export GITLAB_PROJECT_ID=<your-project-id>
aws iam update-assume-role-policy --role-name gitlab-weatherapp-deployer \
  --policy-document "$(envsubst < trust-policy.json)"
```

A project path can in principle be reused by someone else after a project is deleted; the numeric ID cannot,
which is why AWS and GitLab both recommend adding it.

## CI/CD variables (Settings > CI/CD > Variables)

| Key | Value | Protect | Visibility |
|---|---|---|---|
| `DOCKERHUB_USER` | your Docker Hub username | no | Visible |
| `DOCKERHUB_TOKEN` | a Docker Hub personal access token, Read & Write | yes | Masked and hidden |
| `AWS_ROLE_ARN` | `arn:aws:iam::<ACCOUNT_ID>:role/gitlab-weatherapp-deployer` | yes | Masked |
| `JWT_SECRET` | output of `openssl rand -hex 32` | yes | Masked and hidden |
| `DB_ROOT_PASSWORD` | output of `openssl rand -hex 16` | yes | Masked and hidden |
| `DB_PASSWORD` | output of `openssl rand -hex 16` | yes | Masked and hidden |
| `WEATHER_CONTACT` | your email address or a link to your project (MET Norway asks every app for one; not a secret) | yes | Visible |

Keep `JWT_SECRET`, `DB_ROOT_PASSWORD` and `DB_PASSWORD` for the life of the deployment: MySQL reads its passwords
only the first time it starts, so changing them later locks the app out of its own database.
Also protect your tags: **Settings > Repository > Protected tags**, tag `*`, allowed to create: Maintainers.
Without that, a version tag's pipeline gets none of the protected variables and AWS refuses its token.

## Clean up (end of the section)

```bash
helm uninstall weatherapp-ui weatherapp-weather weatherapp-auth --namespace production
helm uninstall weatherapp-ui weatherapp-weather weatherapp-auth --namespace staging
kubectl delete pvc data-weatherapp-auth-mysql-0 --namespace production
kubectl delete pvc data-weatherapp-auth-mysql-0 --namespace staging
aws iam delete-role-policy --role-name gitlab-weatherapp-deployer --policy-name eks-describe-cluster
aws iam delete-role --role-name gitlab-weatherapp-deployer
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/gitlab.com"
cd ~/devops-projects/s01-l04 && eksctl delete cluster -f cluster.yaml --wait
```

Also revoke the Docker Hub token you gave GitLab once you no longer need the pipeline.

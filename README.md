The helm charts are built with circleci and pushed into a public cyberdojo helm repository hosted in GCP. 

https://app.circleci.com/pipelines/github/cyber-dojo/helm-charts?branch=master

To configure the repository on your machine:

```
helm repo add <repo name> https://storage.googleapis.com/cyber-dojo-helm-repo/
helm repo update
[helm v3] helm search repo <repo name>
[helm v2] helm search <repo name>
```
The charts can be then installed from above repo.

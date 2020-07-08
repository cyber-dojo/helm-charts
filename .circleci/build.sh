#!/bin/bash
function sanity_check() {

  if [ -z "${GCS_SECRET_ACCESS_KEY}" ]; then
    echo "GCS_SECRET_ACCESS_KEY found empty. Exiting ..."
    exit 1
  fi

  if [ -z "${CYBERDOJO_HELM_REPO_NAME}" ]; then
    echo "REPO_NAME found empty. Exiting ..."
    exit 1
  fi

  if [ -z "${CYBERDOJO_HELM_REPO_BUCKET_NAME}" ]; then
    echo "REPO_BUCKET_NAME found empty. Exiting ..."
    exit 1
  fi
}

echo "performing sanity checks ..."
sanity_check

echo ${GCS_SECRET_ACCESS_KEY} | base64 -d > gcloud-service-key.json
gcloud auth activate-service-account --key-file gcloud-service-key.json

helm init --client-only

export CYBERDOJO_HELM_REPO_URL="gs://$CYBERDOJO_HELM_REPO_BUCKET_NAME"
export CYBEROJO_HELM_REPO_PUBLIC_URL="https://storage.googleapis.com/$CYBERDOJO_HELM_REPO_BUCKET_NAME/"

helm repo add $CYBERDOJO_HELM_REPO_NAME $CYBEROJO_HELM_REPO_PUBLIC_URL
echo "creating .charts directory ..."
mkdir -p .charts

echo "linting ..."
for d in */ ; do
    if [ "$d" != "docs/" ]; then
      echo "linting package $d"
      helm lint $d
      if [ $? -gt 0 ]; then
        echo "Package $d has errors ... Terminating!"
        exit 9
      fi
    fi
done

echo "building ..."
for d in */ ; do
    if [ "$d" != "docs/" ]; then
      echo "building package $d"
      if [ -e $d/requirements.yaml ]; then
        cd $d;
        helm dependency update;
        cd ..
      fi
      helm package $d -d .charts
      if [ $? -gt 0 ]; then
        echo "Package $d has errors ... Terminating!"
        exit 9
      fi
    fi
done

# pulling existing helm repo index.yaml to be merged with the new charts info.
# Without this, old chart versions can become undiscoverable in the repo.
gsutil cp $CYBERDOJO_GCS_HELM_REPO_URL/index.yaml oldIndex.yaml
# echo "non existing index copied"
echo "generating index.yaml ..."
helm repo index .charts --url $CYBEROJO_HELM_REPO_PUBLIC_URL --merge oldIndex.yaml

echo "pushing charts to $CYBERDOJO_HELM_REPO_NAME repo ..."

# pushing charts to cloud storage
gsutil cp -r .charts/*  $CYBERDOJO_HELM_REPO_URL/
if [ $? -gt 0 ]; then
    echo "Failed to push charts to storage ... Terminating!"
    exit 9
fi

echo "updaing repo ..."
helm repo update
echo "listing charts in $CYBERDOJO_HELM_REPO_NAME repo ..."
helm search $CYBERDOJO_HELM_REPO_NAME

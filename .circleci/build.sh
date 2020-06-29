#!/bin/bash
# To be changed with GCS access keys, region, repo name and url. Creating repo and SA in GCS is a prerequisite
# cli commands to be used is GCS
function sanity_check() {
  if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
    echo "AWS_ACCESS_KEY_ID found empty. Exiting ..."
    exit 1
  fi

  if [ -z "${AWS_DEFAULT_REGION}" ]; then
    echo "AWS_DEFAULT_REGION found empty. Exiting ..."
    exit 1
  fi

  if [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
    echo "AWS_SECRET_ACCESS_KEY found empty. Exiting ..."
    exit 1
  fi

  if [ -z "${PRAQMA_HELM_REPO_NAME}" ]; then
    echo "REPO_NAME found empty. Exiting ..."
    exit 1
  fi

  if [ -z "${PRAQMA_S3_HELM_REPO_BUCKET_NAME}" ]; then
    echo "REPO_URL found empty. Exiting ..."
    exit 1
  fi
}

echo "performing sanity checks ..."
sanity_check

echo "initializing helm ..."
helm init --client-only

echo "creating repo URLs ..."
export PRAQMA_S3_HELM_REPO_URL="https://$PRAQMA_S3_HELM_REPO_BUCKET_NAME.s3.amazonaws.com/"

echo "adding helm repo ..."
helm repo add $PRAQMA_HELM_REPO_NAME $PRAQMA_S3_HELM_REPO_URL

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
aws s3 cp s3://$PRAQMA_S3_HELM_REPO_BUCKET_NAME/index.yaml oldIndex.yaml

echo "generating index.yaml ..."
helm repo index .charts --url $PRAQMA_S3_HELM_REPO_URL --merge oldIndex.yaml

echo "pushing charts to $PRAQMA_HELM_REPO_NAME repo ..."

# pushing charts to s3
aws s3 cp .charts s3://$PRAQMA_S3_HELM_REPO_BUCKET_NAME/ --recursive
if [ $? -gt 0 ]; then
    echo "Failed to push charts to S3 ... Terminating!"
    exit 9
fi

# Deprecated since it uses helm s3 plugin and that pushes charts with private permissions.
# Does not fit for public repos.
#
# for filename in .charts/*; do
#   helm s3 push --force $filename $PRAQMA_HELM_REPO_NAME
#   if [ $? -gt 0 ]; then
#     echo "Package $d has errors when pushing ... Terminating!"
#     exit 9
#   fi
# done

echo "updaing repo ..."
helm repo update

echo "listing charts in $PRAQMA_HELM_REPO_NAME repo ..."
helm search $PRAQMA_HELM_REPO_NAME

#! /bin/bash
set -e

function bucket_name() {
  local project=$1
  echo "${project}-terraform-state"
}

function delete_project_and_bucket() {

  local project=$1
  local gcpproject=$2

  bucket_name="$(bucket_name "${project}")"

  gsutil rm -r gs://"${bucket_name}"
  gcloud projects delete "${gcpproject}" --quiet

}

##
## Script
##

project=""
gcpproject=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    ;;
  --project)
    project="$2"
    shift
    ;;
  --gcpproject)
    gcpproject="$2"
    shift
    ;;
  *)
    usage "Unknown option '$1'"
    ;;
  esac
  shift
done

if [ "${project}" == "" ]; then
  usage "Project name must be provided"
fi

if [ "${gcpproject}" == "" ]; then
  usage "GCP project name must be provided"
fi

delete_project_and_bucket "${project}" "${gcpproject}"

#! /bin/bash
set -e

function bucket_name() {
  local gcpproject=$1
  echo "${gcpproject}-terraform-state"
}

function delete_project_and_bucket() {

  local gcpproject=$1

  bucket_name="$(bucket_name "${gcpproject}")"

  gsutil rm -r gs://"${bucket_name}"
  gcloud projects delete "${gcpproject}" --quiet

}

##
## Script
##

gcpproject=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
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

if [ "${gcpproject}" == "" ]; then
  usage "GCP project name must be provided"
fi

delete_project_and_bucket "${gcpproject}"

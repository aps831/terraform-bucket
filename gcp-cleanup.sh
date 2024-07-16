#! /bin/bash
set -e

function bucket_name_tf_state() {
  local gcpproject=$1
  echo "${gcpproject}-terraform-state"
}

function bucket_name_logging() {
  local gcpproject=$1
  echo "${gcpproject}-logging"
}

function delete_project_and_buckets() {

  local gcpproject=$1

  bucket_name_tf_state="$(bucket_name_tf_state "${gcpproject}")"
  bucket_name_logging="$(bucket_name_logging "${gcpproject}")"

  gsutil rm -r gs://"${bucket_name_tf_state}"
  gsutil rm -r gs://"${bucket_name_logging}"
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

delete_project_and_buckets "${gcpproject}"

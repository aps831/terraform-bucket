#! /bin/bash
set -e

trap 'catch $?' EXIT

function catch() {
  if [ "$1" != "0" ]; then
    echo "An error occurred"
    exit 1
  fi
}

function usage() {
  if [[ $* != "" ]]; then
    echo "Error: $*"
  fi

  cat <<EOF
Usage: $PROGNAME [OPTION ...]
Delete AWS terraform state and logging bucket

Options:
--help          display this usage message and exit
--account       AWS account number
--project       Project name
--profile       AWS profile
--region        AWS region
EOF
  exit 0
}

function bucket_name_state() {
  local account=$1
  local project=$2
  echo "${account}-${project}-terraform-state"
}

function bucket_name_logging() {
  local account=$1
  local project=$2
  echo "${account}-${project}-terraform-logging"
}

function dynamo_db_state() {
  local project=$1
  echo "${project}-terraform-state-locks"
}

function delete_buckets() {
  local account=$1
  local project=$2
  local region=$3

  bucket_name_logging="$(bucket_name_logging "${account}" "${project}")"
  bucket_name_state="$(bucket_name_state "${account}" "${project}")"
  dynamo_db_state="$(dynamo_db_state "${project}")"

  # S3 Bucket State
  versions_state="$(aws s3api list-object-versions --bucket "${bucket_name_state}" --output=json --query='{Objects: Versions[].{Key: Key, VersionId: VersionId}}')"
  aws s3api delete-objects --bucket "${bucket_name_state}" --delete "${versions_state}" > /dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "${bucket_name_state}"

  # S3 Bucket Logging
  versions_logging="$(aws s3api list-object-versions --bucket "${bucket_name_logging}" --output=json --query='{Objects: Versions[].{Key: Key, VersionId: VersionId}}')"
  aws s3api delete-objects --bucket "${bucket_name_logging}" --delete "${versions_logging}" > /dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "${bucket_name_logging}"

  # DyanamoDB State Lock
  aws dynamodb delete-table --table-name "${dynamo_db_state}"

}

##
## Script
##

account=""
project=""
profile=""
region=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    ;;
  --account)
    account="$2"
    shift
    ;;
  --project)
    project="$2"
    shift
    ;;
  --profile)
    profile="$2"
    shift
    ;;
  --region)
    region="$2"
    shift
    ;;
  *)
    usage "Unknown option '$1'"
    ;;
  esac
  shift
done

if [ "${account}" == "" ]; then
  usage "Account number must be provided"
fi

if [ "${project}" == "" ]; then
  usage "Project name must be provided"
fi

if [ "${profile}" == "" ]; then
  usage "Profile name must be provided"
fi

if [ "${region}" == "" ]; then
  usage "Region must be provided"
fi

export AWS_PAGER=""
export AWS_PROFILE="${profile}"

delete_buckets "${account}" "${project}" "${region}"

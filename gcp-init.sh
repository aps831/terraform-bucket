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
Create GCP project and terraform state bucket

Options:
--help          display this usage message and exit
--account       GCP account email
--gcpproject    GCP project name
EOF
  exit 0
}

function life_cycle_policy() {
  filename=$(mktemp)
  cat <<EOF >"$filename"
{
  "lifecycle": {
    "rule": [
      {
        "action": { "type": "Delete" },
        "condition": {
          "numNewerVersions": 2,
          "isLive": false
        }
      }
    ]
  }
}
EOF
  echo "${filename}"
}

function bucket_name_tf_state() {
  local gcpproject=$1
  echo "${gcpproject}-terraform-state"
}

function bucket_name_logging() {
  local gcpproject=$1
  echo "${gcpproject}-logging"
}

function create_project_and_bucket() {

  local account=$1
  local gcpproject=$2

  bucket_name_tf_state="$(bucket_name_tf_state "${gcpproject}")"
  bucket_name_logging="$(bucket_name_logging "${gcpproject}")"

  # Project
  gcloud projects create "${gcpproject}" --enable-cloud-apis

  # Billing
  billing_account="$(gcloud beta billing accounts list | awk 'NR==2 { printf $1 }')"
  gcloud beta billing projects link "${gcpproject}" --billing-account "${billing_account}"

  # Enable API's
  gcloud services enable iam.googleapis.com --project "${gcpproject}"
  gcloud services enable billingbudgets.googleapis.com --project "${gcpproject}"
  gcloud services enable cloudbilling.googleapis.com --project "${gcpproject}"
  gcloud services enable cloudresourcemanager.googleapis.com --project "${gcpproject}"

  # Add Terraform write role
  permissions="serviceusage.services.use"
  permissions="${permissions},resourcemanager.projects.get"
  permissions="${permissions},storage.objects.create"
  permissions="${permissions},storage.objects.delete"
  permissions="${permissions},storage.objects.get"
  permissions="${permissions},storage.objects.getIamPolicy"
  permissions="${permissions},storage.objects.list"
  gcloud iam roles create "terraform.write" --title "Terraform Write" --project "${gcpproject}" --permissions "${permissions}" --stage="GA"
  gcloud projects add-iam-policy-binding "${gcpproject}" --member="user:${account}" --role=projects/"${gcpproject}"/roles/terraform.write

  # Bucket
  gcloud storage buckets create gs://"${bucket_name_tf_state}" --project "${gcpproject}"
  gcloud storage buckets create gs://"${bucket_name_logging}" --project "${gcpproject}"

  # Uniform bucket access
  gcloud storage buckets update gs://"${bucket_name_tf_state}" --uniform-bucket-level-access
  gcloud storage buckets update gs://"${bucket_name_logging}" --uniform-bucket-level-access

  # Prevent public access
  gcloud storage buckets update gs://"${bucket_name_tf_state}" --public-access-prevention
  gcloud storage buckets update gs://"${bucket_name_logging}" --public-access-prevention

  # Versioning
  gcloud storage buckets update gs://"${bucket_name_tf_state}" --versioning
  gcloud storage buckets update gs://"${bucket_name_logging}" --versioning

  gcloud storage buckets update gs://"${bucket_name_tf_state}" --lifecycle-file "$(life_cycle_policy)"
  gcloud storage buckets update gs://"${bucket_name_logging}" --lifecycle-file "$(life_cycle_policy)"

  gcloud storage buckets update gs://"${bucket_name_logging}" --log-bucket gs://"${bucket_name_tf_state}"

}

##
## Script
##

account=""
gcpproject=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    usage
    ;;
  --account)
    account="$2"
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

if [ "${account}" == "" ]; then
  usage "Account email must be provided"
fi

if [ "${gcpproject}" == "" ]; then
  usage "GCP project name must be provided"
fi

create_project_and_bucket "${account}" "${gcpproject}"

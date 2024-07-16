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
--region        GCP region
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
  local region=$3

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
  gsutil mb -p "${gcpproject}" -l "${region}" gs://"${bucket_name_tf_state}"
  gsutil mb -p "${gcpproject}" -l "${region}" gs://"${bucket_name_logging}"

  # Uniform bucket access
  gsutil ubla set on gs://"${bucket_name_tf_state}"
  gsutil ubla set on gs://"${bucket_name_logging}"

  # Prevent public access
  gsutil pap set enforced gs://"${bucket_name_tf_state}"
  gsutil pap set enforced gs://"${bucket_name_logging}"

  # Versioning
  gsutil versioning set on gs://"${bucket_name_tf_state}"
  gsutil versioning set on gs://"${bucket_name_logging}"

  gsutil lifecycle set "$(life_cycle_policy)" gs://"${bucket_name_tf_state}"
  gsutil lifecycle set "$(life_cycle_policy)" gs://"${bucket_name_logging}"

  gsutil logging set on -b gs://"${bucket_name_logging}" -o tfStateLog gs://"${bucket_name_tf_state}"

}

##
## Script
##

account=""
gcpproject=""
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
  --gcpproject)
    gcpproject="$2"
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
  usage "Account email must be provided"
fi

if [ "${gcpproject}" == "" ]; then
  usage "GCP project name must be provided"
fi

if [ "${region}" == "" ]; then
  usage "Region must be provided"
fi

create_project_and_bucket "${account}" "${gcpproject}" "${region}"

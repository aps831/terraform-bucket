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
--project       Project name
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

function bucket_name() {
  local project=$1
  echo "${project}-terraform-state"
}

function create_project_and_bucket() {

  local account=$1
  local project=$2
  local gcpproject=$3
  local region=$4

  bucket_name="$(bucket_name "${project}")"

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

  # Add Terraform admin role
  permissions="serviceusage.services.use"
  permissions="${permissions},resourcemanager.projects.get"
  permissions="${permissions},storage.objects.create"
  permissions="${permissions},storage.objects.delete"
  permissions="${permissions},storage.objects.get"
  permissions="${permissions},storage.objects.getIamPolicy"
  permissions="${permissions},storage.objects.list"
  gcloud iam roles create "terraform.admin" --title "Terraform Admin" --project "${gcpproject}" --permissions "${permissions}" --stage="GA"
  gcloud projects add-iam-policy-binding "${gcpproject}" --member="user:${account}" --role=projects/"${gcpproject}"/roles/terraform.admin

  # Bucket
  gsutil mb -p "${gcpproject}" -l "${region}" gs://"${bucket_name}"

  # Uniform bucket access
  gsutil ubla set on gs://"${bucket_name}"

  # Prevent public access
  gsutil pap set enforced gs://"${bucket_name}"

  # Versioning
  gsutil versioning set on gs://"${bucket_name}"

  gsutil lifecycle set "$(life_cycle_policy)" gs://"${bucket_name}"

}

##
## Script
##

account=""
project=""
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
  --project)
    project="$2"
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

if [ "${project}" == "" ]; then
  usage "Project name must be provided"
fi

if [ "${gcpproject}" == "" ]; then
  usage "GCP project name must be provided"
fi

if [ "${region}" == "" ]; then
  usage "Region must be provided"
fi

create_project_and_bucket "${account}" "${project}" "${gcpproject}" "${region}"

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
Create AWS terraform state and logging bucket

Options:
--help          display this usage message and exit
--account       AWS account number
--project       Project name
--profile       AWS profile
--region        AWS region
--tag           Resource tag
EOF
  exit 0
}

function wait_for_dynamobd_table_to_be_created() {
  local table=$1
  aws dynamodb wait table-exists --table-name "${table}"
}

function lifecycle_rule_state() {
  filename=$(mktemp)
  cat << EOF > "$filename"
{
    "Rules": [
        {
            "Status": "Enabled",
            "Prefix": "",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 365
            },
            "ID": "Delete old versions"
        }
    ]
}
EOF
  echo "$filename"
}

function lifecycle_rule_logging() {
  filename=$(mktemp)
  cat << EOF > "$filename"
{
    "Rules": [
        {
            "Status": "Enabled",
            "Prefix": "",
            "Expiration": {
                "Days": 365
            },
            "ID": "Delete old files"
        }
    ]
}
EOF
  echo "$filename"
}

function bucket_logging() {
  local account=$1
  local project=$2

  bucket_name_logging=$(bucket_name_logging "${account}" "${project}")
  bucket_name_state=$(bucket_name_state "${account}" "${project}")

  filename=$(mktemp)
  cat << EOF > "$filename"
{
  "LoggingEnabled": {
    "TargetBucket": "${bucket_name_logging}",
    "TargetPrefix": "${project}/s3/${bucket_name_state}/"
  }
}
EOF
  echo "$filename"
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

function create_buckets() {
  local account=$1
  local project=$2
  local region=$3
  local tag=$4

  bucket_name_logging="$(bucket_name_logging "${account}" "${project}")"
  bucket_name_state="$(bucket_name_state "${account}" "${project}")"
  dynamo_db_state="$(dynamo_db_state "${project}")"

  # S3 Bucket Logging
  aws s3api create-bucket --bucket "${bucket_name_logging}" --create-bucket-configuration LocationConstraint="${region}"
  aws s3api put-public-access-block --bucket "${bucket_name_logging}" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  aws s3api put-bucket-versioning --bucket "${bucket_name_logging}" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "${bucket_name_logging}" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
  aws s3api put-bucket-tagging --bucket "${bucket_name_logging}" --tagging "TagSet=[{Key=service,Value=$tag}]"
  aws s3api put-bucket-lifecycle-configuration --bucket "${bucket_name_logging}" --lifecycle-configuration file://"$(lifecycle_rule_logging)"
  aws s3api put-bucket-acl --bucket "${bucket_name_logging}" --grant-write URI=http://acs.amazonaws.com/groups/s3/LogDelivery --grant-read-acp URI=http://acs.amazonaws.com/groups/s3/LogDelivery

  # S3 Bucket State
  aws s3api create-bucket --bucket "${bucket_name_state}" --create-bucket-configuration LocationConstraint="${region}"
  aws s3api put-public-access-block --bucket "${bucket_name_state}" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  aws s3api put-bucket-versioning --bucket "${bucket_name_state}" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "${bucket_name_state}" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
  aws s3api put-bucket-tagging --bucket "${bucket_name_state}" --tagging "TagSet=[{Key=service,Value=$tag}]"
  aws s3api put-bucket-lifecycle-configuration --bucket "${bucket_name_state}" --lifecycle-configuration file://"$(lifecycle_rule_state)"
  aws s3api put-bucket-logging --bucket "${bucket_name_state}" --bucket-logging-status file://"$(bucket_logging "${account}" "${project}")"

  # DyanamoDB State Lock
  dynamodb0=$(aws dynamodb create-table --table-name "${dynamo_db_state}" --attribute-definitions AttributeName=LockID,AttributeType=S --billing-mode "PAY_PER_REQUEST" --key-schema AttributeName=LockID,KeyType=HASH)
  wait_for_dynamobd_table_to_be_created "${dynamo_db_state}"
  aws dynamodb tag-resource --resource-arn "$(echo "${dynamodb0}" | jq --raw-output '.TableDescription.TableArn')" --tags Key=service,Value="${tag}"

}

##
## Script
##

account=""
project=""
profile=""
region=""
tag=""
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
  --tag)
    tag="$2"
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

if [ "${tag}" == "" ]; then
  usage "Tag must be provided"
fi

export AWS_PAGER=""
export AWS_PROFILE="${profile}"

create_buckets "${account}" "${project}" "${region}" "${tag}"

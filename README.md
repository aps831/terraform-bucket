# Terraform Bucket

This repository provides scripts for bootstrapping buckets (and in the case of GCP, a project) to store Terraform state.

To initialise an AWS bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/2.0.0/aws-init.sh | bash -s -- --account ${account} --project ${project} --profile ${profile} --region ${region} --tag ${tag}
```

where

```text
account = AWS account number
project = project name (eg git repo)
profile = AWS profile
region  = AWS region (eg eu-west-2)
tag     = tag to add to AWS resources
```

Note that the S3 bucket with name `${account}-${project}-terraform-state` must be globally unique.

To cleanup an AWS bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/2.0.0/aws-cleanup.sh | bash -s -- --account ${account} --project ${project} --profile ${profile} --region ${region}
```

where

```text
account = AWS account number
project = project name (eg git repo)
profile = AWS profile
region  = AWS region (eg eu-west-2)
```

To initialise a GCP project and bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/2.0.0/gcp-init.sh | bash -s -- --account ${account} --project ${project} --gcpproject ${gcpproject} --region ${region}
```

where

```text
account    = GCP account email address
project    = project name (eg git repo plus random word)
gcpproject = GCP project name
region     = GCP region (eg europe-west2)
```

Note that `gcpproject` and the storage bucket with name `${project}-terraform-state` must be globally unique.

To cleanup a GCP project and bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/2.0.0/gcp-cleanup.sh | bash -s -- --project ${project} --gcpproject ${gcpproject}
```

where

```text
project    = project name (eg git repo plus random word)
gcpproject = GCP project name
```

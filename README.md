# Terraform Bucket

This repository provides scripts for bootstrapping buckets (and in the case of GCP, a project) to store Terraform state.

To initialise an AWS bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/v4.4.0/aws-init.sh | bash -s -- --prefix ${prefix} --project ${project} --profile ${profile} --region ${region} --tag ${tag}
```

where

```text
prefix  = prefix for uniqueness constraint
project = project name (eg git repo)
profile = AWS profile
region  = AWS region (eg eu-west-2)
tag     = tag to add to AWS resources
```

Note that the S3 bucket with name `${prefix}-${project}-terraform-state` must be globally unique.

To cleanup an AWS bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/v4.4.0/aws-cleanup.sh | bash -s -- --prefix ${prefix} --project ${project} --profile ${profile} --region ${region}
```

where

```text
prefix  = prefix for uniqueness constraint
project = project name (eg git repo)
profile = AWS profile
region  = AWS region (eg eu-west-2)
```

To initialise a GCP project and bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/v4.4.0/gcp-init.sh | bash -s -- --account ${account} --gcpproject ${gcpproject}
```

where

```text
account    = GCP account email address
gcpproject = GCP project name
```

Note that `gcpproject` and the storage bucket with name `${gcpproject}-terraform-state` must be globally unique.

To cleanup a GCP project and bucket use:

```bash
curl -L https://raw.githubusercontent.com/aps831/terraform-bucket/v4.4.0/gcp-cleanup.sh | bash -s -- --gcpproject ${gcpproject}
```

where

```text
gcpproject = GCP project name
```

#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"

state_key="bootstrap/terraform.tfstate"

if [[ -f backend.tf ]]; then
  if [[ -s terraform.tfstate ]]; then
    echo "Found both backend.tf and a local terraform.tfstate. Delete backend.tf and run this again." >&2
    exit 1
  fi
  echo "Nothing to do: backend.tf exists, so bootstrap's state is already in S3."
  exit 0
fi

if [[ ! -s terraform.tfstate ]]; then
  echo "No local terraform.tfstate found. Run tf apply on bootstrap first, then run this script." >&2
  exit 1
fi

terraform init -input=false
bucket=$(terraform output -raw tf_state_bucket)
region=$(terraform output -raw aws_region)
resource_count=$(terraform state list | wc -l) # list prints per line and we get the num lines
identity=$(aws sts get-caller-identity --region "$region" --query Arn --output text)

echo " Moving $resource_count resources to s3://$bucket/$state_key as $identity"

existing=$(aws s3api list-objects-v2 --bucket "$bucket" --prefix "$state_key" --region "$region" --no-paginate --query KeyCount --output text)
if [[ "$existing" != "0" ]]; then
  echo "s3://$bucket/$state_key already exists. Refusing to overwrite it." >&2
  exit 1
fi

cat > backend.tf <<'EOF'
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
EOF

if ! terraform init -input=false -migrate-state -force-copy \
  -backend-config="bucket=$bucket" \
  -backend-config="region=$region"; then

  rm -f backend.tf
  echo "Migration failed. backend.tf was removed." >&2
  exit 1
fi

if [[ "$(terraform state list | wc -l )" != "$resource_count" ]]; then
  echo "The state in S3 doesn't contain $resource_count resources. Check it before going further." >&2
  exit 1
fi
size=$(aws s3api head-object --bucket "$bucket" --key "$state_key" --region "$region" --query ContentLength --output text)
echo "==> State copied to S3: $resource_count resources, $size bytes."

if [[ ! -s terraform.tfstate ]]; then
  rm -f terraform.tfstate
fi
if [[ -f terraform.tfstate.backup ]]; then
  mv terraform.tfstate.backup terraform.tfstate.before-s3
fi

cat <<EOF

Done. Bootstrap's state is in s3://$bucket/$state_key.
The old local copy is bootstrap/terraform.tfstate.before-s3;
Commit bootstrap/backend.tf. On another machine, initialise bootstrap with:
  terraform init -backend-config="bucket=$bucket" -backend-config="region=$region"
EOF

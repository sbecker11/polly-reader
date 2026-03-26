#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <bucket-name>"
  exit 1
fi

BUCKET="$1"

run_optional() {
  local title="$1"
  shift
  echo "=== ${title} ==="
  if ! "$@"; then
    echo "(not configured or access denied)"
  fi
  echo
}

echo "Bucket report for: ${BUCKET}"
echo

run_optional "Location" aws s3api get-bucket-location --bucket "${BUCKET}"
run_optional "Bucket Info (creation date from list)" \
  aws s3api list-buckets --query "Buckets[?Name=='${BUCKET}']"
run_optional "Versioning" aws s3api get-bucket-versioning --bucket "${BUCKET}"
run_optional "Encryption" aws s3api get-bucket-encryption --bucket "${BUCKET}"
run_optional "Public Access Block" aws s3api get-public-access-block --bucket "${BUCKET}"
run_optional "Bucket Policy" aws s3api get-bucket-policy --bucket "${BUCKET}"
run_optional "Policy Status" aws s3api get-bucket-policy-status --bucket "${BUCKET}"
run_optional "ACL" aws s3api get-bucket-acl --bucket "${BUCKET}"
run_optional "Ownership Controls" aws s3api get-bucket-ownership-controls --bucket "${BUCKET}"
run_optional "Tags" aws s3api get-bucket-tagging --bucket "${BUCKET}"
run_optional "Lifecycle" aws s3api get-bucket-lifecycle-configuration --bucket "${BUCKET}"
run_optional "CORS" aws s3api get-bucket-cors --bucket "${BUCKET}"
run_optional "Logging" aws s3api get-bucket-logging --bucket "${BUCKET}"
run_optional "Website Hosting" aws s3api get-bucket-website --bucket "${BUCKET}"

echo "=== Objects Summary ==="
aws s3 ls "s3://${BUCKET}" --recursive --human-readable --summarize || \
  echo "(unable to list objects)"

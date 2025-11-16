#!/usr/bin/env bash
set -euo pipefail

# Creates ZIP archives for Lambda functions so Terraform can read them.
# Run from the repository root or from the `infrastructure` directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

echo "Packaging Lambdas..."
rm -f "${SCRIPT_DIR}/getShipments.zip" "${SCRIPT_DIR}/createShipments.zip"

if [ -d "${REPO_ROOT}/modernized-app/lambda/getShipments" ]; then
  (cd "${REPO_ROOT}/modernized-app/lambda/getShipments" && zip -r "${SCRIPT_DIR}/getShipments.zip" . >/dev/null)
  echo "Created ${SCRIPT_DIR}/getShipments.zip"
else
  echo "Warning: getShipments source not found at ${REPO_ROOT}/modernized-app/lambda/getShipments" >&2
fi

if [ -d "${REPO_ROOT}/modernized-app/lambda/createShipments" ]; then
  (cd "${REPO_ROOT}/modernized-app/lambda/createShipments" && zip -r "${SCRIPT_DIR}/createShipments.zip" . >/dev/null)
  echo "Created ${SCRIPT_DIR}/createShipments.zip"
else
  echo "Warning: createShipments source not found at ${REPO_ROOT}/modernized-app/lambda/createShipments" >&2
fi

echo "Done."

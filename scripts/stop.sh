#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "=========================================="
echo " Stopping application stack"
echo " Root: ${ROOT_DIR}"
echo "=========================================="

echo "===> Stopping containers and deleting volumes"

docker compose down -v --remove-orphans

echo
echo "===> Removing unused containers"
docker container prune -f

echo
echo "===> Removing folder"
rm -rf es_data postgres_data
echo "===> Completed removing folder"

echo
echo "=========================================="
echo " Stack stopped"
echo " Containers removed"
echo " Volumes removed"
echo "=========================================="
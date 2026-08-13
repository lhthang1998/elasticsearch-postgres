#!/usr/bin/env bash
set -euo pipefail

url="$1"
name="${2:-service}"
attempts="${3:-60}"
auth="${4:-}}" #optional

echo "Waiting for ${name} (${url})..."
for i in $(seq 1 "${attempts}"); do
  if [[ -n "${auth}" ]] then
    if curl -fsS -u "${auth}" "${url}" >dev/null 2>&1; then
      echo "${name} is ready."
      exit 0
    fi
  else
    if curl -fsS  "${url}" >dev/null 2>&1; then
      echo "${name} is ready."
      exit 0
    fi
  fi
  sleep 2
done

echo "${name} did not become ready after ${attempts} attempts" >&2
exit 1

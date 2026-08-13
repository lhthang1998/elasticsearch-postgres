#!/usr/bin/env bash
set -euo pipefail

url="$1"
name="${2:-service}"
attempts="${3:-60}"
auth="${4:-}" #optional

echo
echo "=========================================="
echo "Waiting for: ${name}"
echo "URL:         ${url}"
echo "Attempts:    ${attempts}"
echo "Auth:        $([[ -n "${auth}" ]] && echo "provided" || echo "none")"
echo "=========================================="
echo

for i in $(seq 1 "${attempts}"); do
    echo "[$(date '+%H:%M:%S')] Attempt ${i}/${attempts}"

    if [[ -n "${auth}" ]]; then
        echo "  -> curl with basic authentication"
        echo "  -> curl command:"
        echo "     curl --connect-timeout 3 --max-time 5 -sS -u '${auth}' -w '\\nHTTP_STATUS:%{http_code}' '${url}'"

        response="$(curl \
            --connect-timeout 3 \
            --max-time 5 \
            -sS \
            -u "${auth}" \
            -w '\nHTTP_STATUS:%{http_code}' \
            "${url}" 2>&1)" || curl_exit=$?

        curl_exit="${curl_exit:-0}"
    else
        echo "  -> curl without authentication"

        response="$(curl \
            --connect-timeout 3 \
            --max-time 5 \
            -sS \
            -w '\nHTTP_STATUS:%{http_code}' \
            "${url}" 2>&1)" || curl_exit=$?

        curl_exit="${curl_exit:-0}"
    fi

    echo "  -> curl exit code: ${curl_exit}"
    echo "  -> response:"
    echo "${response}" | sed 's/^/     /'

    if [[ "${curl_exit}" -eq 0 ]]; then
        echo
        echo "=========================================="
        echo "${name} is READY."
        echo "=========================================="
        exit 0
    fi

    echo "  -> ${name} is not ready yet."
    echo "  -> sleeping 2 seconds..."
    echo

    unset curl_exit
    sleep 2
done

echo
echo "=========================================="
echo "ERROR: ${name} did not become ready"
echo "URL: ${url}"
echo "Attempts: ${attempts}"
echo "=========================================="

exit 1

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

ES_USER="${ELASTICSEARCH_USERNAME:-admin}"
ES_PASS="${ELASTICSEARCH_PASSWORD:-passw0rd}"
ES_AUTH="${ES_USER}:${ES_PASS}"

PYTHON_BIN="${PYTHON_BIN:-python}"
SYNC=("${PYTHON_BIN}" "${ROOT_DIR}/tools/sync.py")

echo "===> Starting elasticsearch-postgres stack"
docker-compose up -d --build

echo "===> Waiting for elasticsearch"
"${ROOT_DIR}/scripts/wait-for.sh" "http://localhost:9200" "Elasticsearch" 90 "${ES_AUTH}"

echo "===> Waiting for Kafka Connect"
"${ROOT_DIR}/scripts/wait-for.sh" "http://localhost:8083" "Kafka Connect" 90



echo "===> Creating indices from elasticsearch/indices/"
"${SYNC[@]}" create-indices --recreate

echo "===> Register debezium + elasticsearch connectors"
"${SYNC[@]}" register-connectors

echo "===> Waiting for API"
"${ROOT_DIR}/scripts/wait-for.sh" "http://localhost:8083/health" "Node API" 90

echo "===> Waiting for initial CDC snapshot"
"${SYNC[@]}" wait-snapshot

cat <<EOF

Stack is up
  Postgres:               localhost:5432 (user: admin / pass: AdminDb_pass1 / db: bookstore)
  Elasticsearch:          http://localhost:9200 (user: admin / pass: passw0rd)
  Kafka Connect:          http://localhost:8083
  Search API:             http://localhost:3000


Tables -> indices:
  public.book     -> book
  public.author   -> author

Check everything at a glance:
  python3 tools/sync.py status

Try Vietnamese search:
  curl 'http://localhost:3000/books/search?q=hoa%20vàng'

Direct ES (basic auth):
  curl -u admin:passw0rd 'http://localhost:9200/book/_search?pretty'

EOF

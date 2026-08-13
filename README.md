# elasticsearch-postgres

Demo project that keeps the 'book' and 'author' tables in *PostgreSQL* as the source of truth and syncs *insert / update / delete* changes into *Elasticsearch* in near real time using *Debezium CDC* (Kafka Connect). A small *Node.js* API searches *Elasticsearch* with a *Vietnamese-friendly ICU analyzer*.

## Architecture
```text
┌──────────────────┐       ┌──────────────────────┐
│   PostgreSQL     │       │   Debezium source    │
│                  │──────►│   (Kafka Connect)    │
│   book, author   │       │                      │
└──────────────────┘       └──────────┬───────────┘
                                      │
                                      │ topics:
                                      │ bookstore.public.book
                                      │ bookstore.public.author
                                      ▼
                                ┌───────────┐
                                │   Kafka   │
                                └─────┬─────┘
                                      │
                                      ▼
                    ┌──────────────────────┐    upsert/delete    ┌──────────────────────┐
                    │ Elasticsearch        │ ─────────────────► │ Elasticsearch        │
                    │ sink connector       │                    │ indices:             │
                    │                      │                    │ book, author         │
                    └──────────────────────┘                    └──────────────────────┘
```

### Design choices

| Piece | Choice | Why |
| :--- | :--- | :--- |
| CDC | Debezium PostgreSQL connector ('pgoutput') | Captures INSERT/UPDATE/DELETE from the WAL without dual-writes |
| Transport | Kafka (KRaft) + Kafka Connect | Standard Debezium deployment; KRaft drops the extra Zookeeper container |
| Search store | Elasticsearch 8 + analysis-icu | + security | ICU tokenizer + folding for Vietnamese; basic auth enabled |
| Index definitions | elasticsearch/indices/ | One YAML file per index plus shared 'default.xml', instead of bodies hardcoded in a shell script |
| Document id | Postgres primary key 'id' | Sink extracts 'id' from the Kafka key so deletes remove the same '_id' |
| API | Node.js + elasticsearch |<br/> Thin search layer over the Vietnamese language (uses ES basic auth) |

Postgres remains authoritative. Elasticsearch holds a *denormalized search projection* that can lag by a short CDC delay. 'book' and 'author' are indexed independently - there is no join. Serving books with embedded author details would require enriching the streams (for example with Flink/ksqlDB) before indexing.

### CDC behavior

1. *Insert* - Debezium emits a create event -> sink *upserts* document _id = id
2. *Update* - Debezium emits an update with the new row -> sink *upserts* the same _id
3. *Delete* - Debezium emits a tombstone (null value) -> sink *deletes* _id (behavior.on.null.values=delete)

`REPLICA IDENTITY FULL` is set on both tables so updates/deletes always include enough key/column data for Debezium.

### Vietnamese search

Both indices share one analyzer definition, declared once in elasticsearch/indices/default.xml:
- icu_tokenizer - Unicode-aware tokenization
- lowercase
- icu_folding - folds accents/tones ('vàng' = 'vang')

The Node API uses multi_match with analyzer: vietnamese_search_analyzer on name + description (books) and name + biography (authors).

Note: ICU folding is a practical default for Vietnamese app search. For production linguistic stemming you may layer a dedicated Vietnamese analysis plugin or synonym dictionaries.


## Services

| Service | Host port | Credentials / notes |
| :--- | :--- | :--- |
| Postgres | 5432 | user: 'admin' / password: 'Adminb_Pass1' / db: 'bookstore' |
| Kafka | 9092 | single node in *KRaft* mode (no Zookeeper); internal bootstrap kafka:9092, controller on 9093 |
| Kafka Connect | 8083 | Debezium + Elasticsearch sink |
| Elasticsearch | 9200 | user: admin / password: 'password' (HTTP basic auth; TLS off for local demo) |
| Node API | 3000 | search endpoints (talks to ES with the admin credentials) |

Built-in Elasticsearch user 'elastic' is also set to password 'password' via ELASTIC_PASSWORD (bootstrap requirement). App connectors and scripts use 'admin'.

## Prerequisites

- Docker + Docker Compose v2
- curl (used by start.sh / wait-for.sh)
- python3 - start.sh installs tools/requirements.txt (PYYAML, requests) automatically when they are missing; to do it by hand: python3 -m pip install -r tools/requirements.txt
- A YAML parser for Elasticsearch/indices/ - yq, Python with PyYAML, or the system ruby (macOS ships one, so usually nothing to install)
- ~4 GB RAM free for the full stack

## Quick start
```bash
cd ~/projects/elasticsearch-postgres
chmod +x scripts/*.sh
./scripts/start.sh
```

`start.sh` will:

1. Install tools/requirements.txt if PyYAML or requests are missing
2. docker compose up -d --build
3. Wait for Elasticsearch and Kafka Connect
4. Create every index declared in elasticsearch/indices/ (book, author)
5. Register the Debezium source + Elasticsearch sink connectors
6. Wait for the Node API and the initial CDC snapshot

## Tooling: tools/sync.py

Operational tasks live in one Python script instead of a pile of shell:

| Command | Purpose |
| :--- | :--- |
| create-indices | Apply elasticsearch/indices/*.yml, merged over default.yml |
| register-connectors | (Re)register the Debezium source and Elasticsearch sink |
| wait-snapshot | Block until the initial CDC snapshot lands in Elasticsearch |
| status | Cluster health, per-index document counts, connector/task states |

```bash
python3 -m pip install -r tools/requirements.txt

python3 tools/sync.py status
python3 tools/sync.py create-indices --help
```

Connection details come from the environment, with local defaults baked in:
ELASTICSEARCH_URL, ELASTICSEARCH_USERNAME, ELASTICSEARCH_PASSWORD, CONNECT_URL.

Manual equivalent:
```bash
docker compose up -d --build
./scripts/wait-for.sh http://localhost:9200 Elasticsearch 90 admin:password
./scripts/wait-for.sh http://localhost:8083/ "Kafka Connect"
python3 tools/sync.py create-indices --recreate
python3 tools/sync.py register-connectors
```

## Schema
```sql
CREATE TABLE book (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    year INTEGER
);

CREATE TABLE author (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    biography TEXT,
    country TEXT
);
```

Seed data (Vietnamese + English) is loaded from `postgres/init.sql` on first Postgres start.

## Index definitions (YAML)

Indices live in `elasticsearch/indices/`, one file per index plus shared defaults:

```
elasticsearch/indices/
    default.yml # settings + mappings every index inherits
    book.yml    # -> index 'book'
    author.yml  # -> index 'author'
```

`tools/sync.py` create-indices deep-merges each `<name>.yml` on top of `default.yml` and sends the result to `PUT /<name>`:
- **Index name** = file name (`author.yml` -> `author`), unless the file sets an explicit `index` key.
- **Merging is recursive** for objects, so an index file lists only the fields it adds. Scalars and lists it defines replace the default.
- `default.yml` is never created as an index; it only supplies defaults.

`default.yml` holds the ICU analyzers and the columns every table shares:

```yaml
settings:
    number_of_shards: 1
    analysis:
        analyzer:
            vietnamese_analyzer: { type: custom, tokenizer: icu_tokenizer, filter: [lowercase, icu_folding] }
mappings:
    properties:
        id: { type: long }
        name: { type: text, analyzer: vietnamese_analyzer, search_analyzer: vietnamese_search_analyzer }
```

`author.yml` then only declares what is specific to authors:
```yaml
mappings:
  properties:
    biography: { type: text, analyzer: vietnamese_analyzer, search_analyzer: vietnamese_search_analyzer }
    country: { type: keyword }
```

Adding a third table is therefore: add the table to `postgres/init.sql`, drop a `<table>.yml` here, and add the table to the source connector's `table.include.list` and the sink's `topics`.

Apply the definitions:

```bash
python3 tools/sync.py create-indices             # create missing indices, leave existing ones alone
python3 tools/sync.py create-indices --recreate   # drop and recreate (loses indexed data)
python3 tools/sync.py create-indices --only book  # apply a single index
```

Inspect what would be sent, without touching Elasticsearch:

```bash
python3 tools/sync.py create-indices --dry-run --only author
```

`RECREATE=true` in the environment is equivalent to `--recreate`.

**Index names must match the table names**, because the sink's `RegexRouter` maps `bookstore.public.<table>` to the index `<table>`.

After changing mappings, recreate the indices and restart the source connector so a fresh snapshot repopulates them:

```bash
python3 tools/sync.py create-indices --recreate
curl -X POST http://localhost:8083/connectors/postgres-bookstore-source/restart
```

## Search API

Health:

```bash
curl http://localhost:3000/health
```

| Endpoint | Purpose |
| --- | --- |
| `GET /books` / `GET /authors` | List indexed documents |
| `GET /books/search?q=` / `GET /authors/search?q=` | Vietnamese full-text search |
| `GET /books/:id` / `GET /authors/:id` | Fetch one document by primary key |

```bash
curl 'http://localhost:3000/books'
curl 'http://localhost:3000/authors'
```

## CDC demo
```bash
curl 'http://localhost:3000/books/search?q=hoa%20vang'
curl 'http://localhost:3000/books/search?q=hoa%20vang' # tone-insensitive via ICU folding
curl 'http://localhost:3000/authors/search?q=nguyen%20nhat%20anh'
```

```bash
docker exec -it postgres psql -U admin -d bookstore \
-c "INSERT INTO book (name, description, year) VALUES ('Mắt biếc', 'Câu chuyện tình của Ngạn và Hà Lan.', 1990);"
```

### Update
```bash
docker exec -it postgres psql -U admin -d bookstore \
-c "UPDATE book SET description = 'Bản cập nhật mô tả Mắt biếc' WHERE name = 'Mắt biếc';"
```

### Delete
```bash
docker exec -it postgres psql -U admin -d bookstore \
-c "DELETE FROM book WHERE name = 'Mắt biếc';"
```

Confirm removal:
```bash
curl 'http://localhost:3000/books/search?q=mắt%20biếc'
```
or
```bash
curl -u admin:password 'http://localhost:9200/book/_search?q=name:Mắt'
```

### Author changes flow the same way
```bash
docker exec -it postgres psql -U admin -d bookstore \
-c "INSERT INTO author (name, biography, country) VALUES ('Tô Hoài', 'Tác giả Dế Mèn phiêu lưu ký.', 'Việt Nam');"
curl "http://localhost:3000/authors/search?q=tô%20hoài"
```

## Connector configs
```bash
connect-config/postgres-source.json # Debezium Postgres source ('table.include.list=public.book,public.author')
connect-config/elasticsearch-sink.json # unwrap Debezium envelope, use 'id' as ES document id, route each topic to its index, delete on tombstones
```

The `elasticsearch` sink derives the index name from the topic name, and `topic.index.map` was removed in sink version 11.0.0. A `RegexRouter` transform therefore rewrites `bookstore.public.(.*)` -> `$1`, so `bookstore.public.author` lands in the `author` index created with the Vietnamese analyzer.

Connector names are `postgres-bookstore-source` and `elasticsearch-bookstore-sink`. `tools/sync.py register-connectors` deletes each one before posting it, so re-running is safe. It prints a per-task state summary when it finishes, and `--dry-run` shows what it would register.

Inspect connector status:
```bash
curl http://localhost:8083/connectors?expand=status | python3 -m json.tool
```

## Project layout
```text
README.md
elasticsearch-postgres/
docker-compose.yml         
api/                       # Node.js search service
connect/Dockerfile         # Debezium Connect + ES sink plugin               
connect-config/            # Connector JSON definitions
elasticsearch/
  Dockerfile               # ES 8 + analysis-icu + admin user
  config/elasticsearch.yml # one YAML file per index + shared default.yml
postgres/init.sql          # book + author tables + seed rows
scripts/
  start.sh                 # one-command bring-up
  wait-for.sh              # HTTP readiness polling
```

Only those two files are shell. Every other operation lives in Python:
```text
tools/
  requirements.txt   # PYYAML, requests
  sync.py             # create-indices / register-connectors / wait-snapshot / status
```
## Stop / reset
```bash
docker compose down
# wipe CDC + index + DB state (required after credential changes )
docker compose down -v
```

After a volume wipe, run /scripts/start.sh again so Postg res re-seeds and connectors re-snapshot.
If you previous ly started the stack with older usernames/passwo rds, run docker compose down -v' before ./scripts/start. sh' so Postgres and Elasticsearch
recreate auth state cleanly.

FROM docker.elastic.co/elasticsearch/elasticsearch:8.15.3

# ICU analysis plugin - tokenizer + folding for Vietnamese (and other Unicode) text
RUN elasticsearch-plugin install --batch analysis-icu

COPY config/elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml

# Local demo user: admin / pass0wrd (file realm)
RUN bin/elasticsearch-users useradd admin -p passw0rd -r superuser
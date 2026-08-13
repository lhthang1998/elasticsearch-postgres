FROM quay.io/debezium/connect:2.7

# Install Confluent Elasticsearch Sink so CDC topics can be written to Elasticsearch
# https://www.confluent.io/hub/confluentinc/kafka-connect-elasticsearch
ARG ES_CONNECTOR_VERSION=14.1.1


USER root
RUN curl -fsSl \
    "https://hub-downloads.confluent.io/api/plugins/confluentinc/kafka-connect-elasticsearch/versions/${ES_CONNECTOR_VERSION}/confluentinc-kafka-connect-elasticsearch-${ES_CONNECTOR_VERSION}.zip" \
    -o /tmp/es-connector.zip \
    && unzip -q /tmp/es-connector.zip -d /kafka/connect \
    && rm -f /tmp/es-connector.zip \
    && chown -R kafka:kafka /kafka/connect

USE kafka
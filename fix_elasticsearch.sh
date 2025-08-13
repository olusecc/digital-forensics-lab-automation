#!/bin/bash

# Fix Elasticsearch configuration for single-node operation
cat > /tmp/elasticsearch-fix.yml << 'EOF'
version: '3.7'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - node.name=forensics-node-1
      - cluster.name=forensics-cluster
      - discovery.type=single-node
      - xpack.security.enabled=false
      - xpack.security.enrollment.enabled=false
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - bootstrap.memory_lock=true
      - indices.replication.max_concurrent_allocations=1
      - action.auto_create_index=+forensics*,-.kibana*,-.security*
    ulimits:
      memlock:
        soft: -1
        hard: -1
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - elk

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - XPACK_SECURITY_ENABLED=false
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: logstash
    ports:
      - "5044:5044"
      - "9600:9600"
    environment:
      - "LS_JAVA_OPTS=-Xmx256m -Xms256m"
    depends_on:
      - elasticsearch
    networks:
      - elk
    command: logstash -e 'input { beats { port => 5044 } } output { elasticsearch { hosts => ["elasticsearch:9200"] } }'

volumes:
  elasticsearch-data:

networks:
  elk:
    driver: bridge
EOF

echo "Restarting ELK stack with single-node configuration..."
docker-compose -f /tmp/elasticsearch-fix.yml down
docker-compose -f /tmp/elasticsearch-fix.yml up -d

echo "Waiting for services to start..."
sleep 30

echo "Checking Elasticsearch health..."
curl -X GET "localhost:9200/_cluster/health?pretty"

echo "Creating index template for forensics data..."
curl -X PUT "localhost:9200/_index_template/forensics-template" -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["forensics-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    },
    "mappings": {
      "properties": {
        "@timestamp": {
          "type": "date"
        },
        "case_id": {
          "type": "keyword"
        },
        "evidence_type": {
          "type": "keyword"
        },
        "investigator": {
          "type": "keyword"
        },
        "stage": {
          "type": "keyword"
        },
        "status": {
          "type": "keyword"
        },
        "details": {
          "type": "text"
        }
      }
    }
  }
}
'

echo "ELK stack reconfigured for single-node operation!"

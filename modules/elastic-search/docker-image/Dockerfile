FROM docker.elastic.co/elasticsearch/elasticsearch:8.9.0

USER root

ENV discovery.type=single-node

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
USER elasticsearch
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["eswrapper"]


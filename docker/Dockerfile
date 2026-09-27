FROM cgr.dev/chainguard/python:latest-dev@sha256:d7a9ff52942e89e188372fce9049640087f48473ceeb8cee2495f8136620fc3c

USER root
COPY docker/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --requirement /tmp/requirements.txt
USER 65532

ENTRYPOINT ["/workspace/scripts/configure-container.sh"]

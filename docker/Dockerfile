FROM cgr.dev/chainguard/python:latest-dev@sha256:df9869a05f74ef57bd9fb8d9185f91cd3d93e70d7a89860795525d8c2ddebc50

USER root
COPY docker/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --requirement /tmp/requirements.txt
USER 65532

ENTRYPOINT ["/workspace/scripts/configure-container.sh"]

FROM cgr.dev/chainguard/python:latest-dev@sha256:c07959e43e3edece176d20c32428a53014379790169af4ea5de1dc47277eba75

USER root
COPY docker/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --requirement /tmp/requirements.txt
USER 65532

ENTRYPOINT ["/workspace/scripts/configure-container.sh"]

FROM cgr.dev/chainguard/python:latest-dev@sha256:df9869a05f74ef57bd9fb8d9185f91cd3d93e70d7a89860795525d8c2ddebc50

USER root
RUN pip install --no-cache-dir "pillow==12.3.0" "qrcode==8.2"
USER 65532

ENTRYPOINT ["/workspace/scripts/configure-container.sh"]

FROM python:3.13-alpine

RUN apk add --no-cache bash \
    && pip install --no-cache-dir "qrcode[pil]==8.2"

ENTRYPOINT ["/workspace/scripts/configure.sh"]

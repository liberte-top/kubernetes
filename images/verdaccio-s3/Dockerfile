FROM node:20-alpine

ARG VERDACCIO_VERSION=5.33.0
ARG VERDACCIO_S3_STORAGE_VERSION=10.4.0

RUN npm install --global \
      verdaccio@${VERDACCIO_VERSION} \
      verdaccio-aws-s3-storage@${VERDACCIO_S3_STORAGE_VERSION} \
    && npm cache clean --force \
    && mkdir -p /verdaccio/conf /verdaccio/storage /verdaccio/auth \
    && chown -R node:node /verdaccio

ENV NODE_PATH=/usr/local/lib/node_modules

USER node
WORKDIR /verdaccio
EXPOSE 4873

CMD ["verdaccio", "--config", "/verdaccio/conf/config.yaml", "--listen", "0.0.0.0:4873"]

ARG ANSIBLE_VERSION
ARG ANSIBLE_CONNECTWARE_COLLECTION_VERSION
ARG AWS

# --------------------------------------------------------------------------------------------------
# Builder Image
# --------------------------------------------------------------------------------------------------
FROM alpine:3.16 AS builder

# Required tools for building Python packages
RUN set -eux \
	&& apk add --no-cache \
		bc \
		curl \
		gcc \
		libffi-dev \
		libc-dev \
		make \
		musl-dev \
		openssl-dev \
		python3 \
		python3-dev \
		py-pip \
		docker

# Python packages (copied to final image)
RUN set -eux \
	&& apk add --no-cache  \
	&& pip3 install --no-cache-dir --no-compile \
    docker \
    docker-compose \
    jsondiff \
    boto3 \
	&& find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# --------------------------------------------------------------------------------------------------
# Final Image
# --------------------------------------------------------------------------------------------------
FROM cytopia/ansible:${ANSIBLE_VERSION:-latest}-${ANSIBLE_VERSION:-awshelm3.7} AS production

LABEL maintainer="jforge <github@jforge.de>"

COPY --from=builder /usr/lib/python3.10/site-packages/ /usr/lib/python3.10/site-packages/
COPY --from=builder /usr/bin/docker /usr/bin/docker
COPY --from=builder /usr/bin/docker-compose /usr/bin/docker-compose

# add mqtt tools
RUN pip3 install paho-mqtt
RUN apk add mosquitto mosquitto-clients jq yq
RUN ansible-galaxy collection install community.general amazon.aws cybus.connectware:${ANSIBLE_CONNECTWARE_COLLECTION_VERSION:-2.0.13} 

WORKDIR /data
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]

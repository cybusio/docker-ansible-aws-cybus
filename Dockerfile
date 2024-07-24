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
		docker \
		docker-cli-compose

# Python packages (copied to final image)
RUN set -eux \
	&& pip3 install --no-cache-dir --no-compile \
    docker \
    jsondiff \
	&& find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# --------------------------------------------------------------------------------------------------
# Final Image
# --------------------------------------------------------------------------------------------------
FROM cytopia/ansible:${ANSIBLE_VERSION:-latest}-${ANSIBLE_VERSION:-awshelm3.10} AS production

LABEL maintainer="jforge <github@jforge.de>"

COPY --from=builder /usr/lib/python3.10/site-packages/ /usr/lib/python3.10/site-packages/
COPY --from=builder /usr/bin/docker /usr/bin/docker

# add mqtt and json/yaml tools & upgrade ansible 
RUN pip3 install paho-mqtt boto3 ansible --upgrade
RUN apk add mosquitto mosquitto-clients jq yq
RUN ansible-galaxy collection install community.general amazon.aws cybus.connectware:${ANSIBLE_CONNECTWARE_COLLECTION_VERSION:-2.2.1}

WORKDIR /data
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]

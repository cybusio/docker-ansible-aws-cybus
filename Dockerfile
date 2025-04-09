ARG ANSIBLE_VERSION
ARG AWS

# --------------------------------------------------------------------------------------------------
# Builder Image
# --------------------------------------------------------------------------------------------------
FROM alpine:3.21.3 AS builder

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
		py3-pip \
		docker \
		docker-cli-compose

# Python packages (copied to final image)
RUN set -eux \
	&& pip3 install --break-system-packages --no-cache-dir --no-compile \
      docker \
      jsondiff \
	&& find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# Clean-up some site-packages to safe space
RUN set -eux \
	&& pip3 uninstall --break-system-packages --yes \
		setuptools \
		wheel \
	&& find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf

# --------------------------------------------------------------------------------------------------
# Final Image
# --------------------------------------------------------------------------------------------------
FROM cytopia/ansible:${ANSIBLE_VERSION:-latest}-${ANSIBLE_VERSION:-awshelm3.11} AS production

LABEL maintainer="jforge <github@jforge.de>"
LABEL org.opencontainers.image.authors=
LABEL org.opencontainers.image.created=
LABEL org.opencontainers.image.description=
LABEL org.opencontainers.image.documentation="https://github.com/jforge/docker-ansible-aws-cybus"
LABEL org.opencontainers.image.name="ansible-aws-cybus"
LABEL org.opencontainers.image.ref.name=
LABEL org.opencontainers.image.revision=
LABEL org.opencontainers.image.source="https://github.com/jforge/docker-ansible-aws-cybus"
LABEL org.opencontainers.image.title="Ansible AWS Helm K8s Cybus collection"
LABEL org.opencontainers.image.url="https://github.com/jforge/docker-ansible-aws-cybus"
LABEL org.opencontainers.image.vendor="jforge"

COPY --from=builder /usr/lib/python3.12/site-packages/ /usr/lib/python3.12/site-packages/
COPY --from=builder /usr/bin/docker /usr/bin/docker

# add mqtt and json/yaml tools & upgrade ansible 
RUN pip3 install paho-mqtt boto3 ansible --upgrade
RUN apk add mosquitto mosquitto-clients jq yq
RUN ansible-galaxy collection install community.general amazon.aws cybus.connectware:2.3.0

WORKDIR /data
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]

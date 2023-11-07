# Defines a development environment container image. Can be used with:
# - Docker: https://www.docker.com/
# - Podman: https://podman.io/

FROM alpine:3.18.4

RUN apk add --no-cache \
	# asdf prerequisites
	bash curl git \
	# project prerequisites
	jq make python3 py3-pip

WORKDIR /setup
COPY .tool-versions .

ENV ASDF_DIR="/.asdf"
RUN git clone https://github.com/asdf-vm/asdf.git /.asdf --branch v0.11.1 \
	&& echo '. "/.asdf/asdf.sh"' > ~/.bashrc \
	&& . "/.asdf/asdf.sh" \
	&& asdf plugin add actionlint \
	&& asdf plugin add hadolint \
	&& asdf plugin add shellcheck \
	&& asdf plugin add shfmt \
	&& asdf install

ENTRYPOINT ["/bin/bash"]

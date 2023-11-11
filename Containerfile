# SPDX-License-Identifier: MIT

# Check out Docker at: https://www.docker.com/
# Check out Podman at: https://podman.io/

FROM alpine:3.18.4

RUN apk add --no-cache \
	# asdf prerequisites
	bash curl git \
	# project prerequisites
	jq make python3 py3-pip

ENV ASDF_DIR="/.asdf"

WORKDIR /setup
COPY .tool-versions .

RUN git clone https://github.com/asdf-vm/asdf.git /.asdf --branch v0.13.1 \
	&& echo '. "/.asdf/asdf.sh"' > ~/.bashrc \
	&& . "/.asdf/asdf.sh" \
	&& asdf plugin add actionlint \
	&& asdf plugin add hadolint \
	&& asdf plugin add shellcheck \
	&& asdf plugin add shfmt \
	&& asdf install

ENTRYPOINT ["/bin/bash"]

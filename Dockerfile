# Check out Docker at: https://www.docker.com/
# NOTE: this image is intended for development purposes only.

FROM alpine:3.18.3

RUN apk add --no-cache \
	# asdf prerequisites
	bash curl git \
	# project prerequisites
	jq make python3 py3-pip

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /setup
COPY .tool-versions .

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.1 \
	&& echo '. "$HOME/.asdf/asdf.sh"' > ~/.bashrc \
	&& . "$HOME/.asdf/asdf.sh" \
	&& asdf plugin add actionlint \
	&& asdf plugin add hadolint \
	&& asdf plugin add shellcheck \
	&& asdf plugin add shfmt \
	&& asdf install

ENTRYPOINT ["/bin/bash"]

# Check out Docker at: https://www.docker.com/
# NOTE: this image is intended for development purposes only.

FROM alpine:3.17.2

RUN apk add --no-cache \
	# asdf prerequisites
	bash curl git \
	# project prerequisites
	jq make python3

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.1 \
	&& echo '. "$HOME/.asdf/asdf.sh"' > ~/.bashrc \
	&& . "$HOME/.asdf/asdf.sh" \
	&& asdf plugin add actionlint \
	&& asdf plugin add shellcheck \
	&& asdf plugin add shfmt

ENTRYPOINT ["/bin/bash"]

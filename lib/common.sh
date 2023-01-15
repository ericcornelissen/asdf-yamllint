#!/usr/bin/env bash

set -eo pipefail

base_url="https://pypi.org/pypi/yamllint"

exit_code_missing_env_var=1
exit_code_missing_cmd=2

_get_download_url() {
	local -r version="$1"

	curl --silent "${base_url}/${version}/json" | jq -r '.urls[1].url'
}

# Based on https://github.com/rbenv/ruby-build/blob/697bcff/bin/ruby-build#L1371-L1374
_sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' | \
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

check_env_var() {
	local -r name="$1"
	local -r value="$2"

	if [ -z "${value}" ]; then
		echo "Missing '${name}'"
		exit "${exit_code_missing_env_var}"
	fi
}

check_prerequisite() {
	local -r name="$1"

	if [ -z "$(command -v "${name}")" ]; then
		echo "'${name} 'is required for this command"
		exit "${exit_code_missing_cmd}"
	fi
}

list_versions() {
	curl --silent "https://pypi.org/pypi/yamllint/json" |
		jq --raw-output '.releases | keys[]' |
		_sort_versions
}

download_version() {
	local -r version="$1"
	local -r install_path="$2"

	local -r download_url="$(_get_download_url "${version}")"

	mkdir -p "${install_path}"

	echo "Downloading yamllint from ${download_url} to ${install_path}"
	curl --silent "${download_url}" | \
		tar --extract --gzip \
			--directory "${install_path}" \
			"yamllint-${version}"
}

install_version() {
	local -r version="$1"
	local -r install_path="$2"
	local -r download_path="$3"

	local -r bin_install_path="${install_path}/bin"
	local -r bin_path="${bin_install_path}/yamllint"

	mkdir -p "${bin_install_path}"

	if [ -n "${download_path}" ]; then
		cp -r "${download_path}/yamllint-${version}" "${install_path}"
	fi

	(
		cd "${install_path}/yamllint-${version}";
		python3 -m pip install --quiet --requirement yamllint.egg-info/requires.txt
	)
	{
		echo '#!/usr/bin/env bash'
		echo ''
		echo "PYTHONPATH=\"\${PYTHONPATH}:${install_path}/yamllint-${version}\" \\"
		echo "python3 '${install_path}/yamllint-${version}/yamllint/__main__.py' \"\$@\""
	} >> "${bin_path}"
	chmod +x "${bin_path}"
}

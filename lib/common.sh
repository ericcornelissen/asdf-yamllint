#!/usr/bin/env bash

set -eo pipefail

base_url="https://pypi.org/pypi/yamllint"

exit_code_missing_env_var=1
exit_code_missing_cmd=2

_check_prerequisite() {
	local -r name="$1"

	if [ -z "$(command -v "${name}")" ]; then
		echo "'${name} 'is required for this command"
		exit "${exit_code_missing_cmd}"
	fi
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

list_versions() {
	_check_prerequisite 'curl'
	_check_prerequisite 'jq'
	_check_prerequisite 'sed'
	_check_prerequisite 'sort'
	_check_prerequisite 'awk'

	curl --silent "https://pypi.org/pypi/yamllint/json" |
		jq --raw-output '.releases | keys[]' |
		_sort_versions
}

download_version() {
	_check_prerequisite 'curl'
	_check_prerequisite 'jq'
	_check_prerequisite 'rm'
	_check_prerequisite 'tar'

	local -r version="$1"
	local -r install_path="$2"

	local -r version_json="$(curl --silent "${base_url}/${version}/json")"
	local -r download_json="$(echo "${version_json}" | jq -r '.urls[1]')"
	local -r download_url="$(echo "${download_json}" | jq -r '.url')"
	local -r tar_checksum="$(echo "${download_json}" | jq -r '.digests.sha256')"

	local -r checksum_file="${install_path}/checksum.txt"
	local -r tar_file="${install_path}/yamllint-${version}.tar.gz"

	mkdir -p "${install_path}"

	echo "Downloading yamllint from ${download_url} to ${install_path}"
	curl --silent --show-error \
		--output "${tar_file}" \
		"${download_url}"

	echo "Verifying checksum for ${tar_file}"
	local shasum_command='shasum --algorithm 256'
	if ! command -v shasum &>/dev/null; then
		shasum_command='sha256sum'
	fi
	echo "${tar_checksum}  ${tar_file}" > "${checksum_file}"
	${shasum_command} --quiet --check "${checksum_file}"

	tar --extract --gzip \
		--directory "${install_path}" \
		--file "${tar_file}" \
		"yamllint-${version}"

	rm -f "${checksum_file}" "${tar_file}"
}

install_version() {
	_check_prerequisite 'mkdir'
	_check_prerequisite 'cp'
	_check_prerequisite 'python3'

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

#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -eo pipefail

base_url="https://pypi.org/pypi/yamllint"

exit_code_missing_env_var=1

_get_python_command() {
	# Both `python3` and `python` are names commonly used for the Python 3 binary.
	# The former is definitely Python 3, but not always used. The latter may be
	# either Python 2 or Python 3 so is used as a fallback and only if it's v3.
	# The focus on the Python version follows from yamllint only supporting v3.
	local python_command='python3'
	if ! command -v python3 &>/dev/null; then
		if [[ "$(python --version)" =~ .*" 3".* ]]; then
			python_command='python'
		fi
	fi

	echo "${python_command}"
}

_sort_versions() {
	# Sort versions as humans would expect rather than just alphabetically.
	# ref: https://github.com/rbenv/ruby-build/blob/697bcff/bin/ruby-build#L1371
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n |
		awk '{print $2}'
}

_validate_checksum() {
	local -r file="$1"
	local -r expected_checksum="$2"

	local -r checksum_file="$(dirname "${file}")/checksum.txt"

	# Different systems have different programs for computing SHA checksums. To
	# broaden support, multiple programs are considered. We use whichever one is
	# available on the current system.
	local shasum_command='shasum -a 256'
	if ! command -v shasum &>/dev/null; then
		shasum_command='sha256sum'
	fi

	echo "${expected_checksum}  ${file}" >"${checksum_file}"
	${shasum_command} -c "${checksum_file}" 1>/dev/null

	rm -f "${checksum_file}"
}

check_env_var() {
	local -r name="$1"
	local -r value="$2"

	if [ -z "${value}" ]; then
		echo "Missing '${name}'"
		exit "${exit_code_missing_env_var}"
	fi
}

latest_version() {
	curl --silent "${base_url}/json" |
		jq --raw-output '.info.version'
}

list_versions() {
	curl --silent "${base_url}/json" |
		jq --raw-output '.releases | keys[]' |
		_sort_versions
}

download_version() {
	local -r version="$1"
	local -r download_path="$2"

	local -r version_json="$(curl --silent "${base_url}/${version}/json")"
	local -r download_json="$(echo "${version_json}" | jq -r '.urls[] | select(.packagetype == "sdist")')"
	local -r download_url="$(echo "${download_json}" | jq -r '.url')"
	local -r tar_checksum="$(echo "${download_json}" | jq -r '.digests.sha256')"

	local -r tar_file="${download_path}/yamllint-${version}.tar.gz"

	mkdir -p "${download_path}"

	echo "Downloading yamllint from ${download_url} to ${download_path}"
	curl --silent --show-error \
		--output "${tar_file}" \
		"${download_url}"

	echo "Verifying checksum for ${tar_file}"
	_validate_checksum "${tar_file}" "${tar_checksum}"

	tar --extract --gzip \
		--directory "${download_path}" \
		--file "${tar_file}" \
		"yamllint-${version}"

	rm -f "${tar_file}"
}

install_version() {
	local -r version="$1"
	local -r install_path="$2"
	local -r download_path="$3"

	local -r python_command="$(_get_python_command)"

	local -r src_dir_name="yamllint-${version}"

	local -r bin_install_path="${install_path}/bin"
	local -r bin_path="${bin_install_path}/yamllint"
	local -r src_path="${install_path}/${src_dir_name}"
	local -r venv_path="${src_path}/__venv__"

	mkdir -p "${bin_install_path}"

	if [ -n "${download_path}" ]; then
		cp -r "${download_path}/${src_dir_name}" "${install_path}"
	fi

	${python_command} -m venv "${venv_path}"
	# shellcheck disable=SC1091
	source "${venv_path}/bin/activate"

	(
		cd "${src_path}"
		sed -i -e '/^\[/d' yamllint.egg-info/requires.txt
		${python_command} \
			-m pip install \
			--quiet \
			--disable-pip-version-check \
			--requirement yamllint.egg-info/requires.txt
	)

	deactivate

	{
		echo '#!/usr/bin/env bash'
		echo ''
		echo "source '${venv_path}/bin/activate'"
		echo "PYTHONPATH=\"\${PYTHONPATH}:${install_path}/yamllint-${version}\" \\"
		echo "${python_command} '${install_path}/yamllint-${version}/yamllint/__main__.py' \"\$@\""
		echo 'ret_val=$?'
		echo "deactivate"
		# shellcheck disable=SC2016
		echo 'exit "${ret_val}"'
	} >>"${bin_path}"
	chmod +x "${bin_path}"
}

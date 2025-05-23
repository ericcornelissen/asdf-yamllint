# shellcheck shell=bash
# SPDX-License-Identifier: MIT

base_url="https://pypi.org/pypi/yamllint"

_error() {
	local -r msg="$1"
	echo "Error: ${msg}" >&2
}

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

	if [[ ! -f ${file} ]]; then
		_error "'${file}' not found"
		return 1
	fi

	# Different systems have different programs for computing SHA checksums. To
	# broaden support, multiple programs are considered. We use whichever one is
	# available on the current system.
	local shasum_command='shasum -a 256'
	if ! command -v shasum &>/dev/null; then
		if command -v sha256sum &>/dev/null; then
			shasum_command='sha256sum'
		fi
	fi

	local -r checksum_file="$(dirname "${file}")/checksum.txt"
	echo "${expected_checksum}  ${file}" >"${checksum_file}"

	${shasum_command} -c "${checksum_file}" 1>/dev/null 2>/dev/null || {
		_error 'computed checksums did NOT match'
		rm -f "${checksum_file}"
		return 1
	}

	rm -f "${checksum_file}"
}

check_env_var() {
	local -r name="$1"

	if [ -z "${!name}" ]; then
		_error "missing environment variable '${name}'"
		return 1
	fi
}

latest_version() {
	local -r url="${base_url}/json"

	response=$(curl --fail --silent "${url}") || {
		_error "could not fetch metadata from ${url}"
		return 1
	}

	version=$(echo "${response}" | jq --raw-output '.info.version') || {
		_error "${response}"
		_error 'could not parse metadata from the above response'
		return 1
	}

	if [[ -z ${version} || ${version} == "null" ]]; then
		_error "${response}"
		_error 'could not find version information in the above response'
		return 1
	fi

	echo "${version}"
}

list_versions() {
	local -r url="${base_url}/json"

	response=$(curl --fail --silent "${url}") || {
		_error "could not fetch metadata from ${url}"
		return 1
	}

	versions=$(echo "${response}" | jq --raw-output '.releases | keys[]') || {
		_error "${response}"
		_error 'could not parse metadata from the above response'
		return 1
	}

	if [[ -z ${versions} ]]; then
		_error "${response}"
		_error 'could not find version information in the above response'
		return 1
	fi

	echo "${versions}" | _sort_versions
}

download_version() {
	local -r version="$1"
	local -r download_path="$2"

	local -r version_url="${base_url}/${version}/json"
	response="$(curl --fail --silent "${version_url}")" || {
		_error "could not fetch metadata from ${version_url}"
		return 1
	}
	metadata=$(echo "${response}" | jq -r '.urls[] | select(.packagetype == "sdist")') || {
		_error "${response}"
		_error 'could not parse metadata from the above response'
		return 1
	}
	download_url=$(echo "${metadata}" | jq -r '.url') || {
		_error "${metadata}"
		_error 'could not parse the download URL from the above metadata'
		return 1
	}
	tar_checksum=$(echo "${metadata}" | jq -r '.digests.sha256') || {
		_error "${metadata}"
		_error 'could not parse the checksum from the above metadata'
		return 1
	}

	local -r tar_file="${download_path}/yamllint-${version}.tar.gz"

	mkdir -p "${download_path}" || {
		_error "failed to create the download directory ${download_path}"
		return 1
	}

	echo "Downloading yamllint from ${download_url} to ${download_path}"
	curl --fail --silent --show-error \
		--output "${tar_file}" \
		"${download_url}" ||
		{
			_error "failed to download yamllint from ${download_url}"
			return 1
		}

	echo "Verifying checksum for ${tar_file}"
	_validate_checksum "${tar_file}" "${tar_checksum}" || return 1

	tar --extract --gzip \
		--directory "${download_path}" \
		--file "${tar_file}" \
		"yamllint-${version}" ||
		{
			_error "failed to extract ${tar_file} into ${download_path}"
			rm -f "${tar_file}"
			return 1
		}

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

	mkdir -p "${bin_install_path}" || {
		_error "failed to create the installation directory ${bin_install_path}"
		return 1
	}

	if [ -n "${download_path}" ]; then
		cp -r "${download_path}/${src_dir_name}" "${install_path}"
	fi

	${python_command} -m venv "${venv_path}" || {
		_error "failed to create a virtual environment in ${venv_path}"
		return 1
	}

	# shellcheck disable=SC1091
	source "${venv_path}/bin/activate" || {
		_error 'failed to activate the virtual environment'
		return 1
	}

	(
		cd "${src_path}" || return
		sed -i -e '/^\[/d' yamllint.egg-info/requires.txt
		${python_command} \
			-m pip install \
			--quiet \
			--disable-pip-version-check \
			--requirement yamllint.egg-info/requires.txt
	) || {
		deactivate || true
		_error 'failed to install yamllint dependencies'
		return 1
	}

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

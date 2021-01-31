#!/bin/bash
set -e

for var_secrets in $(doppler secrets download --no-file --format env-no-quotes); do
  var_name=$(grep -o '^\w*' <<< $var_secrets)
  secret_value=$(grep -o '[^=]*$' <<< $var_secrets)

	# Escape percent signs and add a mask per line (see https://github.com/actions/runner/issues/161)
	escaped_mask_value=$(echo "$secret_value" | sed -e 's/%/%25/g')
	IFS=$'\n'
	for line in $escaped_mask_value; do
		echo "::add-mask::$line"
	done
	unset IFS

	# Use new environment file syntax on runners that support it.
	if [ -n "${GITHUB_ENV}" ]; then
		# A random 64 character string is used as the heredoc identifier, to make it practically
		# impossible that this string appears in the secret.
		random_heredoc_identifier=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n1)

		echo "$var_name<<${random_heredoc_identifier}" >> $GITHUB_ENV
		echo "$secret_value" >> $GITHUB_ENV
		echo "${random_heredoc_identifier}" >> $GITHUB_ENV
	else
		# Escape percent signs and newlines when setting the environment variable
		escaped_env_var_value=$(echo -n "$secret_value" | sed -z -e 's/%/%25/g' -e 's/\n/%0A/g')
		echo "::set-env name=$var_name::$escaped_env_var_value"
	fi
done

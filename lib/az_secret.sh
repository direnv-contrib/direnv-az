# use_az_secret: load Azure Key Vault secrets into the environment
#
#   use_az_secret my-vault/db-creds        JSON secret: one variable per key, uppercased
#                                          plain secret: one variable named after the secret
#   use_az_secret my-vault/db-creds@<id>   a specific version, the default is the latest
#   use_az_secret DB_URL=my-vault/db-url   the raw secret string with an explicit variable name
#
# The vault is the name of the Key Vault, not its URL.

# stdin: az keyvault secret JSON, $1: explicit variable name (optional)
# stdout: NUL-delimited name/value pairs
_az_secret_emit() {
  jq -j --arg name "$1" '
    def envname: ascii_upcase | gsub("[^A-Z0-9_]"; "_");
    .value as $s
    | if $name != "" then $name, "\u0000", $s, "\u0000"
      else ($s | try fromjson catch null) as $j
        | if ($j | type) == "object" then
            $j | to_entries[]
            | (.key | envname), "\u0000",
              (.value | if type == "string" then . else tojson end), "\u0000"
          else (.name | envname), "\u0000", $s, "\u0000"
          end
      end'
}

use_az_secret() {
  if [[ $# -eq 0 ]]; then
    log_error "use_az_secret: usage: use_az_secret [NAME=]vault/secret[@version] ..."
    return 1
  fi
  has az || { log_error "use_az_secret: az not found"; return 1; }
  has jq || { log_error "use_az_secret: jq not found"; return 1; }

  local arg name ref vault secret version json key value count=0
  for arg in "$@"; do
    name="" ref=$arg version=""
    if [[ $arg == *=* ]]; then
      name=${arg%%=*}
      ref=${arg#*=}
    fi
    if [[ $ref == *@* ]]; then
      version=${ref#*@}
      ref=${ref%%@*}
    fi
    vault=${ref%%/*}
    secret=${ref#*/}
    if [[ $ref != */* || -z $vault || -z $secret || $secret == */* ]] ||
      [[ $arg == *@* && -z $version ]]; then
      log_error "use_az_secret: invalid secret '$arg'"
      return 1
    fi

    json=$(az keyvault secret show --vault-name "$vault" --name "$secret" \
      ${version:+--version "$version"} --output json) || {
      log_error "use_az_secret: failed to read $vault/$secret"
      return 1
    }
    if ! jq -e '.value | strings' <<<"$json" >/dev/null; then
      log_error "use_az_secret: $vault/$secret has no string value"
      return 1
    fi

    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      if [[ ! $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        log_error "use_az_secret: invalid variable name '$key'"
        return 1
      fi
      export "$key=$value"
      ((count++))
    done < <(printf '%s' "$json" | _az_secret_emit "$name")
  done

  log_status "use_az_secret: loaded $count variable(s)"
}

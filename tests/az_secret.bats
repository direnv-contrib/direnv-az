#!/usr/bin/env bats

# Tests for lib/az_secret.sh (use_az_secret)
#
# Requires bats-core: https://github.com/bats-core/bats-core, direnv and jq
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

# ---------------------------------------------------------------------------
# Loading secrets
# ---------------------------------------------------------------------------

@test "a JSON secret exports one uppercased variable per key" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "{\"name\":\"db-creds\",\"value\":\"{\\\"username\\\":\\\"alice\\\",\\\"pass-word\\\":\\\"hunter2\\\",\\\"port\\\":5432}\"}"; }
    use_az_secret my-vault/db-creds
    echo "USERNAME=$USERNAME PASS_WORD=$PASS_WORD PORT=$PORT"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "USERNAME=alice PASS_WORD=hunter2 PORT=5432" ]]
}

@test "a plain secret is named after the secret" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "{\"name\":\"db-url\",\"value\":\"postgres://example/db\"}"; }
    use_az_secret my-vault/db-url
    echo "DB_URL=$DB_URL"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "DB_URL=postgres://example/db" ]]
}

@test "NAME=vault/secret exports the raw secret string under that name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "{\"name\":\"db-creds\",\"value\":\"{\\\"username\\\":\\\"alice\\\"}\"}"; }
    use_az_secret DB_CREDS=my-vault/db-creds
    echo "$DB_CREDS"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == '{"username":"alice"}' ]]
}

@test "several secrets can be loaded in one call" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() {
      case "$*" in
        *--name\ first*) echo "{\"name\":\"first\",\"value\":\"one\"}" ;;
        *--name\ second*) echo "{\"name\":\"second\",\"value\":\"two\"}" ;;
      esac
    }
    use_az_secret my-vault/first my-vault/second
    echo "FIRST=$FIRST SECOND=$SECOND"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "FIRST=one SECOND=two" ]]
}

@test "the vault and secret are passed to az, the latest version by default" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "args: $*" >&2; echo "{\"name\":\"my-secret\",\"value\":\"v\"}"; }
    use_az_secret my-vault/my-secret
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"args: keyvault secret show --vault-name my-vault --name my-secret --output json"* ]]
}

@test "secret@version reads that version" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "args: $*" >&2; echo "{\"name\":\"my-secret\",\"value\":\"v\"}"; }
    use_az_secret my-vault/my-secret@0123abcd
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"--name my-secret --version 0123abcd --output json"* ]]
}

@test "NAME=vault/secret@version combines an explicit name with a version" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "args: $*" >&2; echo "{\"name\":\"my-secret\",\"value\":\"pinned\"}"; }
    use_az_secret TOKEN=my-vault/my-secret@0123abcd
    echo "TOKEN=$TOKEN"
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"--vault-name my-vault --name my-secret --version 0123abcd"* ]]
  [[ "${lines[-1]}" == "TOKEN=pinned" ]]
}

@test "the status line reports how many variables were loaded" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "{\"name\":\"x\",\"value\":\"{\\\"a\\\":\\\"1\\\",\\\"b\\\":\\\"2\\\"}\"}"; }
    use_az_secret my-vault/x
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_az_secret: loaded 2 variable(s)"* ]]
}

# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_az_secret
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_az_secret [NAME=]vault/secret[@version]"* ]]
}

@test "fails when az is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    has() { [[ "$1" != "az" ]] && type "$1" &>/dev/null; }
    use_az_secret my-vault/db-url
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"az not found"* ]]
}

@test "fails when jq is not installed" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { :; }
    has() { [[ "$1" != "jq" ]] && type "$1" &>/dev/null; }
    use_az_secret my-vault/db-url
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"jq not found"* ]]
}

@test "fails when the secret cannot be read" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { return 1; }
    use_az_secret my-vault/missing
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"failed to read my-vault/missing"* ]]
}

@test "fails when the secret has no value" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "{\"name\":\"empty\",\"value\":null}"; }
    use_az_secret my-vault/empty
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"my-vault/empty has no string value"* ]]
}

@test "fails on a secret without a vault, or with an empty part" {
  local arg
  for arg in db-url /db-url my-vault/ NAME=db-url my-vault/a/b my-vault/db-url@ NAME=@2; do
    run bash -c '
      source "$TEST_HELPER"; load_libs
      az() { echo "{\"name\":\"n\",\"value\":\"v\"}"; }
      use_az_secret "$1"
    ' _ "$arg"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"invalid secret '$arg'"* ]]
  done
}

@test "fails on a key that is not a valid variable name" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    az() { echo "{\"name\":\"x\",\"value\":\"{\\\"1bad\\\":\\\"v\\\"}\"}"; }
    use_az_secret my-vault/x
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"invalid variable name '1BAD'"* ]]
}

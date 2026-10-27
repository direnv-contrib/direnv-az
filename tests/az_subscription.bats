#!/usr/bin/env bats

# Tests for lib/az_subscription.sh (use_az_subscription)
#
# Requires bats-core: https://github.com/bats-core/bats-core and direnv
# Run: bats tests/

export TEST_HELPER
TEST_HELPER="$BATS_TEST_DIRNAME/helper.bash"

@test "exports the subscription for the client libraries and Terraform" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AZURE_SUBSCRIPTION_ID ARM_SUBSCRIPTION_ID
    use_az_subscription 1111-aaaa
    echo "azure=$AZURE_SUBSCRIPTION_ID arm=$ARM_SUBSCRIPTION_ID"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "azure=1111-aaaa arm=1111-aaaa" ]]
}

@test "overrides a subscription that is already set" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    export AZURE_SUBSCRIPTION_ID="old-sub" ARM_SUBSCRIPTION_ID="old-sub"
    use_az_subscription new-sub
    echo "azure=$AZURE_SUBSCRIPTION_ID arm=$ARM_SUBSCRIPTION_ID"
  '
  [[ "$status" -eq 0 ]]
  [[ "${lines[-1]}" == "azure=new-sub arm=new-sub" ]]
}

@test "the status line names the subscription" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_az_subscription 1111-aaaa
  '
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"use_az_subscription: 1111-aaaa"* ]]
}

@test "no arguments prints the usage and fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_az_subscription
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_az_subscription subscription-id"* ]]
}

@test "an empty subscription id fails" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    use_az_subscription ""
  '
  [[ "$status" -eq 1 ]]
  [[ "$output" == *"usage: use_az_subscription subscription-id"* ]]
}

@test "more than one argument fails and sets nothing" {
  run bash -c '
    source "$TEST_HELPER"; load_libs
    unset AZURE_SUBSCRIPTION_ID ARM_SUBSCRIPTION_ID
    use_az_subscription one two
    echo "after=${AZURE_SUBSCRIPTION_ID:-unset}"
  '
  [[ "$output" == *"usage: use_az_subscription subscription-id"* ]]
  [[ "${lines[-1]}" == "after=unset" ]]
}

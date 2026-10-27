# use_az_subscription: select the Azure subscription for the client libraries and Terraform
#
#   use_az_subscription 00000000-0000-0000-0000-000000000000
#                                 sets AZURE_SUBSCRIPTION_ID (Azure SDKs, azd) and
#                                 ARM_SUBSCRIPTION_ID (Terraform, Pulumi), overriding the
#                                 default subscription of the az login

use_az_subscription() {
  if [[ $# -ne 1 || -z $1 ]]; then
    log_error "use_az_subscription: usage: use_az_subscription subscription-id"
    return 1
  fi

  export AZURE_SUBSCRIPTION_ID=$1
  export ARM_SUBSCRIPTION_ID=$1
  log_status "use_az_subscription: $1"
}

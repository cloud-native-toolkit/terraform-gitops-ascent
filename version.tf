terraform {
  required_version = ">= 0.15.0"

  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
      version = ">= 1.18.0"
    }
    gitops = {
      source  = "cloud-native-toolkit/gitops"
      version = ">= 0.1.7"
    }
  }
}

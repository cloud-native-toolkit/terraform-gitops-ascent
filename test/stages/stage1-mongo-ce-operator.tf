module "mongo-operator" {
  source = "github.com/cloud-native-toolkit/terraform-gitops-mongo-ce-operator"

  gitops_config = module.gitops.gitops_config
  git_credentials = module.gitops.git_credentials
  server_name = module.gitops.server_name
  namespace = module.gitops_namespace.name
  kubeseal_cert = module.gitops.sealed_secrets_cert
}


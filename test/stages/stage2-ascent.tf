module "gitops_module" {
  source = "./module"

  ibmcloud_api_key          = var.ibmcloud_api_key
  region                    = var.region
  platform                  = module.dev_cluster.platform
  server_url                = module.dev_cluster.server_url
  gitops_config             = module.gitops.gitops_config
  git_credentials           = module.gitops.git_credentials
  server_name               = module.gitops.server_name
  namespace                 = module.gitops_namespace.name
  kubeseal_cert             = module.gitops.sealed_secrets_cert
  cos_instance_id           = var.cos_instance_id
  cos_bucket_storage_class  = var.cos_bucket_storage_class
  cos_bucket_cross_region_location  = var.cos_bucket_cross_region_location
}

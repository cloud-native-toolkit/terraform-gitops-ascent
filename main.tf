locals {
  name          = "ascent"
  bin_dir       = module.setup_clis.bin_dir
  tmp_dir       = "${path.cwd}/.tmp/${local.name}"
  yaml_dir      = "${local.tmp_dir}/chart"
  secrets_dir   = "${local.tmp_dir}/secrets"
  ingress_host  = "ascent-ui-${var.namespace}.${var.platform.ingress}"
  service_url   = "http${var.platform.tls_secret != "" ? "s" : ""}://${local.ingress_host}"
  instance_id   = data.external.instance_id.result.token
  global = {
    ingressSubdomain = var.platform.ingress
    clusterType = "openshift"
  }
  bff_values    = {
    global = local.global
    replicaCount = 1
    logLevel = "debug"
    image = {
      repository = "quay.io/cloudnativetoolkit/ascent-bff"
      tag = "latest"
      pullPolicy = "IfNotPresent"
      port = 3001
    }
    nameOverride = ""
    fullnameOverride = ""
    service = {
      type = "ClusterIP"
      port = 80
    }
    route = {
      enabled = var.cluster_type == "openshift" ? true : false
    }
    ingress = {
      enabled = var.cluster_type == "openshift" ? false : true
      appid = {
        enabled = false
        requestType = "web"
      }
      namespaceInHost = true
      subdomain = "containers.appdomain.cloud"
      path = "/"
    }
    vcsInfo = {
      repoUrl = ""
      branch = ""
    }
    authentication = {
      provider = var.auth_strategy
    }
    partOf = "ascent"
    connectsTo = ""
    runtime = "js"
  }
  ui_values     = {
    tlsSecretName = var.platform.tls_secret
    global = local.global
    replicaCount = 1
    logLevel = "debug"
    image = {
      repository = "quay.io/cloudnativetoolkit/ascent-ui"
      tag = "latest"
      pullPolicy = "IfNotPresent"
      port = 3000
    }
    nameOverride = ""
    fullnameOverride = ""
    service = {
      type = "ClusterIP"
      port = 80
    }
    route = {
      enabled = var.cluster_type == "openshift" ? true : false
    }
    ingress = {
      enabled = var.cluster_type == "openshift" ? false : true
      appid = {
        enabled = false
        requestType = "web"
      }
      namespaceInHost = true
      subdomain = "containers.appdomain.cloud"
      path = "/"
    }
    vcsInfo = {
      repoUrl = ""
      branch = ""
    }
    authentication = {
      provider = var.auth_strategy
    }
    partOf = "ascent"
    connectsTo = "ascent-bff"
    runtime = "js"
  }
  layer = "applications"
  type  = "base"
  application_branch = "main"
  namespace = var.namespace
  layer_config = var.gitops_config[local.layer]
}

module setup_clis {
  source = "github.com/cloud-native-toolkit/terraform-util-clis.git"
}

# Credentials randomly created
data "external" "auth_token" {
  program = ["${path.module}/token.sh"]
}
data "external" "instance_id" {
  program = ["${path.module}/token.sh"]
}

# Create COS Bucket
resource "ibm_cos_bucket" "ascent_bucket" {
  depends_on=[data.external.instance_id]

  bucket_name          = "ascent-storage-${local.instance_id}"
  resource_instance_id = var.cos_instance_id
  region_location      = var.cos_bucket_cross_region_location
  storage_class        = var.cos_bucket_storage_class
}

resource null_resource create_yaml {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-yaml.sh '${local.name}' '${local.yaml_dir}' '${local.namespace}'"

    environment = {
      BFF_VALUES      = yamlencode(local.bff_values)
      UI_VALUES       = yamlencode(local.ui_values)
      SERVICE_URL     = local.service_url
      AUTH_STRATEGY   = var.auth_strategy
      AUTH_TOKEN      = data.external.auth_token.result.token
      INSTANCE_ID     = local.instance_id
    }
  }
}

resource null_resource create_secrets {
  depends_on = [null_resource.create_yaml]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-secrets.sh '${var.namespace}' '${local.secrets_dir}'"

    environment = {
      IBMCLOUD_API_KEY = var.ibmcloud_api_key
      SERVER_URL      = var.server_url
      AUTH_STRATEGY   = var.auth_strategy
      AUTH_TOKEN      = data.external.auth_token.result.token
      MONGO_HOSTNAME  = var.mongo_hostname
      MONGO_PORT      = var.mongo_port
      MONGO_USERNAME  = var.mongo_username
      MONGO_PASSWORD  = var.mongo_password
      INSTANCE_ID     = local.instance_id
      COS_INSTANCE_ID = ibm_cos_bucket.ascent_bucket.resource_instance_id
      COS_REGION      = ibm_cos_bucket.ascent_bucket.region_location
    }
  }
}

module seal_secrets {
  depends_on = [null_resource.create_secrets]

  source = "github.com/cloud-native-toolkit/terraform-util-seal-secrets.git?ref=v1.0.0"

  source_dir    = local.secrets_dir
  dest_dir      = "${local.yaml_dir}/secrets"
  kubeseal_cert = var.kubeseal_cert
  label         = local.name
}

resource gitops_module module {
  depends_on = [null_resource.create_yaml, module.seal_secrets]

  name        = local.name
  namespace   = var.namespace
  content_dir = local.yaml_dir
  server_name = var.server_name
  layer       = local.layer
  type        = local.type
  branch      = local.application_branch
  config      = yamlencode(var.gitops_config)
  credentials = yamlencode(var.git_credentials)
}

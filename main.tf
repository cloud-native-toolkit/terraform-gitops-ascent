locals {
  name          = "ascent"
  bin_dir       = module.setup_clis.bin_dir
  yaml_dir      = "${path.cwd}/.tmp/${local.name}/chart/${local.name}"
  ingress_host  = "ascent-ui-${var.namespace}.${var.platform.ingress}"
  service_url   = "http${var.platform.tls_secret != "" ? "s" : ""}://${local.ingress_host}"
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
      enabled = local.cluster_type == "openshift" ? true : false
    }
    ingress = {
      enabled = local.cluster_type == "openshift" ? false : true
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
      enabled = local.cluster_type == "openshift" ? true : false
    }
    ingress = {
      enabled = local.cluster_type == "openshift" ? false : true
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
  layer = "application"
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
data "external" "mongo_root_password" {
  program = ["${path.module}/token.sh"]
}
data "external" "instance_id" {
  program = ["${path.module}/token.sh"]
}

# Create COS Bucket
resource "ibm_cos_bucket" "ascent_bucket" {
  bucket_name          = "ascent-storage-${data.external.instance_id.result.token}"
  resource_instance_id = var.cos_instance_id
  region_location      = var.cos_bucket_cross_region_location
  storage_class        = var.cos_bucket_storage_class
}

resource null_resource create_yaml {
  provisioner "local-exec" {
    command = "${path.module}/scripts/create-yaml.sh '${local.name}' '${local.yaml_dir}' '${local.namespace}'"

    environment = {
      IBMCLOUD_API_KEY = var.ibmcloud_api_key
      BFF_VALUES      = yamlencode(local.bff_values)
      UI_VALUES       = yamlencode(local.ui_values)
      SERVER_URL      = var.server_url
      SERVICE_URL     = local.service_url
      AUTH_STRATEGY   = var.auth_strategy
      AUTH_TOKEN      = data.external.auth_token.result.token
      MONGO_HOSTNAME  = var.mongo_hostname
      MONGO_PORT      = var.mongo_port
      MONGO_USERNAME  = var.mongo_username
      MONGO_PASSWORD  = var.mongo_password
      INSTANCE_ID     = data.external.instance_id.result.token
      COS_INSTANCE_ID = ibm_cos_bucket.ascent_bucket.resource_instance_id
      COS_REGION      = ibm_cos_bucket.ascent_bucket.region_location
    }
  }
}

resource null_resource setup_gitops {
  depends_on = [null_resource.create_yaml]

  triggers = {
    name = local.name
    namespace = var.namespace
    yaml_dir = local.yaml_dir
    server_name = var.server_name
    layer = local.layer
    type = local.type
    git_credentials = yamlencode(var.git_credentials)
    gitops_config   = yamlencode(var.gitops_config)
    bin_dir = local.bin_dir
  }

  provisioner "local-exec" {
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "${self.triggers.bin_dir}/igc gitops-module '${self.triggers.name}' -n '${self.triggers.namespace}' --delete --contentDir '${self.triggers.yaml_dir}' --serverName '${self.triggers.server_name}' -l '${self.triggers.layer}' --type '${self.triggers.type}'"

    environment = {
      GIT_CREDENTIALS = nonsensitive(self.triggers.git_credentials)
      GITOPS_CONFIG   = self.triggers.gitops_config
    }
  }
}

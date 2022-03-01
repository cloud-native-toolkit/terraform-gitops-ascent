variable "ibmcloud_api_key" {
  type        = string
  description = "The IBM Cloud api token"
}

variable "gitops_config" {
  type = object({
    boostrap = object({
      argocd-config = object({
        project = string
        repo    = string
        url     = string
        path    = string
      })
    })
    infrastructure = object({
      argocd-config = object({
        project = string
        repo    = string
        url     = string
        path    = string
      })
      payload = object({
        repo = string
        url  = string
        path = string
      })
    })
    services = object({
      argocd-config = object({
        project = string
        repo    = string
        url     = string
        path    = string
      })
      payload = object({
        repo = string
        url  = string
        path = string
      })
    })
    applications = object({
      argocd-config = object({
        project = string
        repo    = string
        url     = string
        path    = string
      })
      payload = object({
        repo = string
        url  = string
        path = string
      })
    })
  })
  description = "Config information regarding the gitops repo structure"
}

variable "git_credentials" {
  type = list(object({
    repo     = string
    url      = string
    username = string
    token    = string
  }))
  description = "The credentials for the gitops repo(s)"
  sensitive   = true
}

variable "namespace" {
  type        = string
  description = "The namespace where the application should be deployed"
}

variable "kubeseal_cert" {
  type        = string
  description = "The certificate/public key used to encrypt the sealed secrets"
  default     = ""
}

variable "server_name" {
  type        = string
  description = "The name of the server"
  default     = "default"
}

variable "platform" {
  type = object({
    kubeconfig = string
    type       = string
    type_code  = string
    version    = string
    ingress    = string
    tls_secret = string
  })
  description = "Configuration values for the cluster platform"
}

variable "server_url" {
  type = string
  description = "The url of the control server"
}

variable "auth_strategy" {
  type = string
  description = "Ascent authentication strategy to be used: openshift | appid "
  default = "openshift"
}

variable "mongo_hostname" {
  type = string
  description = "Hostname of the Mongo instance"
}

variable "mongo_port" {
  type = string
  description = "Mongo port"
}

variable "mongo_username" {
  type = string
  description = "Mongo admin user"
}

variable "mongo_password" {
  type = string
  description = "Mongo admin password"
}

variable "cos_instance_id" {
  type        = string
  description = "The Object Storage instance id"
}

variable "cos_bucket_cross_region_location" {
  type        = string
  description = "Cross-regional bucket location. Supported values are: us | eu | ap"
  default     = "eu"
}

variable "cos_bucket_storage_class" {
  type        = string
  description = "The storage class that you want to use for the bucket. Supported values are standard, vault, cold, flex, and smart."
  default     = "standard"
}

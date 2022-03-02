#!/usr/bin/env bash

NAMESPACE="$1"
DEST_DIR="$2"

mkdir -p "${DEST_DIR}"

# Authentication Config
if [[ -n $AUTH_STRATEGY && $AUTH_STRATEGY == 'openshift-oauth' ]]; then
  # Create OAuth secret
  kubectl create secret generic ascent-oauth-config \
    -n ${NAMESPACE} \
    --from-literal=api-url=${SERVER_URL} \
    --from-literal=oauth-config=$(echo "{\"clientID\": \"ascent\", \"clientSecret\": \"${AUTH_TOKEN}\", \"api_endpoint\": \"${SERVER_URL}\"}") \
    --dry-run=client \
    --output=yaml > "${DEST_DIR}/ascent-oauth-config.yaml"
elif [[ -n $AUTH_STRATEGY && $AUTH_STRATEGY == 'appid' ]]; then
  echo 'AppID auth not yet implemented'
  exit 1
else
  echo "Supported authentication strategy: openshift-oauth | appid"
  echo "Found: $AUTH_STRATEGY"
  exit 1
fi

# Create MongoDB secret
kubectl create secret generic ascent-mongo-config \
  -n ${NAMESPACE} \
  --from-literal=binding=$(echo "{\"connection\":{\"mongodb\":{\"composed\":[\"mongodb://${MONGO_USERNAME}:${MONGO_PASSWORD}@${MONGO_HOSTNAME}:${MONGO_PORT}/ascent-db\"],\"authentication\":{\"username\":\"${MONGO_USERNAME}\",\"password\":\"${MONGO_PASSWORD}\"},\"database\":\"ascent-db\",\"hosts\":[{\"hostname\":\"${MONGO_HOSTNAME}\",\"port\":${MONGO_PORT}}}]}}}") \
  --dry-run=client \
  --output=yaml > "${DEST_DIR}/ascent-mongo-config.yaml"

# Create IBM Cloud Object Storage secret
ibmcloud login --apikey ${IBMCLOUD_API_KEY}
COS_CREDENTIALS=$(ibmcloud resource service-key-create ascent-${INSTANCE_ID} Manager --instance-id ${COS_INSTANCE_ID} --output JSON | jq .credentials | jq ". |= . + {\"endpoints\": \"s3.${COS_REGION}.cloud-object-storage.appdomain.cloud\"}")
kubectl create secret generic ascent-cos-config \
  -n ${NAMESPACE} \
  --from-literal=apikey=$(echo $COS_CREDENTIALS | jq -r .apikey) \
  --from-literal=binding=$(echo $COS_CREDENTIALS) \
  --from-literal=endpoints=$(echo $COS_CREDENTIALS | jq -r .endpoints) \
  --from-literal=iam_apikey_description=$(echo $COS_CREDENTIALS | jq -r .iam_apikey_description) \
  --from-literal=iam_apikey_name=$(echo $COS_CREDENTIALS | jq -r .iam_apikey_name) \
  --from-literal=iam_role_crn=$(echo $COS_CREDENTIALS | jq -r .iam_role_crn) \
  --from-literal=iam_serviceid_crn=$(echo $COS_CREDENTIALS | jq -r .iam_serviceid_crn) \
  --from-literal=resource_instance_id=$(echo $COS_CREDENTIALS | jq -r .resource_instance_id) \
  --dry-run=client \
  --output=yaml > "${DEST_DIR}/ascent-cos-config.yaml"

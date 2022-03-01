#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAME="$1"
DEST_DIR="$2"
NAMESPACE="$3"

find "${DEST_DIR}" -name "*"

cp -R ${MODULE_DIR}/chart/* ${DEST_DIR}
if [[ -n "${BFF_VALUES}" ]]; then
  echo "${BFF_VALUES}" > "${DEST_DIR}/ascent-bff/values.yaml"
fi
if [[ -n "${UI_VALUES}" ]]; then
  echo "${UI_VALUES}" > "${DEST_DIR}/ascent-ui/values.yaml"
fi

# Authentication Config

if [[ -n $AUTH_STRATEGY && $AUTH_STRATEGY == 'openshift-oauth' ]]; then

# Create OpenShift OAuth Client
cat > "${DEST_DIR}/ascent-oauth-client.yaml" <<EOF
apiVersion: oauth.openshift.io/v1
grantMethod: auto
kind: OAuthClient
metadata:
  namespace: ${NAMESPACE}
  name: ascent
  selfLink: /apis/oauth.openshift.io/v1/oauthclients/ascent
redirectURIs:
- ${SERVICE_URL}/login/callback
secret: ${AUTH_TOKEN}
EOF

# Create OAuth Secret for ascent to use
cat > "${DEST_DIR}/ascent-oauth-config-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ascent-oauth-config
  namespace: ${NAMESPACE}
type: Opaque 
data: 
  api-url: $(echo ${SERVER_URL} | base64) 
  oauth-config: $(echo "{\"clientID\": \"ascent\", \"clientSecret\": \"${AUTH_TOKEN}\", \"api_endpoint\": \"${SERVER_URL}\"}" | base64)
EOF

elif [[ -n $AUTH_STRATEGY && $AUTH_STRATEGY == 'appid' ]]; then

echo 'AppID auth not yet implemented'
exit 1

else

echo "Supported authentication strategy: openshift-oauth | appid"
echo "Found: $AUTH_STRATEGY"
exit 1

fi

# MongoDB Config

cat > "${DEST_DIR}/ascent-mongo-config-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ascent-mongo-config
  namespace: ${NAMESPACE}
type: Opaque 
data: 
  binding: $(echo "{\"connection\":{\"mongodb\":{\"composed\":[\"mongodb://${MONGO_USERNAME}:${MONGO_PASSWORD}@${MONGO_HOSTNAME}:${MONGO_PORT}/ascent-db\"],\"authentication\":{\"username\":\"${MONGO_USERNAME}\",\"password\":\"${MONGO_PASSWORD}\"},\"database\":\"ascent-db\",\"hosts\":[{\"hostname\":\"${MONGO_HOSTNAME}\",\"port\":${MONGO_PORT}}}]}}}" | base64)
EOF

# Ascent ConfigMap

cat > "${DEST_DIR}/ascent-configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ascent
  namespace: ${NAMESPACE}
data:
  api-host: http://ascent-bff
  instance-id: ${INSTANCE_ID}
  route: ${SERVICE_URL}
EOF

# IBM Cloud Object Storage Config

ibmcloud login --apikey ${IBMCLOUD_API_KEY}
COS_CREDENTIALS=$(ibmcloud resource service-key-create ascent-${INSTANCE_ID} Manager --instance-id ${COS_INSTANCE_ID} --output JSON | jq .credentials | jq ". |= . + {\"endpoints\": \"s3.${COS_REGION}.cloud-object-storage.appdomain.cloud\"}")
cat > "${DEST_DIR}/ascent-cos-config-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ascent-cos-config
  namespace: mapper-staging
type: Opaque
data:
  apikey: $(echo $COS_CREDENTIALS | jq -r .apikey | base64)
  binding: $(echo $COS_CREDENTIALS | base64)
  endpoints: $(echo $COS_CREDENTIALS | jq -r .endpoints | base64)
  iam_apikey_description: $(echo $COS_CREDENTIALS | jq -r .iam_apikey_description | base64)
  iam_apikey_name: $(echo $COS_CREDENTIALS | jq -r .iam_apikey_name | base64)
  iam_role_crn: $(echo $COS_CREDENTIALS | jq -r .iam_role_crn | base64)
  iam_serviceid_crn: $(echo $COS_CREDENTIALS | jq -r .iam_serviceid_crn | base64)
  resource_instance_id: $(echo $COS_CREDENTIALS | jq -r .resource_instance_id | base64)
EOF

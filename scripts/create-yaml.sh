#!/usr/bin/env bash

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)
MODULE_DIR=$(cd "${SCRIPT_DIR}/.."; pwd -P)

NAME="$1"
DEST_DIR="$2"
NAMESPACE="$3"

mkdir -p "${DEST_DIR}"/ascent-config

cp -R ${MODULE_DIR}/chart/* ${DEST_DIR}
if [[ -n "${BFF_VALUES}" ]]; then
  echo "${BFF_VALUES}" > "${DEST_DIR}/ascent-bff/values.yaml"
fi
if [[ -n "${UI_VALUES}" ]]; then
  echo "${UI_VALUES}" > "${DEST_DIR}/ascent-ui/values.yaml"
fi
if [[ -n "${MONGODB_VALUES}" ]]; then
  echo "${MONGODB_VALUES}" > "${DEST_DIR}/ascent-mongodb/values.yaml"
fi

# Authentication Config

if [[ -n $AUTH_STRATEGY && $AUTH_STRATEGY == 'openshift' ]]; then

# Create OpenShift OAuth Client
cat > "${DEST_DIR}/ascent-config/ascent-oauth-client.yaml" <<EOF
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

elif [[ -n $AUTH_STRATEGY && $AUTH_STRATEGY == 'appid' ]]; then

echo 'AppID auth not yet implemented'
exit 1

else

echo "Supported authentication strategy: openshift | appid"
echo "Found: $AUTH_STRATEGY"
exit 1

fi

# Ascent ConfigMap
cat > "${DEST_DIR}/ascent-config/ascent-configmap.yaml" <<EOF
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

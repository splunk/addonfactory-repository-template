### Common script to create namespace and service account for addon

# Export addon specific variables
export ADDON_NAME=$(echo $REPO | sed -r 's/splunk-add-on-for-//g')
export ADDON_ROLE="$ADDON_NAME-role"
export ADDON_ROLE_BINDING="$ADDON_NAME-binding"
export SERVICE_ACCOUNT="$ADDON_NAME-account"
export ISTIO_ROLE="istio-service-read-role"
export ISTIO_ROLE_BINDING="$ADDON_NAME-istio-svc-read"
export PROXY_NAMESPACE="proxy-namespace"
export PROXY_ROLE="proxy-role"
export PROXY_ROLE_BINDING="$ADDON_NAME-proxy-bind"

# Create namespace
envsubst < eks/addon-namespace.yaml | kubectl apply -f -

# Enable istio proxy injection for namespace
kubectl label namespace $REPO istio-injection=enabled

# Create role for namespace
envsubst < eks/addon-role.yaml | kubectl apply -f -

# Create service account
envsubst < eks/addon-serviceaccount.yaml | kubectl apply -f -

# Create role binding between addon role and service account
envsubst < eks/addon-rolebinding.yaml | kubectl apply -f -

# Role to read serivce in istio-system namespace
envsubst < eks/istio-role.yaml | kubectl apply -f - 

# Create role binding between istio service real role and service account
envsubst < eks/istio-rolebinding.yaml | kubectl apply -f -

# Create namespace for porxy servers
envsubst < eks/proxy-namespace.yaml | kubectl apply -f -

# Create proxy role for proxy-namespace namespace
envsubst < eks/proxy-role.yaml | kubectl apply -f - 

# Create role binding between proxy-namespace and service account
envsubst < eks/proxy-rolebinding.yaml | kubectl apply -f -

# Create virtual gateway for namepspace
envsubst < eks/addon-virtualgateway.yaml | kubectl apply -f -

# Get service account token
export SA_TOKEN=$(kubectl get secret $(kubectl get sa $SERVICE_ACCOUNT -n $REPO -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' -n $REPO | base64 -d) 

# Set cluster_endpoint, cluster_certificate, sa_token in environment of addon repo

curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"CLUSTER_ENDPOINT\", \"value\":\"${CLUSTER_ENDPOINT}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"CLUSTER_CERTIFICATE\", \"value\":\"${CLUSTER_CERTIFICATE}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"SA_TOKEN\", \"value\":\"${SA_TOKEN}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}

# Set aws creds for route53 access in addon repo(this account has only access to route53)
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"AWS_ACCESS_KEY_ID\", \"value\":\"${AWS_ACCESS_KEY_ID_ROUTE53}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"AWS_SECRET_ACCESS_KEY\", \"value\":\"${AWS_SECRET_ACCESS_KEY_ROUTE53}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}

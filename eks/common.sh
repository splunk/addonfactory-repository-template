### COMMON SCRIPT TO CREATE NAMESPACE AND SERVICE ACCOUNT FOR ADDON

# AWS_ACCESS_KEY_ID AND AWS_SECRET_ACCESS_KEY SHOULD BE IN ENVIRONMENT VARIABLES
# INSTALL AWS-CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# INSTALL KUBECTL
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl

# CLUSTER VARIABLES
export CLUSTER_NAME="addonfactory-automation-cluster"
export CLUSTER_REGION="us-east-1"
export CLUSTER_ENDPOINT=$(aws eks describe-cluster --name $CLUSTER_NAME --region $CLUSTER_REGION | jq -r ".cluster.endpoint")
export CLUSTER_CERTIFICATE=$(aws eks describe-cluster --name $CLUSTER_NAME --region $CLUSTER_REGION | jq -r ".cluster.certificateAuthority.data")

# UPDATE KUBE CONFIG
rm -rf ~/.kube
aws eks update-kubeconfig --name $CLUSTER_NAME --region $CLUSTER_REGION

# EXPORT ADDON SPECIFIC VARIABLES
export ADDON_NAME=$(echo $REPO | sed -r 's/splunk-add-on-for-//g')
export ROLE_NAME="$ADDON_NAME-role"
export SERVICE_ACCOUNT="$ADDON_NAME-account"
export ROLE_BINDING_NAME="$ADDON_NAME-binding"
export ROLE_NAME_ISTIO="istio-service-read-role"
export ROLE_NAME_PROXY="proxy-role"

# CREATE NAMESPACE
envsubst < eks/namespace.yaml | kubectl apply -f -

# ENABLE PROXY INJECTION FOR NAMESPACE
kubectl label namespace $REPO istio-injection=enabled

# CREATE ROLE FOR NAMESPACE
envsubst < eks/role.yaml | kubectl apply -f -

# CREATE SERVICE ACCOUNT
envsubst < eks/service-account.yaml | kubectl apply -f -

# CREATE ROLE BINDING
envsubst < eks/role-binding.yaml | kubectl apply -f -

# CREATE/UPDATE READ SERIVCE ROLE FOR istio-system NAMESPACE
envsubst < eks/role-istio.yaml | kubectl apply -f - 

# CREATE ROLE BINDING TO FOR istio-system NAMESPACE
envsubst < eks/role-binding-istio.yaml | kubectl apply -f -

# CREATE PROXY ROLE FOR proxy-namespace NAMESPACE
envsubst < eks/role-proxy.yaml | kubectl apply -f - 

# CREATE ROLE BINDING TO FOR proxy-namespace NAMESPACE
envsubst < eks/role-binding-proxy.yaml | kubectl apply -f -

# CREATE GATEWAY FOR NAMEPSPACE
envsubst < eks/virtual-gateway.yaml | kubectl apply -f -

# GET SERVICE ACCOUNT TOKEN
export SA_TOKEN=$(kubectl get secret $(kubectl get sa $SERVICE_ACCOUNT -n $REPO -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' -n $REPO | base64 -d) 

# SET CLUSTER_ENDPOINT, CLUSTER_CERTIFICATE, SA_TOKEN IN ENVIRONMENT OF ADDON

curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"CLUSTER_ENDPOINT\", \"value\":\"${CLUSTER_ENDPOINT}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"CLUSTER_CERTIFICATE\", \"value\":\"${CLUSTER_CERTIFICATE}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"SA_TOKEN\", \"value\":\"${SA_TOKEN}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}

# SET AWS CREDS FOR ROUTE53 ACCESS(THIS ACCOUNT HAS ONLY ACCESS TO ROUTE53)
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"AWS_ACCESS_KEY_ID\", \"value\":\"${AWS_ACCESS_KEY_ID_ROUTE53}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}
curl -X POST --header "Content-Type: application/json" -d "{\"name\":\"AWS_SECRET_ACCESS_KEY\", \"value\":\"${AWS_SECRET_ACCESS_KEY_ROUTE53}\"}" https://circleci.com/api/v1.1/project/github/$REPOORG/$REPO/envvar?circle-token=${CIRCLECI_TOKEN}

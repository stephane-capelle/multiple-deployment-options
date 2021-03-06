#!/bin/bash
cd service

if [ -z "$BLUEMIX_API_KEY" ]; then
  echo 'No Bluemix API key specified in the pipeline. Skipping Kubernetes deployment.'
  exit 0
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo 'No existing cluster name specified in the pipeline. Skipping Kubernetes deployment.'
  exit 0
fi

if [ -f "image.env" ]; then
  echo 'Loading image name from image.env file.'
  source image.env
fi

if [ -z "$IMAGE_NAME" ]; then
  echo 'No Docker image specified.'
  exit 1
fi

################################################################
# Install dependencies
################################################################
echo 'Installing dependencies...'
sudo apt-get -qq update 1>/dev/null
sudo apt-get -qq install jq 1>/dev/null
sudo apt-get -qq install figlet 1>/dev/null

figlet -f small 'Bluemix CLI'

wget --quiet --output-document=/tmp/Bluemix_CLI_amd64.tar.gz  http://public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/latest/Bluemix_CLI_amd64.tar.gz
tar -xf /tmp/Bluemix_CLI_amd64.tar.gz --directory=/tmp

# Create bx alias
echo "#!/bin/sh" >/tmp/Bluemix_CLI/bin/bx
echo "/tmp/Bluemix_CLI/bin/bluemix \"\$@\" " >>/tmp/Bluemix_CLI/bin/bx
chmod +x /tmp/Bluemix_CLI/bin/*

export PATH="/tmp/Bluemix_CLI/bin:$PATH"

figlet -f small 'Container Service'
bx plugin install container-service -r Bluemix

figlet -f small 'kubectl'
wget --quiet --output-document=/tmp/Bluemix_CLI/bin/kubectl  https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x /tmp/Bluemix_CLI/bin/kubectl

bx --version
bx plugin list

figlet 'Logging in Bluemix'

bx login -a "$CF_TARGET_URL" --apikey "$BLUEMIX_API_KEY" -o "$CF_ORG" -s "$CF_SPACE"
if [ $? -ne 0 ]; then
  echo 'Failed to authenticate to Bluemix'
  exit 1
fi

# Init container clusters
echo "bx cs init"
bx cs init
if [ $? -ne 0 ]; then
  echo 'Failed to initialize to Bluemix Container Service'
  exit 1
fi

################################################################
# Deploy
################################################################
figlet 'Fibonacci Deployment'

# The cluster must be ready for us to continue
CLUSTER_STATE=$(bx cs workers $CLUSTER_NAME | grep -m1 Ready | awk '{ print $6 }')
if [ "$CLUSTER_STATE" != "Ready" ]
then
  echo "Cluster is not in a Ready state (current state is $CLUSTER_STATE). Re-run this stage once the cluster is Ready."
  exit 1
fi

# Setting up config files
echo -e 'Setting KUBECONFIG...'
exp=$(bx cs cluster-config $CLUSTER_NAME | grep export)
if [ $? -ne 0 ]; then
  echo "There is an issue with your existing cluster: $CLUSTER_NAME"
  bx cs workers $CLUSTER_NAME
  echo "Run the job again once the Cluster is at Ready state"
  exit 1
fi
eval "$exp"

# Generate a tmp deployment file where the image name has been replaced by the actual image to use
echo "Using Docker image $IMAGE_NAME"
ESCAPED_IMAGE_NAME=$(echo $IMAGE_NAME | sed 's/\//\\\//g')
cat fibonacci-deployment.yml | sed 's/registry.ng.bluemix.net\/<namespace>\/fibonacci:latest/'$ESCAPED_IMAGE_NAME'/g' > tmp-fibonacci-deployment.yml

echo -e 'Deleting previous version of Fibonacci service...'
kubectl delete --ignore-not-found=true -f tmp-fibonacci-deployment.yml

echo -e 'Deploying Fibonacci service...'
kubectl create -f tmp-fibonacci-deployment.yml

IP_ADDR=$(bx cs workers $CLUSTER_NAME | grep -m1 Ready | awk '{ print $2 }')
if [ -z $IP_ADDR ]; then
  echo "$CLUSTER_NAME not created or workers not ready"
  exit 1
fi

PORT=$(kubectl get services | grep fibonacci-service | sed 's/.*://g' | sed 's/\/.*//g')

echo "Fibonacci service available at http://$IP_ADDR:$PORT"

#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/.reporc

#################################################################################
# Configuration Data
#################################################################################

#This can be updated to use any string which will guarantee global uniqueness across your region (username, favorite cat, etc.)
SERVICE_SUFFIX=${RANDOM}

# The domain associated with your Bluemix region
DOMAIN="mybluemix.net"
#DOMAIN="eu-gb.mybluemix.net"
#DOMAIN="au-syd.mybluemix.net"

BLUEMIX_REGISTRY_HOST=registry.ng.bluemix.net
#BLUEMIX_REGISTRY_HOST=registry.eu-gb.bluemix.net
#BLUEMIX_REGISTRY_HOST=registry.au-syd.bluemix.net

cf ic init
NAMESPACE=$(cf ic namespace get)

#################################################################################
# Deployment Code
#################################################################################

#Build all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${REQUIRED_REPOS[@]}; do

  #PROJECT=$(echo ${REPO} | cut -d/ -f5 | cut -d. -f1)
  echo -e "\nStarting ${REPO} project"

  cd ../${REPO}

  #Remove the 'microservices-refapp-' prefix from the image names
  IMAGE_NAME=${REPO#refarch-cloudnative-}

  # Create the route ahead of time to control access
  CURRENT_SPACE=$(cf target | grep "Space:" | awk '{print $2}')
  SERVICE_ROUTE="${IMAGE_NAME}-${SERVICE_SUFFIX}"

  cf create-route ${CURRENT_SPACE} ${DOMAIN} --hostname ${SERVICE_ROUTE}

  echo -e "\nTagging and pushing ${IMAGE_NAME}"
  docker tag ${IMAGE_NAME}:latest ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}:latest
  docker push ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}:latest

  echo -e "\nCreating ${IMAGE_NAME} container group"
  # Push application code
  if [[ ${IMAGE_NAME} == *"netflix-eureka"* ]]; then
    # Push Eureka application code
    cf ic group create \
      --name ${IMAGE_NAME}-group \
      --publish 8761 --memory 256 --auto \
      --min 1 --max 2 --desired 1 \
      --hostname ${SERVICE_ROUTE} \
      --domain ${DOMAIN} \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}
    RUN_RESULT=$?

    EUREKA_ENDPOINT="http://${SERVICE_ROUTE}.${DOMAIN}/eureka/"

  elif [[ ${IMAGE_NAME} == *"spring-config"* ]]; then
    # Push Config Server application code, leveraging metadata from manifest.yml
    cf ic group create \
      --name ${IMAGE_NAME}-group \
      --publish 8080 --memory 128 --auto \
      --min 1 --max 2 --desired 1 \
      --hostname ${SERVICE_ROUTE} \
      --domain ${DOMAIN} \
      --env "server_port=8080" \
      --env "eureka_client_serviceUrl_defaultZone=${EUREKA_ENDPOINT}" \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}
    RUN_RESULT=$?

    CONFIG_ENDPOINT="http://${SERVICE_ROUTE}.${DOMAIN}"

  else
    # Push microservice component code, leveraging metadata from manifest.yml
    cf ic group create \
      --name ${IMAGE_NAME}-group \
      --publish 8080 --memory 128 --auto \
      --min 1 --max 2 --desired 1 \
      --hostname ${SERVICE_ROUTE} \
      --domain ${DOMAIN} \
      --env "server_port=8080" \
      --env "eureka_client_serviceUrl_defaultZone=${EUREKA_ENDPOINT}" \
      --env "spring_cloud_config_uri=${CONFIG_ENDPOINT}" \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}
    RUN_RESULT=$?
  fi

  if [ ${RUN_RESULT} -ne 0 ]; then
    echo ${REPO}" failed to start successfully.  Check logs in the local project directory for more details."
    exit 1
  fi
  cd $SCRIPTDIR
done

cf ic group ls

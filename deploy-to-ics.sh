#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/.reporc

#################################################################################
# Configuration Data
#################################################################################

#This can be updated to use any string which will guarantee global uniqueness across your region (username, favorite cat, etc.)
UNIQUE_IDENTIFIER=${1:-RANDOM}

# The domain associated with your Bluemix region
DOMAIN="mybluemix.net"
#DOMAIN="eu-gb.mybluemix.net"
#DOMAIN="au-syd.mybluemix.net"

BLUEMIX_REGISTRY_HOST=registry.ng.bluemix.net
#BLUEMIX_REGISTRY_HOST=registry.eu-gb.bluemix.net
#BLUEMIX_REGISTRY_HOST=registry.au-syd.bluemix.net

#The name of the CloudAMQP Bluemix Service for hystrix integration.
CLOUDAMQP_SERVICE="cloudamqp-wfd-resiliency"

#The name of the user-provided-service we will create to connect to Service Discovery servers
SERVICE_DISCOVERY_UPS="eureka-service-discovery"
#The name of the user-provided-service we will create to connect to Config servers
CONFIG_SERVER_UPS="config-server"
#The name of the user-provided-service we will create to connect to zipkin
ZIPKIN_SERVER_UPS="zipkin-server"
#The name of the container bridge app used for binding services to containers
BRIDGE_APP="container-bridge-app"

cf ic init
NAMESPACE=$(cf ic namespace get)


#################################################################################
# Create integration services
#################################################################################

# Deploy Container Bridge App
touch empty_file.txt
cf push ${BRIDGE_APP} -p . -i 1 -d ${DOMAIN} -k 1M -m 64M --no-hostname --no-manifest --no-route --no-start

# Create new CloudAMQP Service
cf create-service cloudamqp lemur ${CLOUDAMQP_SERVICE}
cf bind-service ${BRIDGE_APP} ${CLOUDAMQP_SERVICE}

#################################################################################
# Deployment Code
#################################################################################

#Build all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${IC_REQUIRED_REPOS[@]}; do

  #PROJECT=$(echo ${REPO} | cut -d/ -f5 | cut -d. -f1)
  echo -e "\nStarting ${REPO} project"

  cd ../${REPO}

  #Remove the 'microservices-refapp-' prefix from the image names
  IMAGE_NAME=${REPO#refarch-cloudnative-}

  # Create the route ahead of time to control access
  #CURRENT_SPACE=$(cf target | grep "Space:" | awk '{print $2}')

  #cf create-route ${CURRENT_SPACE} ${DOMAIN} --hostname ${SERVICE_ROUTE}

  echo -e "\nTagging and pushing ${IMAGE_NAME}"
  docker tag ${IMAGE_NAME}:latest ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}-${UNIQUE_IDENTIFIER}:latest
  docker push ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}-${UNIQUE_IDENTIFIER}:latest

  echo -e "\nCreating ${IMAGE_NAME} container group"
  # Push application code
  if [[ ${IMAGE_NAME} == *"netflix-eureka"* ]]; then
    # Push Eureka application code
    cf ic group create \
      --name ${IMAGE_NAME}-${UNIQUE_IDENTIFIER} \
      --publish 8761 --memory 256 --auto \
      --min 1 --max 2 --desired 1 \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}-${UNIQUE_IDENTIFIER}
    RUN_RESULT=$?

    # Create Eureka CUPS
    EUREKA_CONTAINER_GR_ID=`cf ic group list | grep ${IMAGE_NAME}-${UNIQUE_IDENTIFIER} | sed 's/ .*$//g'`
    while [[ -z $EUREKA_CONTAINER_GR_IP ]]
    do
      sleep 5
      EUREKA_CONTAINER_GR_IP=`cf ic group inspect $EUREKA_CONTAINER_GR_ID | grep private_ip_address | sed 's/.*: "\(.*\)".*$/\1/g'`
    done
    cf create-user-provided-service ${SERVICE_DISCOVERY_UPS} -p "{\"uri\": \"http://${EUREKA_CONTAINER_GR_IP}:8761/eureka/\"}"
    # Bind CUPS
    cf bind-service ${BRIDGE_APP} ${SERVICE_DISCOVERY_UPS}

  elif [[ ${IMAGE_NAME} == *"spring-config"* ]]; then
    # Push Config Server application code, leveraging metadata from manifest.yml
    cf ic group create \
      --name ${IMAGE_NAME}-${UNIQUE_IDENTIFIER} \
      --publish 8888 --memory 128 --auto \
      --min 1 --max 2 --desired 1 \
      --env CCS_BIND_APP=${BRIDGE_APP} \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}-${UNIQUE_IDENTIFIER}
    RUN_RESULT=$?

    # Create the Config Server CUPS
    CS_CONTAINER_GR_ID=`cf ic group list | grep ${IMAGE_NAME}-${UNIQUE_IDENTIFIER} | sed 's/ .*$//g'`
    while [[ -z $CS_CONTAINER_GR_IP ]]
    do
      sleep 5
      CS_CONTAINER_GR_IP=`cf ic group inspect $CS_CONTAINER_GR_ID | grep private_ip_address | sed 's/.*: "\(.*\)".*$/\1/g'`
    done
    cf create-user-provided-service ${CONFIG_SERVER_UPS} -p "{\"uri\": \"http://${CS_CONTAINER_GR_IP}:8888/\"}"
    # Bind CUPS
    cf bind-service ${BRIDGE_APP} ${CONFIG_SERVER_UPS}
  elif [[ ${IMAGE_NAME} == *"hystrix"* ]]; then
    IP_ADDRESS=`bluemix ic ips -q | head -n1`
    cf ic run \
      --name ${IMAGE_NAME}-${UNIQUE_IDENTIFIER} \
      --publish ${IP_ADDRESS}:8383:8383 \
      --memory 128 \
      --env CCS_BIND_APP=${BRIDGE_APP} \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}-${UNIQUE_IDENTIFIER}

  elif [[ ${IMAGE_NAME} == *"turbine"* ]]; then
    cf ic run \
      --name ${IMAGE_NAME}-${UNIQUE_IDENTIFIER} \
      --publish 8989:8989 --publish 8990:8990 \
      --memory 128 \
      --env CCS_BIND_APP=${BRIDGE_APP} \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}-${UNIQUE_IDENTIFIER}

  else
    # Push microservice component code, leveraging metadata from manifest.yml
    PORT=`cat docker/Dockerfile | grep EXPOSE | awk '{print $2}'`
    cf ic group create \
      --name ${IMAGE_NAME}-${UNIQUE_IDENTIFIER} \
      --publish ${PORT} --memory 128 --auto \
      --min 1 --max 2 --desired 1 \
      --env CCS_BIND_APP=${BRIDGE_APP} \
      ${BLUEMIX_REGISTRY_HOST}/${NAMESPACE}/${IMAGE_NAME}-${UNIQUE_IDENTIFIER}
    RUN_RESULT=$?
    if [[ ${IMAGE_NAME} == *"zuul"* ]]; then
      cf ic route map -d ${DOMAIN} -n "wfd-menu-ic-version-${UNIQUE_IDENTIFIER}" ${IMAGE_NAME}-${UNIQUE_IDENTIFIER}
    fi
  fi

  if [ ${RUN_RESULT} -ne 0 ]; then
    echo ${REPO}" failed to start successfully. Check logs in the local project directory for more details."
    exit 1
  fi
  cd $SCRIPTDIR
done

cf ic group ls
echo
echo
cf ic ps

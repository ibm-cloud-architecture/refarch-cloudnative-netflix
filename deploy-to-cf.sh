#!/bin/bash

####
####TODO:
####

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#################################################################################
# Configuration Data
#################################################################################

#This can be updated to use any string which will guarantee global uniqueness across your region (username, favorite cat, etc.)
SERVICE_SUFFIX=${RANDOM}

#The name of the user-provided-service we will create to connect to Service Discovery servers
SERVICE_DISCOVERY_UPS="eureka-service-discovery"

# The domain associated with your Bluemix region
DOMAIN="mybluemix.net"
#DOMAIN="eu-gb.mybluemix.net"
#DOMAIN="au-syd.mybluemix.net"

#IBM Cloud Architecture GitHub Repository.  This should be changed for forked repositories.
GITHUB_ORG="ibm-cloud-architecture"

#All required repositories
REQUIRED_REPOS=(
    https://github.com/${GITHUB_ORG}/microservices-netflix-eureka.git
    https://github.com/${GITHUB_ORG}/microservices-netflix-zuul.git
    https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-appetizer.git
    #https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-entree.git
    #https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-dessert.git
    #https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-menu.git
)

#################################################################################
# Deployment Code
#################################################################################

#Build all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${REQUIRED_REPOS[@]}; do

  PROJECT=$(echo ${REPO} | cut -d/ -f5 | cut -d. -f1)
  echo -e "\nStarting ${PROJECT} project"

  cd ../${PROJECT}

  # Determein which JAR file we should use (since we have both Gradle and Maven possibilities)
  RUNNABLE_JAR="$(find . -name "*-SNAPSHOT.jar" | sed -n 1p)"

  # Create the route ahead of time to control access
  CURRENT_SPACE=$(cf target | grep "Space:" | awk '{print $2}')
  SERVICE_ROUTE="${PROJECT}-${SERVICE_SUFFIX}"

  cf create-route ${CURRENT_SPACE} ${DOMAIN} --hostname ${SERVICE_ROUTE}

  # Push application code
  if [[ ${PROJECT} == *"eureka"* ]]; then
    # Push Eureka application code, leveraging metadata from manifest.yml
    cf push \
      -p ${RUNNABLE_JAR} \
      -d ${DOMAIN} \
      -n ${SERVICE_ROUTE}
    RUN_RESULT=$?

    # Create a user-provided-service instance of Eureka for easier binding
    CHECK_SERVICE=$(cf service ${SERVICE_DISCOVERY_UPS})
    if [[ "$?" == "0" ]]; then
      cf delete-service -f ${SERVICE_DISCOVERY_UPS}
    fi
    cf create-user-provided-service ${SERVICE_DISCOVERY_UPS} -p "{\"uri\": \"http://${SERVICE_ROUTE}.${DOMAIN}/eureka/\"}"

  else
    # Push microservice component code, leveraging metadata from manifest.yml
    cf push \
      -p ${RUNNABLE_JAR} \
      -d ${DOMAIN} \
      -n ${SERVICE_ROUTE} \
      --no-start

    cf set-env ${PROJECT} SPRING_PROFILES_ACTIVE cloud

    cf bind-service ${PROJECT} ${SERVICE_DISCOVERY_UPS}
    cf restage ${PROJECT}
    cf start ${PROJECT}
    RUN_RESULT=$?
  fi

  if [ ${RUN_RESULT} -ne 0 ]; then
    echo ${PROJECT}" failed to start successfully.  Check logs in the local project directory for more details."
    exit 1
  fi
  cd $SCRIPTDIR
done

cf apps
#TODO Do some more inspection here to output messages for where users can find:
# - Their Eureka Dashboard
# - Their Menu UI endpoint, via Zuul-Proxy

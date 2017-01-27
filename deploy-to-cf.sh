#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/.reporc

#################################################################################
# Configuration Data
#################################################################################

#This can be updated to use any string which will guarantee global uniqueness across your region (username, favorite cat, etc.)
SERVICE_SUFFIX=${RANDOM}

#The name of the user-provided-service we will create to connect to Service Discovery servers
SERVICE_DISCOVERY_UPS="eureka-service-discovery"
#The name of the user-provided-service we will create to connect to Config servers
CONFIG_SERVER_UPS="config-server"
#The name of the user-provided-service we will create to connect to zipkin
ZIPKIN_SERVER_UPS="zipkin-server"
#The name of the CloudAMQP Bluemix Service for hystrix integration.
CLOUDAMQP_SERVICE="cloudamqp-wfd-resiliency"

# The domain associated with your Bluemix region
DOMAIN="mybluemix.net"
#DOMAIN="eu-gb.mybluemix.net"
#DOMAIN="au-syd.mybluemix.net"

#################################################################################
# Create integration services
#################################################################################

############################ CloudAMQP Service ##################################
if [ -n "`cf services | grep ${CLOUDAMQP_SERVICE}`" ]; then
  # Before creating a new CloudAMQP Service, we need to delete the old one and to do so we have to
  # unbind any app bound to the old service.
  MICROSERVICES=`cf services | grep ${CLOUDAMQP_SERVICE} | sed 's/^.*   \(wfd.*$\)/\1/g' | sed 's/, / /g'`

  if [ -n "$MICROSERVICES" ]; then
    for MICROSERVICE in `echo ${MICROSERVICES}`
    do
      cf unbind-service ${MICROSERVICE} ${CLOUDAMQP_SERVICE}
    done
  else
    cf delete-service ${CLOUDAMQP_SERVICE} -f
  fi
else
  # Create new CloudAMQP Service
  cf create-service cloudamqp lemur ${CLOUDAMQP_SERVICE}
fi
#################################################################################

#################################################################################
# Deployment Code
#################################################################################

#Build all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${REQUIRED_REPOS[@]}; do

  #PROJECT=$(echo ${REPO} | cut -d/ -f5 | cut -d. -f1)
  echo -e "\nStarting ${REPO} project"

  cd ../${REPO}

  # Determine which JAR file we should use (since we have both Gradle and Maven possibilities)
  RUNNABLE_JAR="$(find . -name "*-SNAPSHOT.jar" | sed -n 1p)"

  # Create the route ahead of time to control access
  COMPONENT=${REPO#refarch-cloudnative-}
  CURRENT_SPACE=$(cf target | grep "Space:" | awk '{print $2}')
  SERVICE_ROUTE="${COMPONENT}-${SERVICE_SUFFIX}"

  cf create-route ${CURRENT_SPACE} ${DOMAIN} --hostname ${SERVICE_ROUTE}

  # Push application code
  if [[ ${COMPONENT} == *"netflix-eureka"* ]]; then
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

  elif [[ ${COMPONENT} == *"spring-config"* ]]; then
    # Push Config Server application code, leveraging metadata from manifest.yml
    cf push \
      -p ${RUNNABLE_JAR} \
      -d ${DOMAIN} \
      -n ${SERVICE_ROUTE} \
      --no-start
    RUN_RESULT=$?

    cf set-env ${COMPONENT} SPRING_PROFILES_ACTIVE cloud
    cf bind-service ${COMPONENT} ${SERVICE_DISCOVERY_UPS}
    cf bind-service ${COMPONENT} ${ZIPKIN_SERVER_UPS}
    cf restage ${COMPONENT}
    cf start ${COMPONENT}

    # Create a user-provided-service instance of Config Server for easier binding
    CHECK_SERVICE=$(cf service ${CONFIG_SERVER_UPS})
    if [[ "$?" == "0" ]]; then
      cf delete-service -f ${CONFIG_SERVER_UPS}
    fi
    cf create-user-provided-service ${CONFIG_SERVER_UPS} -p "{\"uri\": \"http://${SERVICE_ROUTE}.${DOMAIN}/\"}"

  elif [[ ${COMPONENT} == *"zipkin"* ]]; then
    # zipkin jar is downloaded, not built by us:
    RUNNABLE_JAR="$(find . -name "zipkin.jar" | sed -n 1p)"
    # Push zipkin server, leveraging metadata from manifest.yml
    cf push \
      -p ${RUNNABLE_JAR} \
      -d ${DOMAIN} \
      -n ${SERVICE_ROUTE} \
      --no-start
    RUN_RESULT=$?

    cf bind-service ${COMPONENT} ${SERVICE_DISCOVERY_UPS}
    cf restage ${COMPONENT}
    cf start ${COMPONENT}

    # Create a user-provided-service instance of zipkin for easier binding
    CHECK_SERVICE=$(cf service ${ZIPKIN_SERVER_UPS})
    if [[ "$?" == "0" ]]; then
      cf delete-service -f ${ZIPKIN_SERVER_UPS}
    fi
    cf create-user-provided-service ${ZIPKIN_SERVER_UPS} -p "{\"uri\": \"http://${SERVICE_ROUTE}.${DOMAIN}/\"}"
  elif [[ ${COMPONENT} == "netflix-hystrix" ]]; then
    # Do nothing since the cf version of the hystrix dashboard has its own repo
    continue
  elif [[ ${COMPONENT} == "netflix-hystrix-cf" ]]; then
    # Hystrix Dashboard is a WAR application which uses Web Sockets.
    RUNNABLE_WAR="$(find . -name "hystrix-dashboard-0.0.1.war" | sed -n 1p)"
    # Push hystrix dashboard, leveraging metadata from manifest.yml
    cf push \
      -p ${RUNNABLE_WAR} \
      -d ${DOMAIN} \
      -n ${SERVICE_ROUTE} \
      --no-start
    RUN_RESULT=$?

    cf set-env ${COMPONENT} SPRING_PROFILES_ACTIVE cloud
    cf bind-service ${COMPONENT} ${ZIPKIN_SERVER_UPS}
    cf bind-service ${COMPONENT} ${CLOUDAMQP_SERVICE}

  else
    # Push microservice component code, leveraging metadata from manifest.yml
    cf push \
      -p ${RUNNABLE_JAR} \
      -d ${DOMAIN} \
      -n ${SERVICE_ROUTE} \
      --no-start

    cf set-env ${COMPONENT} SPRING_PROFILES_ACTIVE cloud

    cf bind-service ${COMPONENT} ${SERVICE_DISCOVERY_UPS}
    cf bind-service ${COMPONENT} ${CONFIG_SERVER_UPS}
    cf bind-service ${COMPONENT} ${ZIPKIN_SERVER_UPS}
    cf bind-service ${COMPONENT} ${CLOUDAMQP_SERVICE}
    cf start ${COMPONENT}
    RUN_RESULT=$?
  fi

  if [ ${RUN_RESULT} -ne 0 ]; then
    echo ${REPO}" failed to start successfully.  Check logs in the local project directory for more details."
    exit 1
  fi
  cd $SCRIPTDIR
done

cf apps

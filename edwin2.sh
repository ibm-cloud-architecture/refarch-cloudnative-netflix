#!/bin/bash

####
####TODO:
####

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#################################################################################
# Build peer repositories
#################################################################################

#Optional overrides to allow for specific default branches to be used.
DEFAULT_BRANCH=${1:-master}

#IBM Cloud Architecture GitHub Repository.  This should be changed for forked repositories.
GITHUB_ORG="ibm-cloud-architecture"

#All required repositories
REQUIRED_REPOS=(
    https://github.com/${GITHUB_ORG}/microservices-netflix-eureka.git
    https://github.com/${GITHUB_ORG}/microservices-netflix-zuul.git
    https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-appetizer.git
    https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-entree.git
    https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-dessert.git
    https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-menu.git
)

#Build all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${REQUIRED_REPOS[@]}; do

  PROJECT=$(echo ${REPO} | cut -d/ -f5 | cut -d. -f1)
  echo -e "\nStarting ${PROJECT} project"

  if [[ ! -d ${PROJECT} ]]; then
    git clone ${REPO}
  fi
  cd ${PROJECT}
  if [[ -d build/libs ]]; then
    # If gradle-built JAR exists, use it
    RUNNABLE_JAR="$(find build/libs -name "*.jar")"
  elif [[ -d target ]]; then
    # If mvn-built JAR exists, use it
    RUNNABLE_JAR="$(find target -name "*.jar")"
  else
    # Gradle build, then use it
    ./gradlew build
    RUNNABLE_JAR="$(find build/libs -name "*.jar")"
    #mvn clean package
    #RUNNABLE_JAR="$(find target -name "*.jar")"
  fi

  FILE_NAME=$(basename ${RUNNABLE_JAR})
  # Cut last 4 characters (.jar) from FILE_NAME
  APP_NAME=${FILE_NAME::-4}

  MEM="256M"
  if [[ ${APP_NAME} == *"eureka"* ]]; then
    MEM="512M"
  fi

  cf push ${APP_NAME} -p ${RUNNABLE_JAR} -m ${MEM}
  RUN_RESULT=$?

  if [ ${RUN_RESULT} -ne 0 ]; then
      echo ${PROJECT}" failed to start successfully.  Check logs in the local project directory for more details."
#      exit 1
  fi
  cd $SCRIPTDIR
done

cf apps

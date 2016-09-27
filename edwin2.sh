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

EUREKA_NAME="eureka-edwin"

#All required repositories
REQUIRED_REPOS=(
    https://github.com/${GITHUB_ORG}/microservices-netflix-eureka.git
    https://github.com/${GITHUB_ORG}/microservices-netflix-zuul.git
    https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-appetizer.git
    #https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-entree.git
    #https://github.com/${GITHUB_ORG}/microservices-refapp-wfd-dessert.git
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
  ### May not be the best way to determine this.
  if [[ ${PROJECT} == *"eureka"* ]]; then
    APP_YAML="application-eureka.yml"
  #elif [[ ${PROJECT} == *"zuul"* ]]; then
  #  APP_YAML="application-zuul-proxy.yml"
  else
    APP_YAML="application-client.yml"
  fi
  #if [[ -d build/libs ]]; then
    # If gradle-built JAR exists, use it
  #  RUNNABLE_JAR="$(find build/libs -name "*.jar")"
  #elif [[ -d target ]]; then
    # If mvn-built JAR exists, use it
  #  RUNNABLE_JAR="$(find target -name "*.jar")"
  #else
    # Gradle build, then use it
    mv src/main/resources/application.yml src/main/resources/application.yml.bak
    cp ../${APP_YAML} src/main/resources/application.yml
    #?? Save existing JAR file
    #??OLD_JAR="$(find build/libs -name "*.jar")"
    #??mv build/libs/${OLD_JAR} build/libs/${OLD_JAR}.bak
    ./gradlew build
    RUNNABLE_JAR="$(find build/libs -name "*.jar")"
    #mvn clean package
    #RUNNABLE_JAR="$(find target -name "*.jar")"
    mv src/main/resources/application.yml src/main/resources/application.yml.cf
    mv src/main/resources/application.yml.bak src/main/resources/application.yml
  #fi

  FILE_NAME=$(basename ${RUNNABLE_JAR})
  # Cut last 4 characters (.jar) from FILE_NAME
  APP_NAME=${FILE_NAME::-4}

  if [[ ${APP_NAME} == *"eureka"* ]]; then
    MEM="512M"
  else
    MEM="256M"
  fi
  if [[ ${PROJECT} == *"eureka"* ]]; then
    APP_NAME=${EUREKA_NAME}
  elif [[ ${PROJECT} == *"zuul"* ]]; then
      APP_NAME="zuul-proxy"
  elif [[ ${PROJECT} == *"menu"* ]]; then
    APP_NAME="menu-service"
  elif [[ ${PROJECT} == *"appetizer"* ]]; then
    APP_NAME="appetizer-service"
  elif [[ ${PROJECT} == *"entree"* ]]; then
    APP_NAME="entree-service"
  elif [[ ${PROJECT} == *"dessert"* ]]; then
    APP_NAME="dessert-service"
  fi

  if [[ ${PROJECT} == *"eureka"* ]]; then
    cf push ${APP_NAME} -p ${RUNNABLE_JAR} -m ${MEM}
    RUN_RESULT=$?
    ### TODO
    ### Need to do this in a clean way. Service may already exist.
    ###
    #cf cups ${APP_NAME} -p '{"uri": "http://eureka-001-snapshot.mybluemix.net/eureka"}'
    cf cups ${APP_NAME} -p '{"uri": "http://eureka-edwin.mybluemix.net/eureka"}'
  else
    cf push ${APP_NAME} -p ${RUNNABLE_JAR} -m ${MEM} --no-start
    cf set-env "${APP_NAME}" SPRING_PROFILES_ACTIVE cloud
    ### TODO
    ### May already be bound:
    ###
    #cf bind-service "${APP_NAME}" eureka-0.0.1-SNAPSHOT
    cf bind-service "${APP_NAME}" ${EUREKA_NAME}
    #cf restage ${APP_NAME}
    cf start "${APP_NAME}"
    RUN_RESULT=$?
  fi

  if [ ${RUN_RESULT} -ne 0 ]; then
      echo ${PROJECT}" failed to start successfully.  Check logs in the local project directory for more details."
#      exit 1
  fi
  cd $SCRIPTDIR
done

cf apps

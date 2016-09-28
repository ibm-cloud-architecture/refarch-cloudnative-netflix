#!/bin/bash

####
####TODO:
#### - Add execution parameters to allow for _clean_ option

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
  echo -e "\nBuilding ${PROJECT} project"

  cd ../${PROJECT}
  ./build-microservice.sh $*
  if [ $? -ne 0 ]; then
      echo "${PROJECT} failed to compile"
      exit 1
  fi
  cd ${SCRIPTDIR}
done

#!/bin/bash

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#################################################################################
# Clone peer repositories
#################################################################################
GIT_AVAIL=$(which git)
if [ ${?} -ne 0 ]; then
  echo "git is not available on your local system.  Please install git for your operating system and try again."
  exit 1
fi

#Optional overrides to allow for specific default branches to be used.
DEFAULT_BRANCH=${1:-master}

#IBM Cloud Architecture GitHub Repository.  This should be changed for forked repositories.
GITHUB_ORG="ibm-cloud-architecture"

#All required repositories
REQUIRED_REPOS=(
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-netflix-eureka.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-zipkin.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-spring-config.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-spring-turbine.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-netflix-zuul.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-wfd-appetizer.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-wfd-entree.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-wfd-dessert.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-wfd-menu.git
    https://github.com/${GITHUB_ORG}/refarch-cloudnative-wfd-ui.git
)

#Clone all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${REQUIRED_REPOS[@]}; do
  PROJECT=$(echo ${REPO} | cut -d/ -f5 | cut -d. -f1)
  echo -e "\nCloning ${PROJECT} project"
  git clone -b ${DEFAULT_BRANCH} ${REPO} ../${PROJECT}
done

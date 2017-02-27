#!/bin/bash

####
####TODO:
#### - Add execution parameters to allow for _clean_ option

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/.reporc

#################################################################################
# Build peer repositories
#################################################################################

#Optional overrides to allow for specific default branches to be used.
DEFAULT_BRANCH=${1:-master}

#Build all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${REQUIRED_REPOS[@]}; do
  #PROJECT=$(echo ${REPO} | cut -d/ -f5 | cut -d. -f1)
  echo -e "\nBuilding ${REPO} project"

  cd ../${REPO}
  ./build-microservice.sh $*
  if [ $? -ne 0 ]; then
      echo "${REPO} failed to compile"
      exit 1
  fi
  cd ${SCRIPTDIR}
done
#!/bin/bash
#################################################################################
# Clone peer repositories
#################################################################################

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/.reporc

GIT_AVAIL=$(which git)
if [ ${?} -ne 0 ]; then
  echo "git is not available on your local system.  Please install git for your operating system and try again."
  exit 1
fi

#Optional overrides to allow for specific default branches to be used.
DEFAULT_BRANCH=${1:-master}

#IBM Cloud Architecture GitHub Repository.
GITHUB_ORG=${CUSTOM_GITHUB_ORG:-ibm-cloud-architecture}
echo "Cloning from GitHub Organization or User Account of \"${GITHUB_ORG}\"."
echo "--> To override this value, run \"export CUSTOM_GITHUB_ORG=your-github-org\" prior to running this script."
echo "Cloning from repository branch \"${DEFAULT_BRANCH}\"."
echo "--> To override this value, pass in the desired branch as a parameter to this script. E.g \"./clone-peers.sh BUILD\""
read -p "Press ENTER to continue"

#Clone all required repositories as a peer of the current directory (root microservices-refapp-netflix repository)
for REPO in ${REQUIRED_REPOS[@]}; do
  GIT_REPO="https://github.com/${GITHUB_ORG}/${REPO}.git"
  echo -e "\nCloning ${REPO} project"
  git clone -b ${DEFAULT_BRANCH} ${GIT_REPO} ../${REPO}
done

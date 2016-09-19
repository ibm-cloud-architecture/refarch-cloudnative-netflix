#!/bin/bash

set -x

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#$SCRIPTDIR/../microservices-netflix-eureka/build-mvn.sh
cd $SCRIPTDIR/../eureka/
./build-mvn.sh
if [ $? -ne 0 ]; then
    echo "Eureka failed to compile"
    exit 1
fi
cd $SCRIPTDIR

#$SCRIPTDIR/../microservices-netflix-zuul/build-mvn.sh
cd $SCRIPTDIR/../zuul-proxy/
./build-mvn.sh
if [ $? -ne 0 ]; then
    echo "Zuul failed to compile"
    exit 1
fi
cd $SCRIPTDIR

cd $SCRIPTDIR/../microservices-refapp-wfd-entree/
./build-mvn.sh
if [ $? -ne 0 ]; then
    echo "Entree failed to compile"
    exit 1
fi
cd $SCRIPTDIR

cd $SCRIPTDIR/../microservices-refapp-wfd-appetizer/
./build-mvn.sh
if [ $? -ne 0 ]; then
    echo "Appetizer failed to compile"
    exit 1
fi
cd $SCRIPTDIR

cd $SCRIPTDIR/../microservices-refapp-wfd-menu/
./build-mvn.sh
if [ $? -ne 0 ]; then
    echo "Menu failed to compile"
    exit 1
fi
cd $SCRIPTDIR

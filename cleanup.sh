#!/bin/bash

SERVICES=(
      cloudamqp-wfd-resiliency
      config-server
      eureka-service-discovery
      zipkin-server
)


while getopts ":c:i:" opt; do
  case $opt in
    c)
      UNIQUE_IDENTIFIER=$OPTARG
      CF='yes'
      echo "Cleaning Cloud Foundry version"
      echo "Unique identifier: $UNIQUE_IDENTIFIER"
      ;;
    i)
      UNIQUE_IDENTIFIER=$OPTARG
      IC='yes'
      echo "Cleaning IBM Containers version"
      echo "Unique identifier: $UNIQUE_IDENTIFIER"
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done

ROUTES=`cf routes | grep $UNIQUE_IDENTIFIER | sed 's/microservices-whats-for-dinner *//g' | sed 's/   .*//g'`

if [[ $CF == 'yes' ]]
then
  ## Cloud Foundry Version ##
  APPS=`cf apps | grep $UNIQUE_IDENTIFIER | sed 's/   .*//g'`

  # Deleting all Cloud Foundry apps
  for app in $APPS
  do
    cf delete -f $app
  done

elif [[ $IC == 'yes' ]]
then
  ## IBM Containers version
  CONT_GRP=`cf ic group list | grep $UNIQUE_IDENTIFIER | awk '{print $1}'`
  CONT=`cf ic ps | grep $UNIQUE_IDENTIFIER | awk '{print $1}'`

  # Delete container groups
  for group in $CONT_GRP
  do
    cf ic group rm -f $group
  done

  for container in $CONT
  do
    cf ic rm $container --force
  done

  # Delete Container Bridge App
  cf delete -f container-bridge-app
else
  echo "[ERROR]: Wrong option selected. Please, select either Cloud Foundry or IBM Containers"
  exit 1
fi

# Deleting all created routes
for route in $ROUTES
do
  cf delete-route -f mybluemix.net --hostname $route
done

# Deleting all created services
for service in ${SERVICES[@]}
do
  cf delete-service -f $service
done

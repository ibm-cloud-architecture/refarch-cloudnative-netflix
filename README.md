# IBM Cloud Architecture - Microservices Reference Application for Netflix OSS

Reference applications for deploying microservice-based applications onto IBM Bluemix, leveraging the Netflix OSS framework.

_This application has been developed and designed to run in the **IBM Bluemix us-south public region**. Changes may be required if it is to run on a different IBM Bluemix public region or on a local/dedicated environment._

## Architecture

  ![Application Architecture](static/imgs/wfd-arch-v1.png?raw=true)

## Application Overview

The application is a simple dinner menu that displays available appetizers, entrees, and desserts for a non-existent restaurant.  There are several components of this architecture:

- Menu UI & Backend services aggregate all the options and display them to the user
- Individual microservices for menu options among Appetizers, Entrees, and Desserts
- Menu microservices communicate to each other using the [Netflix OSS Framework](https://netflix.github.io/):
    - [Zuul](https://github.com/Netflix/zuul) provides a proxy layer for the microservices.  
    - [Eureka](https://github.com/Netflix/eureka) provides a service registry.  The reusable Java microservices register themselves to Eureka which allows clients to find them.
- Menu microservices can be dynamically configured using the [Spring Framework](https://spring.io/):
    - [Spring Cloud Config](https://cloud.spring.io/spring-cloud-config/) provides server and client-side support for externalized configuration in a distributed system.

## Project Component Repositories

This project runs itself like a microservice project, as such each component in the architecture has its own Git Repository and tutorial listed below.  

Infrastructure Components:  

1. [Eureka](https://github.com/ibm-cloud-architecture/refarch-cloudnative-netflix-eureka)  - Contains the Eureka application components for microservices foundation  
2. [Zuul](https://github.com/ibm-cloud-architecture/refarch-cloudnative-netflix-zuul)  - Contains the Zuul application components for microservices foundation  
3. [Config](https://github.com/ibm-cloud-architecture/refarch-cloudnative-spring-config) - Contains the Config application components

Application Components:  

1. [Menu UI](https://github.com/ibm-cloud-architecture/refarch-cloudnative-wfd-ui)  - User interface for presenting menu options externally  
2. [Menu Backend](https://github.com/ibm-cloud-architecture/refarch-cloudnative-wfd-menu)  - Exposes all the meal components as a single REST API endpoint, aggregating Appetizers, Entrees, and Desserts.  
3. [Appetizer Service](https://github.com/ibm-cloud-architecture/refarch-cloudnative-wfd-appetizer)  - Microservice providing a REST API for Appetizer options
4. [Entree Service](https://github.com/ibm-cloud-architecture/refarch-cloudnative-wfd-entree)  - Microservice providing a REST API for Entree options  
5. [Dessert Service](https://github.com/ibm-cloud-architecture/refarch-cloudnative-wfd-dessert)  - Microservice providing a REST API for Dessert options  

### Branches

1.  **master** - This is the active development branch with the latest code and integrations.  
2.  **BUILD** - This is the [Milestone 1](https://github.com/ibm-cloud-architecture/refarch-cloudnative-netflix/tree/BUILD) branch.  It contains base microservice code, Eureka, Zuul, and Config Server components.
3.  **DEVOPS** - This is the (planned) Milestone 2 branch.  It is planned to contain DevOps pipelines for easy deployment to Bluemix, as well as Active Deploy integration scenarios.
4.  **RESILIENCY** - This is the (planned) Milestone 3 branch.  It will contain integration with Netflix Hystrix for circuit breaker implementations, as well as Zipkin/OpenTracing for distributed tracing implementations.
5.  **MANAGE** - This is the (planned) Milestone 4 branch.  It will contain cloud-based service management capabilities allowing for 24x7 operational excellence of microservice-based applications.

## Run the reference applications locally and in IBM Cloud

### Prerequisites: Environment Setup

- Install Java JDK 1.8 and ensure it is available in your PATH
- Install Docker on Windows or Mac

- Acquire the code
  - Clone the base repository:
    **`git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-netflix`**
  - Clone the peer repositories using the `master` branch, which is the active development branch:
    **`./clone_peers.sh`**
  - Or you can specify a branch when cloning the peer projects to clone and checkout a specific milestone branch.  By default, `master` is selected if no parameter is supplied:
    **`./clone_peers.sh BUILD`** to clone peer projects and use the **BUILD** branch for all projects

### Run locally via Docker Compose

You can run the entire application locally on your laptop via Docker Compose, a container orchestration tool provided by Docker.

#### Step 1: Build locally

Run one of the following build script to build all the necessary Java projects.  

-   **`./build-all.sh[-d]`** will build all the components required runnable JARs using [Gradle](https://gradle.org/) and optionally package them into Docker containers.

-   **`./build-all.sh-m [-d]`** will build all the components required runnable JARs using [Apache Maven](https://maven.apache.org/) and optionally package them into Docker containers.

#### Step 2: Run Docker Compose

Run one of the following Docker Compose commands to start all the application components locally:

  - **`docker-compose up`** to run with output sent to the console _(for all 7 microservices)_  
    or  
  - **`docker-compose up -d`** to run in detached mode and run the containers in the background.  

#### Step 3: Access the application

You can access the application after a few moments via **`http://localhost/whats-for-dinner`**!  That's easy enough!  

The backing services are automatically registered with Eureka and routed to the necessary dependent microservices, upon calling the _Menu_ service.

### Run on Bluemix via Cloud Foundry

Run the following script to deploy all the necessary Java projects as Cloud Foundry apps.

  **`./deploy-to-cf.sh`**

### Run on Bluemix via IBM Container Service

Run the following script to deploy all the necessary Java projects as Container Groups.

  **`./deploy-to-ics.sh`**


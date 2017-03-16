# How to execute an experiment

## Prerequisites

- An installed kubectl program (in case kubernetes is to be used)
- A local copy of glassfish 4.1.1
- Local docker installation
- The two CoCoME repositories
  - https://github.com/research-iobserve/cocome-cloud-jee-platform-migration
  - https://github.com/research-iobserve/cocome-cloud-jee-service-adapter
  - Note:  Presently please use the scalability-usability-1 branch for the proper setup
- A local kieker-1.12.zip or kieker-1.13-SNAPSHOT.zip in extracted form (for experiment-execution.sh only)
- JMeter 3.0
  Note: The loaddriver models for jmeter MUST use the property
        frontendIP to set the IP address of the frontend.
- The TCP endpoint for Kieker TCP-probes from 
  `iobserve-analysis/collector`.
  - To get this collector, execute `gradle build` in 
    `iobserve-analysis`. Please follow compilation instructions of the iobserve analysis project.
    Note: Presently please use the scalability-usability-1 branch for the proper collector.
  - After the build go to the `experiment-execution` directory.
  - Unpack the distribution archive with
    `tar -xvpf ../iobserve-analysis/collector/build/distributions/collector-0.0.2-SNAPSHOT.tar`
    Note, depending on your checkout location you must adapt this path.
  - Check that the `global-config.rc` COLLECTOR is pointing to the
    correct script.
    
## Example parameter

`REPO_HOST=blade1.se.internal:5000`
This is the host of the private docker repository. It is located on
`blade1.se.internal` and can be accessed via port 5000.

`GLASSFISH_IMAGE=reiner/glassfish`
Our glassfish image is labeled reiner/glassfish you may choose another
label for your setup.

`POSTGRES_IMAGE=postgres-cocome`
We use as label for the postgresql image the label `postgres-cocome` as
it is preconfigured to be used as database for CoCoME.

## Creating docker images

The docker images can be found in the `docker-images` repository.
Checkout the `docker-images` repository.

a) Change to `cocome-glassfish`
b) Run `docker build -t reiner/glassfish .`
c) Change to `cocome-postgres`
d) Run `docker build -t cocome-postgres .`

## Uploading images to private repository

Note: You can skip this task, in case you are using a local docker setup.
In that case DOCKER_REPOSITORY in `global-config.rc` must be set to `""`

a) Collect the server certs from your private docker repository server
b) Create a local directory for the certs (you need root privileges)
   `sudo mkdir -p /etc/docker/certs.d/`
c) Create a directory for the specific docker domain, e.g.,
   `sudo mkdir -p /etc/docker/certs.d/$REPO_HOST`
   Note, the port number is included in the directory name.
d) Copy the cert to this directory
   `sudo cp blade1.se.internal.crt /etc/docker/certs.d/$REPO_HOST/ca.crt`
e) Restart docker
   `sudo service docker restart`
f) Tag the image to the private docker repository
   `docker tag $GLASSFISH_IMAGE $REPO_HOST$GLASSFISH_IMAGE`
   `docker tag $POSTGRES_IMAGE $REPO_HOST$POSTGRS_IMAGE`
g) Push the images
   `docker push $REPO_HOST$GLASSFISH_IMAGE`
   `docker push $REPO_HOST$POSTGRES_IMAGE`

## Configuring the experiment

The `global-config.rc` is used to configure the experiment and other
tools used to run the experiment. A template of the configuration can
be found in `global-config.rc.template`. Please follow the comments in
the template to setup the experiment.

## Adapt and check JMeter load drivers

Each load driver must have the following structure. Note: The label
names can differ from this example.
+ Testplan: "Testplan"
  + Thread Group: "Process Sale Test"
    - HTTP Cache Manager
    - HTTP Cookie Manager
    - HTTP Request Default Einstellungen
    - Dely before HTTP requests
    + Once Only Controller "Login Controller"
      - Initialization of CoCoME 
    + Recording Controller "Purchase Controller"

The Testplan must contain the following paramters:
web.host             ${__P(frontendIP)}
web.port             8080
product.barcode      123456
purchase.cash.amount 800
cashdesk.name        cashDesk
store.id             2
cashier.username     cashier
cashier.password     cashier
base.url             cloud-web-frontend

## Ensure clean directory structure

Check that the directories for `analysis`, `data` and `visualizations`
are empty. In case you want to keep the directory content, please copy
them somewhere. In my setup these directories are
- `../data`
- `../analysis`
- `../visualizations`
The present `execute-experiment.sh` deletes the content of these
directories automatically.

## Execute experiment

Before executing the experiment make sure that no other experiment is
already running on the Kubernetes system. Even if you called
`kube-allocate-cocome.sh stop`, there might still be nodes active, as
the undeployment and deletion of the setup may take additional time.
The `execute-experiment.sh` script will also ask you to check the 
condition of the experiment setup.

In case there is no other experiment running and no residual pods, 
deployments and replicators present, you can start the experiment.

`./execute-experiment.sh LOADDRIVER`

## The experiment compiles

## Trouble Shooting

The scripts are designed to detect many issues automatically, but we did not think of every
potential error and not every mis-configuration can be detected.

### Docker errors
`Starting services ...
/usr/bin/docker: Error parsing reference: "blade1.se.internal:5000//reiner/glassfish" is not a valid repository/tag.
See '/usr/bin/docker run --help'.
/usr/bin/docker: "inspect" requires a minimum of 1 argument.
See '/usr/bin/docker inspect --help'.

Usage:	docker inspect [OPTIONS] CONTAINER|IMAGE|TASK [CONTAINER|IMAGE|TASK...]`

The availability and correct naming of the two docker images is not checked in advance.
In case the names are wrong, the docker repository is specified incorrectly or cannot be reached,
you will get an error from `docker run` and `docker inspect`.

Check the names of the images in the `IMAGE[*]` array.

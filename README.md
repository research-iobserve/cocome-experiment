# How to execute an experiment

The experiment execution script support docker and kubernetes at the
moment. It may support other system later as well.

## Prerequisites

- If you plan to use kubernetes
  - Install `kubectl` (see http://kubernetes.io/docs/user-guide/prereqs/)
- A local copy of glassfish 4.1.1+ (https://glassfish.java.net/download.html)
- Local docker installation 1.12.2+
- gradle 2.13 
- Maven
- Graphviz
- Kieker 1.13-SNAPSHOT (1.12 may work too)
- Java 8 to be able to compile all of the iObserve stuff
- JMeter 3.0
  **Note:** The loaddriver models for jmeter MUST use the property
        frontendIP to set the IP address of the frontend.
        
## Compiling iObserve Kieker add-ons and Analysis

The iObserve analysis package is required to provide specific probes for CoCoME
and provide the necessary tooling to log and aggregate data including the
TCP endpoint for the logging.

```
git clone https://github.com/research-iobserve/iobserve-analysis.git
git clone https://github.com/research-iobserve/iobserve-repository.git
```
The TCP endpoint for Kieker TCP-probes is located in
`iobserve-analysis/org.iobserve.collector`. The probes and records are located in
`iobserve-analysis/org.iobserve.monitoring` and `iobserve-analysis/org.iobserve.common`,
respectively.
- To get the probes, records and the collector, execute `gradle build` in 
  `iobserve-analysis`.
- After the build go to the `experiment-execution` directory.
- Unpack the distribution archive with
  `tar -xvpf ../iobserve-analysis/org.iobserve.collector/build/distributions/org.iobserve.collector-0.0.2-SNAPSHOT.tar`
  **Note:** depending on your checkout location you must adapt this path.
- Check that the `global-config.rc` COLLECTOR variable is pointing to the
  correct script.


## Further reading

Please also consult the `how-to-prepare-the-experiment.md` file.
    
## Global configuration parameters (example excerpt)

We use the following example parameter throughout this README. You may
use other values for them if necessary. However, you might need to
reconfigure other parts as well.

`REPO_HOST=blade1.se.internal:5000`
This is the host of the private docker repository which is accessible
by docker and kubernetes. It is located on `blade1.se.internal` and can
be accessed via port 5000.

`GLASSFISH_IMAGE=reiner/glassfish`
Our glassfish image is labeled reiner/glassfish you may choose another
label for your setup.

`POSTGRES_IMAGE=reiner/postgres-cocome`
We use as label for the postgresql image the label `reiner/postgres-cocome` as
it is preconfigured to be used as database for CoCoME.

## Creating docker images

The docker images can be found in the `docker-images` repository of the
iobserve project.
Checkout the `docker-images` repository.

1. Change to `cocome-glassfish`
2. Run `docker build -t reiner/glassfish .`
3. Change to `cocome-postgres`
4. Run `docker build -t reiner/cocome-postgres .`

## Uploading images to private repository

In case you are using docker and want to use it on your local machine,
you do not need to perform these steps.

a) Collect the server certs from your private docker repository server

b) Create a local directory for the certs (you need root privileges)
   ```
   sudo mkdir -p /etc/docker/certs.d/
   ```
c) Create a directory for the specific docker domain, e.g.,
   ```
   sudo mkdir -p /etc/docker/certs.d/$REPO_HOST
   ```
   **Note:** the port number is included in the directory name.
  
d) Copy the cert to this directory
   ```
   sudo cp blade1.se.internal.crt /etc/docker/certs.d/$REPO_HOST/ca.crt
   ```
e) Restart docker
   ```
   sudo service docker restart
   ```
f) Tag the image to the private docker repository
   ```
   docker tag $GLASSFISH_IMAGE $REPO_HOST$GLASSFISH_IMAGE
   docker tag $POSTGRES_IMAGE $REPO_HOST$POSTGRS_IMAGE
   ```
g) Push the images
   ```
   docker push $REPO_HOST$GLASSFISH_IMAGE
   docker push $REPO_HOST$POSTGRES_IMAGE
   ```

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
```
web.host             ${__P(frontendIP)}
web.port             8080
product.barcode      123456
purchase.cash.amount 800
cashdesk.name        cashDesk
store.id             2
cashier.username     cashier
cashier.password     cashier
base.url             cloud-web-frontend
```

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


During the execution, the script asks you to check and acknowledge the
completion of experiment tasks. After execution the experiment has
produced a tar file containing the collected monitoring data and example
images generated with the Kieker analysis tool.


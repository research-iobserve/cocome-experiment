# How To Prepare the Experiment

## Prerequisites

You need
- glassfish [4.1.1 or later] https://glassfish.java.net/download.html
- gradle [2.13*]
- maven [3* or later]
- docker [1.12.2 or later]
- JMeter [3.0.*] http://jmeter.apache.org/download_jmeter.cgi

Glassfish is required for the asadmin tool, docker as a container
environment. Grade is used for iobserve build system and maven for
CoCoME.

Also checkout the following repositories:
CoCoME:
`git clone https://github.com/research-iobserve/cocome-cloud-jee-service-adapter.git`
`git clone https://github.com/research-iobserve/cocome-cloud-jee-platform-migration.git`

Docker Container:
`git clone https://github.com/research-iobserve/docker-images.git`

iObserve Analysis: 
The analysis also provides iObserve specific probes and the repository
the additional packages as maven repository which are not available via
maven.

`git clone https://github.com/research-iobserve/iobserve-analysis.git`
`git clone https://github.com/research-iobserve/iobserve-repository.git`

## Compilation

Go to the iobserve-analysis folder and create file called 'gradle.properties'.
In this file enter one line
`api.baseline=FULL_PATH_TO_IOBSERVE_REPOSITORY/mvn-repo`

Save the file.

Execute `gradle build`

Execute `gradle install`

## Create Docker Container

Change to the directory `docker-images`.

This directory should contain one ` and one `cocome-postgres`
directory.

`cd cocome-glassfish`

The docker container is supplied with a Kieker configuration file
`kieker.monitoring.properties`. To support monitoring, you need to
adjust this file to your needs. As it is not very helpful to log to
a docker container (all is lost after termination), it is better to
write all logging information to a remote host. In our case this is
`192.168.48.222`. 

Therefore, you must edit the line
`kieker.monitoring.writer.tcp.SingleSocketTcpWriter.hostname=192.168.48.222`
for your remote host.

Now build the glassfish image. Use the following line and replace 
`PREFIX` with your name or any other identifier that help you to find
your image later on.

`docker build -t PREFIX/glassfish .`

This will create a new docker image for glassfish.

Last line should look like this

`Successfully built f2d841e58f69`

Type

`docker images`

and check if your `PREFIX/glassfish` is listed.

Now continue with the postgres docker image.

`cd ../cocome-postgres`

This docker image configuration contains a minimal db setup script
where we create a database `cocomedb`, a user `cocome` with a password
`dbuser`.

You may change this, but this requires other modifications later (which
is not covered in this how to) in the service-adapter. 

Create the image with

`docker build -t PREFIX/postgres .`

The last output line should be

`Successfully built 596adb192baf`

Check whether the image is available with

`docker images`

## Start Containers

You need at least the following instances:
web        (glassfish)
store      (glassfish)
registry   (glassfish)
enterprise (glassfish)
adapter    (glassfish)
database   (postgres)

All in all 5 glassfish instances and one postgres.

We use kubernetes to start our docker container, but you can also do
this directly on your machine with:

`docker run PREFIX/postgres`  (one time)
`docker run PREFIX/glassfish` (five times)

It helps to use 5 different terminals to start them so you can watch
the log information.

## Retrieve IP addresses for your containers

Type

`docker ps`

This lists all running images. To get the IP addresses for all of them,
you need to `inspect` the containers. The `ps` command listed six
machines each with its own container id.

For each container id type:

`docker inspect CONTAINER_ID | grep IPAddress | tail -1 | awk '{ print $2}' | sed 's/^\"\(.*\)\",$/\1/g'`

Note all these ip addresses. You also may used the `./get-container-ip.sh`
script (available in the latest master revision).

## Test whether the database is available

Lets assume your database is running on `172.17.0.7`, then you can type

`psql -h 172.17.0.7 -U cocome cocomedb -W`

The system will prompt for the password, which is `dbuser`.

If the system does not provide access or refuses to connect something of
your setup is broken and you have to investigate the output of the 
postgres docker image.

## Test the glassfish installations

You can connect with your browser to the other IP addresses with

`https://IP-ADDRESS:4848/`

This should bring up the login screen of the respective glassfish.
You may log in with `admin` and `admin`.

## Configure and Compile CoCoME

Go to the `cocome-cloud-jee-platform-migration` directory, e.g.,

`cd ../cocome-cloud-jee-platform-migration`

You may find valuable information listed in the `README.md` in this
directory. However, to continue with this how to, we skip this file. 

Change to `cocome-maven-project` with

`cd cocome-maven-project`

In this directory you may find an `settings.xml.template`. Copy it to
`settings.xml` and open it in your favorite editor,e.g.,

`vi settings.xml`

In this file, you find various configuration settings. One of them are
the host settings. This is where the IP-addresses go. 

Note which IP address was used for which service of CoCoME.
`logic.registry`   is for `registry`
`logic.store`      is for `store`
`logic.enterprise` is for `enterprise`
`web`              is for `web`
`serviceadapter`   is for `adapter`

After configuration type

`mvn -s settings.xml compile package`

Now switch to the service-adapter archive.

`cd ../../cocome-cloud-jee-service-adapter`

Here you must compile the application as well with

`mvn -s ../cocome-cloud-jee-platform-migration/cocome-maven-project/settings.xml compile package`

In case both builds are successful, you can continue and setup the data collector.

## Configure and Run Kieker Data Collector

Before deployment, you must setup the data collector or an Kieker
analysis service. For this tutorial, we use the iobserve-collector as
it collects all the data from all machines and logs them in one Kieker
log.

First go to the experiment root directory.

`cd ..`

Now extract the previously build collector with

`tar -xvpf iobserve-analysis/org.iobserve.collector/build/distributions/org.iobserve.collector-0.0.2-SNAPSHOT.tar`

This creates an directory called `org.iobserve.collector-0.0.2-SNAPSHOT`
with a `bin` and `lib` subdirectory.

Before starting the collector, it is recommended to create a data directory.
This is done as follows:

`mkdir data`

Now run the collector with

`org.iobserve.collector-0.0.2-SNAPSHOT/bin/org.iobserve.collector -d data -p 9876`

The output should look like

`Receiver
SLF4J: Class path contains multiple SLF4J bindings.
SLF4J: Found binding in [jar:file:/home/reiner/Projects/iObserve/org.iobserve.collector-0.0.2-SNAPSHOT/lib/gradle-core-2.13.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: Found binding in [jar:file:/home/reiner/Projects/iObserve/org.iobserve.collector-0.0.2-SNAPSHOT/lib/logback-classic-1.1.7.jar!/org/slf4j/impl/StaticLoggerBinder.class]
SLF4J: See http://www.slf4j.org/codes.html#multiple_bindings for an explanation.
SLF4J: Actual binding is of type [org.gradle.logging.internal.slf4j.OutputEventListenerBackedLoggerContext]
Configuration complete
Running analysis`

If you look in the `data` directory, you may find a subdirectory with
a name similar to this example

`kieker-20161213-122339345-UTC-stockholm-iObserve-Experiments`

The prefix `kieker` is followed by the date and the time of the initialization
of the logging. `UTC` is the used timezone followed by the host name, and
concluded by an experiment identifier (which is set in the collector).

## Deploy CoCoME

Finally, you can deploy CoCoME.

Go back to the root directory of your experiment folder. Lets assume you
unpacked the glassfish folder there.

Create a password file for the glassfish asadmin tool otherwise you have
to provide it over and over again.

echo "AS_ADMIN_PASSWORD=admin" > pwfile

Assuming `172.17.0.2` is the service-adapter node and `172.17.0.7` is
the database node, type

`glassfish4/glassfish/bin/asadmin --host 172.17.0.2 -p 4848 --user admin -W pwfile \
	--interactive=false \
	create-jdbc-connection-pool \
	--datasourceclassname org.postgresql.ds.PGSimpleDataSource \
	--restype javax.sql.DataSource \
 	--property user=cocome:password=dbuser:servername=172.17.0.7:databasename=cocomedb PostgresPool`

This should create a connection pool for the postgres database on the
adapter node. It should state success with:

JDBC connection pool PostgresPool created successfully.
Command create-jdbc-connection-pool executed successfully.

Now type to create the necessary resource

`glassfish4/glassfish/bin/asadmin --host 172.17.0.2 -p 4848 --user admin -W pwfile \
	--interactive=false \
	create-jdbc-resource --connectionpoolid PostgresPool jdbc/CoCoMEDB`

This should report

JDBC resource jdbc/CoCoMEDB created successfully.
Command create-jdbc-resource executed successfully.

'Note:' It is very helpful to script these tasks, as they have to be done
over and over againg.

'Note:' In the following the compiled and packaged EAR and WAR files come
with an version suffix (-1.1). On some systems this is omitted. In that
case you have to adjust the names accordingly.

Now deploy the ear and war images as follows. Note the given IP addresses
are only examples.

`glassfish4/glassfish/bin/asadmin --host 172.17.0.2 -p 4848 --user admin -W pwfile --interactive=false deploy service-adapter/service-adapter-ear/target/service-adapter-ear-1.1.ear`

Success is indicated with:

Application deployed with name service-adapter-ear-1.1.
Command deploy executed successfully.

The next part is the registry:

`glassfish4/glassfish/bin/asadmin --host 172.17.0.6 -p 4848 --user admin -W pwfile --interactive=false deploy cocome-cloud-jee-platform-migration/cocome-maven-project/cloud-logic-service/cloud-registry-service/target/cloud-registry-service-1.1.war`

Success is indicated with:

Application deployed with name cloud-registry-service-1.1.
Command deploy executed successfully.

Deploy the store service:
 
`glassfish4/glassfish/bin/asadmin --host 172.17.0.5 -p 4848 --user admin -W pwfile --interactive=false deploy cocome-cloud-jee-platform-migration/cocome-maven-project/cloud-logic-service/cloud-store-logic/store-logic-ear/target/store-logic-ear-1.1.ear`

Success is indicated with:

Application deployed with name store-logic-ear-1.1.
Command deploy executed successfully.

Deploy the enterprise service:

`glassfish4/glassfish/bin/asadmin --host 172.17.0.4 -p 4848 --user admin -W pwfile --interactive=false deploy cocome-cloud-jee-platform-migration/cocome-maven-project/cloud-logic-service/cloud-enterprise-logic/enterprise-logic-ear/target/enterprise-logic-ear-1.1.ear`

Success is indicated with:

Application deployed with name enterprise-logic-ear-1.1.
Command deploy executed successfully.

Deploy the web frontend:

`glassfish4/glassfish/bin/asadmin --host 172.17.0.3 -p 4848 --user admin -W pwfile --interactive=false deploy cocome-cloud-jee-platform-migration/cocome-maven-project/cloud-web-frontend/target/cloud-web-frontend-1.1.war`

Success is indicated with:

Application deployed with name cloud-web-frontend-1.1.
Command deploy executed successfully.

'Note:' It is recommended, if this is your first deployment to check if
everything is fine by entering every glassfish instance via its web
interface.

## Access the Application

In the above example configuration, the web frontend is deployed on 
host `172.17.0.3`. So now you can access the web frontend with

`https://172.17.0.3:8080/clound-web-frontend/`

or

`https://172.17.0.3:8080/clound-web-frontend-1.1/`

Valid logins are 'cashier'/'cashier' and 'admin'/'admin'.

The cashier can be used for the 'Cashier' role (see drop down menu) and
admin is suitable for 'Database Manager'.

## Execute a JMeter Script

Before you can shop anything with CoCoME, you need an initialization.
This can be done by hand, but this is cumbersome so we prepared an
initialization JMeter script.

Assuming you unpacked JMeter in the experiment root folder, you can type

`apache-jmeter-3.0/bin/jmeter -p "jmeter.properties" -l "data/results.csv" -n -t "initialize.jmx" -JfrontendIP="172.17.0.3"`

The `jmeter.properties` configure the logging of actions of the JMeter
application. The results are stored in `data/results.csv`, 
`initialize.jmx` contains the workload used ot initialize CoCoME with
one product, and `172.17.0.3` is again the IP of the web frontend.

Please note that you have to adjust the IP addresses to the one your
docker instances have.


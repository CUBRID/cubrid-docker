# How to Use the CUBRID Images
## Build an Image for CUBRID
Build an image for CUBRID as follows:

    docker build -t cubrid:tag tag
where `tag` is the tag specifying the CUBRID version you want.

## Start a CUBRID Instance in a Container
### Start all CUBRID Components (Broker and Server) in a Container
Start a CUBRID instance as follows:

    docker run -d --name container-name -e "CUBRID_DB=dbname" cubrid:tag
where `container-name` is the name you want to assign to your container, `dbname` is the name of DB you want to use or create and `tag` is the tag specifying the CUBRID version you want.

### Connect to CUBRID from the CUBRID Command Line Client (csql)
The following command runs a csql command line client inside an existing CUBRID container instance:

    docker exec -it container-name csql dbname

## Start CUBRID Components in Multiple Containers
### Start Containers for Broker and DB Server
Start a Server instance as follows:

    docker run -d -e 'CUBRID_COMPONENTS=SERVER' --name server-container-name cubrid:tag

And Start a Broker instance as follows:

    docker run -d -e 'CUBRID_COMPONENTS=BROKER' -e 'CUBRID_DB_HOST=cubrid_server' -e 'CUBRID_DB=dbname' --name broker-container-name --link cubrid_server:server-container-name cubrid:tag
where `server-container-name` or `broker-container-name` is the name you want to assign to your container.

### Start Containers for Broker and DB Server Using Docker Compose
Start Broker and Server instance as follows:

    docker-compose -p project-name -f tag/docker-compose.yml up
where `project-name` is the name you want to assign to your project and `tag` is the tag specifying the CUBRID version you want.

## Start CUBRID HA in Multiple Containers
### Start CUBRID HA Components (Master DB and Slave DB Server)
Create a isolated network for HA

    docker network create --driver bridge cubrid_ha_net
where `cubrid_ha_net` is the name you want to assign to your isolated network.

Start a Master instance (with Broker) as follows:

    docker run -d --net=cubrid_ha_net -e 'CUBRID_COMPONENTS=HA' -e 'CUBRID_DB_HOST=master-container-name:slave-container-name' -e 'CUBRID_DB=dbname' --hostname master-container-name --name master-container-name cubrid:tag

Start a Slave instance (with Broker) as follows:

    docker run -d --net=cubrid_ha_net -e 'CUBRID_COMPONENTS=HA' -e 'CUBRID_DB_HOST=master-container-name:slave-container-name' -e 'CUBRID_DB=dbname' --hostname slave-container-name --name slave-container-name cubrid:tag
where `master-container-name` or `slave-container-name` is the name you want to assign to your container and `tag` is the tag specifying the CUBRID version you want.

The following command runs a cubrid command inside an existing master container instance:

    docker exec -it master-container-name gosu cubrid cubrid hb status
### Start CUBRID HA Components (Broker, Master DB and Slave DB Server) Using Docker Compose
Start HA instances as follows:

    docker-compose -p ha-project-name -f tag/docker-compose-ha.yml up
where `ha-project-name` is the name you want to assign to your project and `tag` is the tag specifying the CUBRID version you want.

Stop HA instances remove related containers, networks and volumes as follows:

    docker-compose -p ha-project-name -f tag/docker-compose-ha.yml down -v

### Start CUBRID HA Components (Master DB with Broker and Slave DB Server with Broker) Using Docker Compose
Start HA instances as follows:

    docker-compose -p ha2-project-name -f tag/docker-compose-ha2.yml up
where `ha2-project-name` is the name you want to assign to your project and `tag` is the tag specifying the CUBRID version you want.

# Supported Docker Versions
- Docker version 1.10 or higher is required.
- Docker Compose version 1.11.2 or higher is required.

The compose file used in above examples is written in Compose File Format 2.0 and it requires Docker Engine version 1.10+.
For more information for Docker Engine and other Docker products, please visit https://github.com/docker.


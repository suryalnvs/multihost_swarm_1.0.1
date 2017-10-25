#### HYPERLEDGER/FABRIC MULTIHOST NETWORK using DOCKER-SWARM

### Introduction
This project demonstrates how to launch network using Hyperledger-Fabric-v1.0.1 on a multi-host, multi-org network. It consists of scripts that spin your hyperledger-fabric network(multi-host) by utilizing a docker swarm. Chaincode example02 is used to test the network using cli.

### Build fabric network on multiple hosts
Install prerequisites on each host machine. Follow the steps [here](https://github.com/suryalnvs/startup_scripts/blob/master/setup_prereq.sh).
You also need to make sure that your host machines can see each other and talk using either a private or public ip.

**Note:** You can follow the byfn example in the fabric docs to generate your certificates and use the ca servers. For convenience, we have bootstrapped the certificates and imported them in this project to be used immediately.

From the first machine:
```
docker swarm init
```
This machine acts as the swarm-manager. Ignore the output from the swarm init and retrieve the worker join token by running the following command:
```
docker swarm join-token worker
```

This will output a command that looks something like:
```
docker swarm join --token SWMTKN-1-1rzeleqmbxe1czsan98fopg63ghyp9sqc1lvj8z94bvhtgjvzh-d3yot42fplz1xeiarz2clt1ux 10.0.2.11:2377
```
Execute this statement on both worker machines(which now are workers from a swarm perspective but we just need them for the overlay network so we do not care). 

## Launching the Hyperledger-Fabric Network across multihosts:
**clone the repo onto the first machine (swarm-manager) and start launching the network across multihost machines from multihost_swarm_1.0.1 directory. Let's go!*
```
cd multihost_swarm_1.0.1
```
Obtain the hostnames of your manager, workers by running the command:
```
docker node ls
```
Before launching the network, generate the certificates using cryptogen and channel-artifacts using configtxgen:
```
./generateArtifacts.sh <channel-name>
```
Once, the above command ran successfully, copy the generated certificates and channel-artifacts to a location on all the machines in the cluster.

## To launch the network across multiple machines, modify the following in the multihost_launcher.sh script with the hostnames obtained from above:
```
ZK_NODE="manager" # Node name of the host where zookeeper will be launched
KAFKA_NODE="manager" #Node name of the host where kafka will be launched
ORDERER_NODE="manager" #Node name of the host where orderer will be launched
PEER_NODE1="multihost1" #Node name of the host where the first peer of each organization will be launched
PEER_NODE2="multihost2" #Node name of the host where the second peer of each organization will be launched
CA_NODE="manager"  #Node name of the host where the ca of each organization will be launched
CLI_NODE="manager" #Node name of the host where the cli container will be launched
TLS=true
CERTS_PATH=/home/ubuntu/multihost_swarm_1.0.1 #change this path to where the certificates and channel-artifacts are copied
```
After modifying the multihost_launcher.sh script, use the following script to launch the network:
```
Usage: 
  ./multihost_launcher.sh [opt] [value] "
                           -z: number of zookeepers, default=3
                           -k: number of kafka, default=5
                           -o: number of orderers, default=3"
                           -r: number of organizations, default=2"
                           -c: channel name, default=mychannel"
 For example: 
 ./multihost_launcher.sh -z 3 -k 5 -o 3 -r 2 -c mychannel
```
To see the services that are launched from the above command, run the following command:
```
docker service ls
```
This command will launch the network and a cli container to deploy the chaincode example02 and run invokes and queries to test the network.

This end-to-end scenario can be observed in the cli logs.

To remove all the services, run the following command:
```
docker service rm $(docker service ls)
```

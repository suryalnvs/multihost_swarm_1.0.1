#!/bin/bash

#Node names and IP addresses of the hosts to be used
ZK_NODE="manager" # Node name of the host where zookeeper to be launched
KAFKA_NODE="manager" #Node name of the host where kafka to be launched
ORDERER_NODE="manager" #Node name of the host where orderer to be launched
PEER_NODE1="multihost1"
PEER_NODE2="multihost2"
CA_NODE="manager"
CLI_NODE="manager"
TLS=true
CERTS_PATH=/home/ubuntu/multihost_swarm_1.0.1

function printHelp {

   echo "Usage: "
   echo " ./multihost_launcher.sh [opt] [value] "
   echo "    -z: number of zookeepers, default=3"
   echo "    -k: number of kafka, default=5"
   echo "    -o: number of orderers, default=3"
   echo "    -r: number of organizations, default=2"
   echo "    -c: channel name, default=mychannel"
   echo " "
   echo " example: "
   echo " ./multihost_launcher.sh -z 3 -k 5 -o 3 -r 2 -c mychannel"
   exit
}

#defaults
nZookeeper=3
nKafka=5
nOrderer=3
nOrgs=2
channel="mychannel"

while getopts ":z:k:o:r:c:" opt; 
do
	case $opt in
        	z)
	  	  nZookeeper=$OPTARG
        	;;
        	k)
          	  nKafka=$OPTARG
        	;;
        	o)
          	  nOrderer=$OPTARG
        	;;
        	r)
          	  nOrgs=$OPTARG
        	;;
        	c)
          	  channel=$OPTARG
        	;;
        	\?)
      		   echo "Invalid option: -$OPTARG" >&2
      		   printHelp
      		;;
    		:)
      		  echo "Option -$OPTARG requires an argument." >&2
          	  printHelp
      		;;
   	esac
done

#echo "Generating the Artifacts"
#./generateArtifacts.sh $channel

echo "Creating the overlay network"
docker network ls | grep my-network
if [ $? -ne 0 ]; then
	docker network create --driver overlay --subnet=10.0.0.0/24 --attachable my-network
else
	echo "my-network overlay network bridge already exists"
fi

echo "Launching zookeepers"
for (( i=0 ; i<$nZookeeper ; i++ ))
do
        docker service create --name zookeeper$i \
        --network my-network \
        --restart-condition none \
        --host zookeeper0:10.0.0.3 \
        --host zookeeper1:10.0.0.5 \
        --host zookeeper2:10.0.0.7 \
        --host kafka0:10.0.0.9 \
        --host kafka1:10.0.0.11 \
        --host kafka2:10.0.0.13 \
        --host kafka3:10.0.0.15 \
        --host kafka4:10.0.0.17 \
        --constraint 'node.hostname == '$ZK_NODE \
        --env ZOO_MY_ID=`expr $i + 1` \
        --env ZOO_SERVERS='server.1=zookeeper0:2888:3888:participant server.2=zookeeper1:2888:3888:participant server.3=zookeeper2:2888:3888:participant' \
        hyperledger/fabric-zookeeper:x86_64-1.0.1
done

sleep 15

echo "Launching kafka brokers"
for (( i=0, j=9092 ; i<$nKafka; i++, j=j+2 ))
do

        docker service create --name kafka$i \
        --network my-network \
        --restart-condition none \
        --host zookeeper0:10.0.0.3 \
        --host zookeeper1:10.0.0.5 \
        --host zookeeper2:10.0.0.7 \
        --host kafka0:10.0.0.9 \
        --host kafka1:10.0.0.11 \
        --host kafka2:10.0.0.13 \
        --host kafka3:10.0.0.15 \
        --host kafka4:10.0.0.17 \
        --host orderer0.example.com:10.0.0.19 \
        --host orderer1.example.com:10.0.0.21 \
        --host orderer2.example.com:10.0.0.23 \
        --constraint 'node.hostname == '$KAFKA_NODE \
        --env KAFKA_BROKER_ID=$i \
        --env KAFKA_MESSAGE_MAX_BYTES=10000000 \
        --env KAFKA_REPLICA_FETCH_MAX_BYTES=10000000 \
        --env KAFKA_ADVERTISED_PORT=$j \
        --env KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka$i:$j \
        --env KAFKA_LISTENERS=PLAINTEXT://:$j \
        --env KAFKA_LOG_RETENTION_HOURS=4380 \
        --env KAFKA_LOG_DIRS=/kafka-logs/ \
        --env KAFKA_ZOOKEEPER_CONNECT=zookeeper0:2181,zookeeper1:2181,zookeeper2:2181 \
        --env KAFKA_DEFAULT_REPLICATION_FACTOR=3 \
        --env KAFKA_MIN_INSYNC_REPLICAS=2 \
        --env KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE=false \
        hyperledger/fabric-kafka:x86_64-1.0.1
done

sleep 10

echo "Launching Orderers"
for (( i=0, j=7050 ; i<$nOrderer ; i++, j=j+20 ))
do 
	docker service create --name orderer$i \
	--network my-network  \
	--restart-condition none \
        --hostname orderer$i \
        --host kafka0:10.0.0.9 \
        --host kafka1:10.0.0.11 \
        --host kafka2:10.0.0.13 \
        --host kafka3:10.0.0.15 \
        --host kafka4:10.0.0.17 \
        --host orderer0.example.com:10.0.0.19 \
        --host orderer1.example.com:10.0.0.21 \
        --host orderer2.example.com:10.0.0.23 \
        --host peer0.org1.example.com:10.0.0.25 \
        --host peer1.org1.example.com:10.0.0.27 \
        --host peer0.org2.example.com:10.0.0.29 \
        --host peer1.org2.example.com:10.0.0.31 \
	--constraint 'node.hostname == '$ORDERER_NODE \
        --env ORDERER_GENERAL_LEDGERTYPE=file \
        --env ORDERER_FILELEDGER_LOCATION=/var/hyperledger/orderer/ \
        --env ORDERER_GENERAL_LOGLEVEL=ERROR \
        --env ORDERER_GENERAL_LISTENADDRESS=0.0.0.0 \
        --env ORDERER_GENERAL_GENESISMETHOD=file \
        --env ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/genesis.block \
        --env ORDERER_GENERAL_LOCALMSPID=OrdererMSP \
        --env ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp  \
        --env ORDERER_RAMLEDGER_HISTORY_SIZE=100 \
        --env ORDERER_GENERAL_TLS_ENABLED=$TLS \
        --env ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key \
        --env ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt \
        --env ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt] \
        --workdir /opt/gopath/src/github.com/hyperledger/fabric  \
        --mount type=bind,src=$CERTS_PATH/channels/genesis.block,dst=/var/hyperledger/orderer/genesis.block  \
        --mount type=bind,src=$CERTS_PATH/crypto-config/ordererOrganizations/example.com/orderers/orderer$i.example.com/msp,dst=/var/hyperledger/orderer/msp \
        --mount type=bind,src=$CERTS_PATH/crypto-config/ordererOrganizations/example.com/orderers/orderer$i.example.com/tls,dst=/var/hyperledger/orderer/tls \
        --publish $j:7050 \
        hyperledger/fabric-orderer:x86_64-1.0.1 orderer
done

echo "Launching Peers"
total_orgs=$nOrgs

for (( i=0, port1=7051, tmp_port=7061 , tmp_ip=25 ; i<$total_orgs ; i++, port1=port1+20, tmp_port=tmp_port+20, tmp_ip=tmp_ip+4  ))
do
        echo "Launching org${i}-peer0"
        docker service create --name org${i}-peer0 \
        --network my-network \
        --restart-condition none \
        --host orderer0.example.com:10.0.0.19 \
        --host orderer1.example.com:10.0.0.21 \
        --host orderer2.example.com:10.0.0.23 \
        --host peer0.org1.example.com:10.0.0.25 \
        --host peer1.org1.example.com:10.0.0.27 \
        --host peer0.org2.example.com:10.0.0.29 \
        --host peer1.org2.example.com:10.0.0.31 \
        --host ca-org1:10.0.0.33 \
        --host ca-org2:10.0.0.35 \
	--constraint 'node.hostname == '$PEER_NODE1 \
        --env CORE_PEER_ADDRESSAUTODETECT=false \
        --env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
        --env CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=my-network \
        --env CORE_VM_DOCKER_HOSTCONFIG_EXTRAHOSTS=peer0.org`expr $i + 1`.example.com:10.0.0.$tmp_ip \
        --env CORE_LOGGING_LEVEL=DEBUG \
        --env CORE_PEER_TLS_ENABLED=$TLS \
        --env CORE_PEER_COMMITTER_ENABLED=true \
        --env CORE_PEER_GOSSIP_ORGLEADER=false \
        --env CORE_PEER_GOSSIP_USELEADERELECTION=true \
        --env CORE_PEER_PROFILE_ENABLED=true \
        --env CORE_PEER_ADDRESS=peer0.org`expr $i + 1`.example.com:7051 \
        --env CORE_PEER_LISTENADDRESS=0.0.0.0:7051 \
        --env CORE_PEER_ID=peer0.org`expr $i + 1`.example.com \
        --env CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp \
        --env CORE_PEER_LOCALMSPID=Org`expr $i + 1`MSP \
        --env CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org`expr $i + 1`.example.com:7051 \
        --env CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
        --env CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
        --env CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
        --env CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
        --workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
        --mount type=bind,src=/var/run/,dst=/host/var/run/ \
        --mount type=bind,src=$CERTS_PATH/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer0.org`expr $i + 1`.example.com/msp,dst=/etc/hyperledger/fabric/msp \
        --mount type=bind,src=$CERTS_PATH/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer0.org`expr $i + 1`.example.com/tls,dst=/etc/hyperledger/fabric/tls \
        --publish $port1:7051 \
        --publish `expr $port1 + 2`:7053 \
        hyperledger/fabric-peer:x86_64-1.0.1 peer node start

        for (( p=1, port2=$tmp_port, ip=${tmp_ip}+2 ; p < 2 ; p++, port2=port2+10, ip=ip+2 ))
        do
		echo "Launching org${i}-peer$p"
		docker service create --name org${i}-peer${p} \
       		--network my-network \
       		--restart-condition none \
        	--host orderer0.example.com:10.0.0.19 \
        	--host orderer1.example.com:10.0.0.21 \
        	--host orderer2.example.com:10.0.0.23 \
        	--host peer0.org1.example.com:10.0.0.25 \
        	--host peer1.org1.example.com:10.0.0.27 \
        	--host peer0.org2.example.com:10.0.0.29 \
        	--host peer1.org2.example.com:10.0.0.31 \
        	--host ca-org1:10.0.0.33 \
        	--host ca-org2:10.0.0.35 \
        	--constraint 'node.hostname == '$PEER_NODE2 \
                --env CORE_PEER_ADDRESSAUTODETECT=false \
                --env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
                --env CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=my-network \
                --env CORE_VM_DOCKER_HOSTCONFIG_EXTRAHOSTS=peer$p.org`expr $i + 1`.example.com:10.0.0.$ip \
                --env CORE_LOGGING_LEVEL=ERROR \
                --env CORE_LOGGING_GOSSIP=DEBUG \
                --env CORE_PEER_TLS_ENABLED=$TLS \
                --env CORE_PEER_COMMITTER_ENABLED=true \
                --env CORE_PEER_GOSSIP_ORGLEADER=false \
                --env CORE_PEER_GOSSIP_USELEADERELECTION=true \
                --env CORE_PEER_PROFILE_ENABLED=true \
                --env CORE_PEER_ADDRESS=peer1.org`expr $i + 1`.example.com:7051 \
                --env CORE_PEER_ID=peer1.org`expr $i + 1`.example.com \
                --env CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp \
                --env CORE_PEER_LOCALMSPID=Org`expr $i + 1`MSP \
                --env CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org`expr $i + 1`.example.com:7051 \
                --env CORE_PEER_GOSSIP_SKIPHANDSHAKE=true \
                --env CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt \
                --env CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key \
                --env CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt \
                --workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
                --mount type=bind,src=/var/run/,dst=/host/var/run/ \
                --mount type=bind,src=$CERTS_PATH/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer$p.org`expr $i + 1`.example.com/msp,dst=/etc/hyperledger/fabric/msp \
                --mount type=bind,src=$CERTS_PATH/crypto-config/peerOrganizations/org`expr $i + 1`.example.com/peers/peer$p.org`expr $i + 1`.example.com/tls,dst=/etc/hyperledger/fabric/tls \
                --publish $port2:7051 \
                --publish `expr $port2 + 2`:7053 \
                hyperledger/fabric-peer:x86_64-1.0.1 peer node start
        done
done

echo "Launching CA"
for (( p=1, port=7054 ; p <= $nOrgs  ; p++, port=port+1000 ))
do

        CURRENT_DIR=$PWD
        cd /$CERTS_PATH/crypto-config/peerOrganizations/org$p.example.com/ca/
        PRIV_KEY=$(ls *_sk)
        cd $CURRENT_DIR
        docker service create --name ca_org$p \
        --network my-network \
        --hostname ca-org$p \
        --restart-condition none \
        --constraint 'node.hostname == '$CA_NODE \
        --env FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server \
        --env FABRIC_CA_SERVER_CA_NAME=ca-org$p \
        --env FABRIC_CA_SERVER_TLS_ENABLED=$TLS \
        --env FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org$p.example.com-cert.pem \
        --env FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/$PRIV_KEY \
        --env FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org$p.example.com-cert.pem \
        --env FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-config/$PRIV_KEY \
        --publish $port:7054 \
        --mount type=bind,src=$CERTS_PATH/crypto-config/peerOrganizations/org$p.example.com/ca/,dst=/etc/hyperledger/fabric-ca-server-config \
        hyperledger/fabric-ca:x86_64-1.0.1 sh -c 'fabric-ca-server start -b admin:adminpw' -d
done

#
sleep 15
#
echo "Launching CLI"
docker service create --name cli \
	--tty=true \
	--network my-network \
	--restart-condition none \
        --host orderer0.example.com:10.0.0.19 \
        --host orderer1.example.com:10.0.0.21 \
        --host orderer2.example.com:10.0.0.23 \
        --host peer0.org1.example.com:10.0.0.25 \
        --host peer1.org1.example.com:10.0.0.27 \
        --host peer0.org2.example.com:10.0.0.29 \
        --host peer1.org2.example.com:10.0.0.31 \
	--constraint 'node.hostname == '$CLI_NODE \
	--env GOPATH=/opt/gopath \
	--env CORE_PEER_ADDRESSAUTODETECT=false \
	--env CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock \
	--env CORE_PEER_TLS_ENABLED=$TLS \
	--env CORE_LOGGING_LEVEL=DEBUG \
	--env CORE_PEER_ID=cli \
	--env CORE_PEER_ENDORSER_ENABLED=true \
	--env CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
	--env CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
	--env CORE_PEER_GOSSIP_IGNORESECURITY=true \
	--env CORE_PEER_LOCALMSPID=Org0MSP \
	--env CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
	--workdir /opt/gopath/src/github.com/hyperledger/fabric/peer \
	--mount type=bind,src=/var/run,dst=/host/var/run \
	--mount type=bind,src=$CERTS_PATH/crypto-config,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto \
	--mount type=bind,src=$CERTS_PATH/channels,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts \
	--mount type=bind,src=$CERTS_PATH/scripts,dst=/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts \
	--mount type=bind,src=$CERTS_PATH/chaincodes,dst=/opt/gopath/src/github.com/hyperledger/fabric/examples/chaincode \
	hyperledger/fabric-tools:x86_64-1.0.1  /bin/bash -c './scripts/script.sh '$channel'; '

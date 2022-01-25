
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

function startFresh(){
  docker rm -f $(docker ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
  docker rm -f $(docker ps -aq --filter name='dev-peer*') 2>/dev/null || true
  docker image rm -f $(docker images -aq --filter reference='dev-peer*') 2>/dev/null || true
}

function createOrgs() {
  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  cryptogen generate --config=./organizations/cryptogen/crypto-config.yaml --output="organizations"
}

function networkUp() {

  if [ ! -d "organizations/peerOrganizations" ]; then
    createOrgs
  fi

  DOCKER_SOCK="${DOCKER_SOCK}" docker-compose -f ${COMPOSE_FILE_BASE} up -d 2>&1

  docker ps -a
}

function createChannel() {
  scripts/createChannel.sh $CHANNEL_NAME
}


function networkDown() {
  
  DOCKER_SOCK=$DOCKER_SOCK docker-compose -f $COMPOSE_FILE_BASE down --volumes --remove-orphans
  startFresh
  docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations'
  docker run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz'
}

COMPOSE_FILE_BASE=docker/docker-compose-test-net.yaml


SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"

MODE=$1
CHANNEL_NAME=$2
 
if [ "$MODE" == "up" ]; then
  networkUp
elif [ "$MODE" == "createChannel" ]; then
  createChannel
elif [ "$MODE" == "down" ]; then
  networkDown
fi


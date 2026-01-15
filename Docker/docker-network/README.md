# Docker Networking

## Bridge Network

```bash
# To View All The Networks
docker network ls

# Inspect Bridge Network
docker network inspect bridge

# Test Container
docker run -d --name nginx-app -p 80:80 nginx:stable-alpine3.23

# Check running container
docker ps

# Inspect docker container
docker inspect nginx-app

# Curl Request
curl localhost:80 

# Test Container
docker run -d --name nginx-app-v2 -p 81:80 nginx:stable-alpine3.23

# Test connection inside docker
docker exec -it nginx-app-v2 sh
# Will work with ip
curl 172.17.0.2
# Not work because dns is not configured in default bridge network
curl nginx-app

# Bridge Network Create
docker network create my-bridge-net --subnet 10.0.0.0/19 --gateway 10.0.0.1

# See Network list
docker network ls

# New Container with custom bridge network
docker run -d --network my-bridge-net -p 82:80 nginx:stable-alpine3.23
docker run -d --network my-bridge-net -p 83:80 nginx:stable-alpine3.23

# View Bridge link
bridge link

# Inspect network
docker inspect bridge
```

## Host Network

```bash
# Create container with host network
docker run --name nginx-host -d --network host nginx:stable-alpine3.23

# Can directly access using host ip
```

## None Network

```bash
# Create container with none network
docker run --name nginx-none -d --network none nginx:stable-alpine3.23

# Not exposed to outside
```

## IPvlan Network

```bash
# Create IPvlan network with l2 version
docker network create -d ipvlan --subnet=172.30.1.0/24 --gateway=172.30.1.1 -o parent=enp1s0 -o ipvlan_mode=l2 my-ipvlan-net

# Create container with IPvlan network with l2 version
docker run --name nginx-ipvlan -d --network my-ipvlan-net nginx:stable-alpine3.23

# The ip of the container will be in the range of the host but mac address will be same

# Create IPvlan network with l3 version
```
## Macvlan Network

```bash
# Create Macvlan network
docker network create -d macvlan --subnet=172.30.1.0/24 --gateway=172.30.1.1 -o parent=enp1s0 my-macvlan-net

# Create container with Macvlan network
docker run --name nginx-macvlan -d --network my-macvlan-net --ip 172.30.1.253 nginx:stable-alpine3.23

# Mac address will be different between the host and the container
# Need promiscuous mode
# No DHCP will be available
```
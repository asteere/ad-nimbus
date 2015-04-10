# Instructions from https://registry.hub.docker.com/_/nginx/
# From: http://nginx.com/blog/deploying-nginx-nginx-plus-docker/

FROM centos:latest

MAINTAINER Andy Steere <andy.steere@troppussoftware.com>

# Install netcat to allow communication with the nginx container via Unix sockets
# From: http://blog.dixo.net/2015/02/load-balancing-with-coreos/
# From: http://blog.dixo.net/2015/02/sending-signals-from-one-docker-container-to-another/
RUN yum -y install nc

# Install dig
RUN yum install bind-utils

# Make the folder accessible by ssh container
VOLUME /usr/share




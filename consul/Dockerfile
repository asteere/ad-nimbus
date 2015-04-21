# Instructions from https://registry.hub.docker.com/_/nginx/
# From: http://nginx.com/blog/deploying-nginx-nginx-plus-docker/

FROM centos:latest

MAINTAINER Andy Steere <andy.steere@troppussoftware.com>

# Consul is already part of the git code. Update as needed
# TODO: Should we be pulling consul as part of the container build or as a separate intentional step?

#EXPOSE 8300 8301 8301/udp 8302 8302/udp 8400 8500 53 53/udp

# Make the folder accessible by ssh container
VOLUME /usr/share




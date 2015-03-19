# Instructions from https://registry.hub.docker.com/_/nginx/
# From: http://nginx.com/blog/deploying-nginx-nginx-plus-docker/

FROM centos:latest

MAINTAINER Andy Steere <andy.steere@troppussoftware.com>

# TODO: Figure out how to get latest from github rather than hardcoding this
RUN mkdir -p /etc/confd
RUN curl -L https://github.com/kelseyhightower/confd/releases/download/v0.8.0/confd-0.8.0-linux-amd64 -o /etc/confd/confd
RUN chmod +x /etc/confd/confd

# Make the folder accessible by ssh container
VOLUME /usr/share




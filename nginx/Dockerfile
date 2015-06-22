# Instructions from https://registry.hub.docker.com/_/nginx/
# From: http://nginx.com/blog/deploying-nginx-nginx-plus-docker/

FROM centos:latest

MAINTAINER Andy Steere <andy.steere@troppussoftware.com>

# Update package manager.
RUN yum update -y

# Set repository for nginx.
COPY ./nginx.repo /etc/yum.repos.d/nginx.repo

# Install nginx.
RUN yum install -y nginx

########################
# TODO: Copy the WebContent Research project
#COPY /Users/troppus/Research/WebContent /usr/share/nginx/html
#######################

RUN rm -v /etc/nginx/conf.d/default.conf
RUN rm -v /etc/nginx/nginx.conf

COPY content /usr/share/nginx/html

# Don't start nginx, let fleetctl do it on coreos startup
#CMD ["nginx", "-g", "daemon off;"]


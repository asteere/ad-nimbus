# Instructions from https://registry.hub.docker.com/_/nginx/
# From: http://nginx.com/blog/deploying-nginx-nginx-plus-docker/

FROM nginx:latest

MAINTAINER Andy Steere <andy.steere@troppussoftware.com>

COPY . /usr/share/nginx/html

RUN rm -v /etc/nginx/conf.d/default.conf
RUN rm -v /etc/nginx/nginx.conf

COPY content /usr/share/nginx/html

# Make these folder accessible by ssh container
VOLUME /usr/share

EXPOSE 80
EXPOSE 443

# Don't start nginx, let fleetctl do it on coreos startup
#CMD ["nginx", "-g", "daemon off;"]


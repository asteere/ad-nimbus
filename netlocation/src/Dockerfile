# Base OS.
FROM centos:latest

# Maintainer.
MAINTAINER Mark Larter <mark@freeheelgroup.com>

# Set repository for nodejs.
RUN curl -sL https://rpm.nodesource.com/setup | bash -

# Install nodejs and npm.
RUN yum install -y nodejs

# Install app dependencies.
RUN npm i maxmind-db-reader

# Copy app source to VM. If you do this, then you need to rebuild the container whenever anything in src changes
#COPY . /src

# Install app.
#RUN cd /src; npm i

# Map port.
EXPOSE 8080

# Define runtime.
#CMD ["node", "/src/index.js"]


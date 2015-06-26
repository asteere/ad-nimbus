FROM python

# From https://registry.hub.docker.com/u/alexturek/aws-cli-docker/
MAINTAINER Andy Steere <andy.steere@troppussoftware.com>

RUN pip install awscli

# Mount point for aws cli credentials and configuration mapped from host instance
VOLUME /root/.aws

# No entry point so that command on the Mac looks like the command passed to docker

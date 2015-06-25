General Architectural principles, design, learnings, etc. picked up along the way

When you create a new service, recommended high-level steps
Build app enough to have something to run
Build docker container
Build script to call docker container
Build fleet service

Services are folder. Implementations.

Block diagram - Firewall, Load Balancer, Reverse Proxy, Apps

Use docker run --expose and -P rather than EXPOSE in the dockerfile as the two pieces of information are closer together (same start script file).

Currently, we are not using the latest tag as it doesn't mean you are getting latest version. Be specific, no suprises and no extra complexity in the build process.
From: http://container-solutions.com/docker-latest-confusion/

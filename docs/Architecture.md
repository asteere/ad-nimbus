General Architectural principles, design, learnings, etc. picked up along the way

Ad-nimbus is an exploration into the technologies available to provide elastic services. We use the term elastic to mean the ability of the production environment (hardware, OS, software, data, processes - disaster recovery, alerts, logging) to respond to increases and decreases in load with minimal operator intervention.

When you create a new service please your life will be easier if you follow these high-level steps
Create enough of your app to have something to put in a container. 
Create your app to be run from the command line. 
Build a docker container with the applications, utilities, etc for your app to run. 
Don''t put your application in the container yet. Use the --volume command to mount it from the host OS.
Create a script to call the docker container
Build fleet service

Following the above steps will make it easier to troubleshoot any problems because you can easily remove complexity to find the problem. Some of the opportunities for complexity are the following:
- User id and pathing (fleet service (root) or ssh (core)
- Additional network stacks, port forwarding, exposed ports 
 
The scripts are built with the assumption that services (netlocation, nginx)  are folders. Implementations of a service are under the service folder. 

The adNimbusEnvironment and *Environment files contain the control variables that are shared between fleetctl services, scripts and the application/services. A grep for the usage of a variable can fail as some of the variables are called via reflection. If  you add such a variable, please document it in the *Environment file for the benefit of future users (including yourself).

TODO: Block diagram - Firewall, Load Balancer, Reverse Proxy, Apps

Use docker run --expose and -P rather than EXPOSE in the dockerfile as the two pieces of information are closer together (same start script file).

Currently, we are not using the "latest" tag since it doesn''t mean you are getting latest version. It only means that you are getting the image with the tag "latest" when you don''t specify a tag. Recommendation: Using specific tags eliminates the opportunity for someone to pull the wrong image. 
From: http://container-solutions.com/docker-latest-confusion/

The behavior of developers (rapid edit/test/commit) vs ops (deploy with the smallest number of steps/test/wait for problems) create two different ways of creating containers
1. Sharing the app and data from the host OS with the container eliminates the need to build the container every time the app changes. The container only has the technology (apps/utils) needed for the app to run (curl, libssl, etc).
2. Bundling the app and the data inside the container makes these entities self-contained reducing opportunities for error. 

This demo hasn''t explored how to automate the transition between the two modes (dev vs ops. We will explore this issue once we get approval for a production version of this demo.

The functions that are expected to be used from the command line are all lower case. This is intentional to make shell completion of file names, functions, etc less ambiguous. For example: is it getIPAddress or getIpAddress.


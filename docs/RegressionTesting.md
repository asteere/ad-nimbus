Regression Testing
# Start the cluster and services (see Installation.md)

# Create an addService file and check that the monitor service adds up to adNimbusEnvironment maxNetLocationServices 
# Note: this can take awhile for the new service to download the container and start.
touch ~/share/addService

while true; do date; fluf; sleep 5; echo; done

# Test that the load balancer is using all the netlocation servies in a round robin fashion.

# To view nginx reloading after confd sends the SIGHUP
tail -f ~/share/nginx/nginx_error.log

# To view nginx redirecting the curl request to the different netlocation service
tail -f ~/share/nginx/nginx_access.log

# Run checkNetLocation to send the netlocation request to nginx.
checkNetLocation

# Remove the addService file, watch the netlocation services decrease to the adNimbusEnvironment minNetLocationServices value.
while true; do date; fluf; sleep 5; echo; done

# The netlocation State and Dstate columns should go from launched to loaded 

# The monitor service will output an Error message if the number of launched instances doesn't match the etcdctl number of netlocation keys. I am uncertain if this is a real issue.

# Once the number of netlocation services launched matches the expected this cycle of the test is complete.

# The next two cycles of the test are to create the addService file, watch the netlocations start to the maximum, nginx continues to load balance, remove addServices, watch the netlocation stop, nginx continues to load balance.

# TODO: Stop the services, verify that the etcdctl keys are correct (etctree)

# TODO: Restart the services and validate that the services are available and working

Known Bugs
If there are no netlocation services, monitor does not start one

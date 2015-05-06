Regression Testing (super high-level and needs review)
# 1.0 Start the cluster and services (see Installation.md)

# 2.0 Validate nginx, netlocation and maxmind are working
checknetlocation

# 3.0 Validate that two netlocations are added when the consul health checks start to fail

# Watch the number of netlocations
mywatch.sh -n .5 "flu | grep netlocation"

# Watch for netlocation services getting added 
fjournal -f monitor@1.service

# Watch confd update nginx/nginx.conf. Look for the output of "grep 172.17.8 nginx/nginx.conf"
fjournal -f confd_nginx@1.service

# Watch nginx round robin. Note it can take up to one minute for the nginx entries to be logged
tail -f nginx/nginx_access.log

# Create a hack failure situation
forceFailures.sh 

# When a new netlocation is added, run checkNetLocation 4 times and validate that the IP address are correct.
# You have about a minute to check before the third netlocation is added.

# 4.0 Watch the number of netlocations go from 3 to 1 using the fjournal, tail and mywatch.sh commands above

# Validate that two netlocation services are removed once the failures are removed. It takes 30+ seconds after the failures
# are cleared for the first netlocation service to be removed.

# Clear the hack failure situation
forceFailures.sh clear

# 5.0 Validate that monitor runOtherChecks detects configuration issues
monitor/monitor.sh runOtherChecks 

# 6.0 Use the consul web api to validate the nodes, services, key/values and health checks are correct

Known Bugs
If there are no netlocation services, monitor does not start one

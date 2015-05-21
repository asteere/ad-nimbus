Regression Testing (super high-level and needs review)
# 1.0 Start the cluster and services (see Installation.md)

# 2.0 Validate nginx, netlocation and maxmind are working
checknetlocation

# This is the sample results
{
  "ipAddress": "198.243.23.131",
  "countryCode": "US",
  "country": "United States",
  "regionCode": "CO",
  "region": "Colorado",
  "city": "Louisville",
  "postal": "80027",
  "lat": 39.9778,
  "lon": -105.1319,
  "timezone": "America/Denver",
  "isp": "CenturyLink"
}

# 2.1 Validate the port forwarding is by running the following on the host machine
checkhostnetlocation

# 2.2 The output of checkhostnetlocation contains the curl command with the correct ip address and port. 
# Run the command on another machine.

# 3.0 Validate that two additional netlocations are added when the consul health checks start to fail

# Watch the number of netlocations. In a CoreOS window run the following:
mywatch.sh -n .5 "flu | grep netlocation"

# Watch for netlocation services getting added and removed. In a CoreOS window run the following:
fjournal -f monitor@1.service

# Watch confd update nginx/nginx.conf. When netlocation creates a consul key, confd will update the nginx.conf file.
tail -f monitor/tmp/startConfd.log

# Create a constant stream of netlocation requests from the host
mywatch.sh -n 1 checkhostnetlocation

# Watch nginx round robin as netlocation services are added and stopped.
# Watch nginx reload the configuration (SIGHUP) whenever a netlocation service is added or stopped. 
# Note it can take up to one minute for the nginx entries to be logged.
tail -f nginx/nginx_access.log nginx/nginx_error.log

# Use the consul web api to validate the nodes, services, key/values and health checks are correct.

# Create a hacked failure situation. In a CoreOS window run the following:
forceFailures.sh 

# 4.0 Watch the number of netlocations go from 3 to 1 using the commands above

# Validate that netlocation services are removed once the failures are removed. It takes 30+ seconds after the failures
# are cleared for the first netlocation service to be removed. It then takes an additional 30+ seconds for the second
# netlocation to be removed.

# Clear the hacked failure situation
forceFailures.sh clear

# 5.0 Validate that monitor runOtherChecks detects configuration issues
monitor/monitor.sh runOtherChecks 

Known Bugs
If there are no netlocation services, monitor does not start one

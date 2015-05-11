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

# 7.0 Test portforwarding from Vagrant to host OS and beyond. 
# 7.1 
# On a coreOs machine, find hostname running nginx. Where core-01 has the IP address 172.17.8.101, core-02 has 102, etc. 
flu | grep nginx | sed -e 's/.*\///' -e 's/\t.*//' 

# On the host machine find out what port vagrant mapped nginx 49160 to. In this example 49160 is mapped to 2201
# grep core-02 /tmp/vup.log | grep 49160
# ==> core-02: Fixed port collision for 49160 => 49160. Now on port 2201.
#     core-02: 49160 => 2201 (adapter 1)
grep "core-XX" /tmp/vup.log | grep 49160

# Get the IP address of the host machine. Ignore the lo0, vbox*. Most likely it is the en1 adapter
ip addr 

# Run a netlocation request with the mapped port, validate the results
export port=<mapped port number>
export ipAddr=localhost; port=$port; curl -X GET  "http://$ipAddr:$port?ipAddress=198.243.23.131"
export ipAddr=<ip addr of host machine>; port=$port; curl -X GET  "http://$ipAddr:$port?ipAddress=198.243.23.131"

# 7.2 On another machine, run the following command replacing the ipAddrs with the ip address running vagrant
export port=<mapped port number>
export ipAddr=<ip addr of host machine>; port=$port; curl -X GET  "http://$ipAddr:$port?ipAddress=198.243.23.131"

Known Bugs
If there are no netlocation services, monitor does not start one

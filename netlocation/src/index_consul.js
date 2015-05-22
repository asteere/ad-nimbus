// Dependencies.
var express = require('express');
var geoReader = require('maxmind-db-reader');

// TODO: Remove when we don't need the delay for debugging/testing
var fs = require('fs');
var hostAddress = process.argv[2];
var instance = process.argv[3];
console.log('NodeJs instance ' + instance + ' is running on ' + hostAddress); // 10.25.10.147
var spawn = require('child_process').spawn;

// Constants.
var SERVICE = "netLocation";
var PORT = 8080;

// Initialize MaxMind geo-location data.
var countryDb = geoReader.openSync(__dirname + '/data/maxMind/GeoIP2-City.mmdb');
var ispDb = geoReader.openSync(__dirname + '/data/maxMind/GeoIP2-ISP.mmdb');

// Print the result

// Create service.
var app = express();

// Define routes.
app.get('/', function(request, response) {
    msg = "Error: better path needs to be defined. path=" + request.path;

    console.error(msg);

    response.status(500).send(msg);
});

app.get('/api/v1/netlocation/*', function(request, response) {
    // Get IP address for lookup. First check query params, use request IP if
    // query param not specified.
    console.log("path=" + request.path);
    var ipAddress = request.path.split('/').pop();;
    console.log('Request ipAddress: ' + ipAddress);
    if (!ipAddress) ipAddress = request.ip;
    console.log('Request ipAddress: ' + ipAddress);
        
    // Lookup geo-location for specified IP.
    var geoData = { "ipAddress" : ipAddress };
    var countryData = null;
    var ispData = null;
    countryDb.getGeoData(ipAddress, function(err, countryData) {
        // Do something about err.
        if (err) {
            console.log('err: ' + err);
            geoData.errorCountry = err;
        }
        else {
            // Append country data.
            appendCountry(geoData, countryData);
        }
                         
        // Lookup ISP for specified IP.
        ispDb.getGeoData(ipAddress, function(err, ispData) {
            // Do something about err.
            if (err) {
                console.log('err: ' + err);
                geoData.errorIsp = err;
            }
            else {
                // Append ISP data.
                appendIsp(geoData, ispData);
            }

            // HACK: look for the file for this service that indicates how long the response should be delayed
            // HACK: This hack creates an external test failure since if delays the response time
            var path = "/opt/tmp/external/netlocation@" + instance + ".service_" + hostAddress + ".cfg";
            console.log("Attempting to read file: " + path);
            var delay = 0;
            try {
                delay = fs.readFileSync(path, "utf8", function(err, data) {
                    if (err) {
                        console.log("Error reading file:" + path + " Err: " + err);
                        return;
                    }
                });
                delay = parseInt(delay) * 1000;
            } catch (err) {
                if (err.toString().indexOf("ENOENT, no such file or directory") <= -1) {
                    console.log("Error reading file path: " + path + " Err: " + err);
                }
                delay=0;
            }
            
            console.log("Delay this response by " + delay + " mSecs. Date: " + new Date());
            setTimeout(function () {
                console.log("Done waiting Date: " + new Date());
                response.send(geoData);
            }, delay);
        });
    });
});

// Listen.
app.listen(PORT);
console.log(SERVICE + ' running on port ' + PORT);

// Function to append country data to response payload.
function appendCountry(geoData, countryData) {
    if (countryData) {
        // Country.
        var country = countryData.country;
        if (country) {
            geoData.countryCode = country.iso_code;
            var names = country.names;
            if (names) {
                geoData.country = names["en"];
            }
        }
        
        // State.
        var subdivisions = countryData.subdivisions;
        if (subdivisions) {
            var subdivision = subdivisions[0];
            if (subdivision) {
                geoData.regionCode = subdivision.iso_code;
                names = subdivision.names;
                if (names) {
                    geoData.region = names["en"];
                }
            }
        }
        
        // City.
        var city = countryData.city;
        if (city) {
            names = city.names;
            if (names) {
                geoData.city = names["en"];
            }
        }
        
        // Postal.
        var postal = countryData.postal;
        if (postal) {
            geoData.postal = postal.code;
        }
        
        // Location.
        var location = countryData.location;
        if (location) {
            geoData.lat = location.latitude;
            geoData.lon = location.longitude;
            geoData.timezone = location.time_zone;
        }
    }
}

// Function to append ISP data to response payload.
function appendIsp(geoData, ispData) {
    if (ispData) {
        if (ispData.isp) {
            geoData.isp = ispData.isp;
        }
    }
}

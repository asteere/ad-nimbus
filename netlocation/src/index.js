// Dependencies.
var express = require('express');
var geoReader = require('maxmind-db-reader');

// Constants.
var SERVICE = "netLocation";
var PORT = 8080;

// Initialize MaxMind geo-location data.
var countryDb = geoReader.openSync(__dirname + '/data/maxMind/GeoIP2-City.mmdb');
var ispDb = geoReader.openSync(__dirname + '/data/maxMind/GeoIP2-ISP.mmdb');

// Create service.
var app = express();

// Define routes.
app.get('/', function(request, response) {
    // Get IP address for lookup. First check query params, use request IP if
    // query param not specified.
    var ipAddress = request.query.ipAddress;
    console.log('ipAddress: ' + ipAddress);
    if (!ipAddress) ipAddress = request.ip;
    console.log('ipAddress: ' + ipAddress);
        
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
                         
            response.send(geoData);
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

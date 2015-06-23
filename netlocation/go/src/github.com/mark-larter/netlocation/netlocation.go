package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/oschwald/maxminddb-golang"
)

var dbGeo, dbIsp *maxminddb.Reader

func main() {
	// Set up MaxMind databases.
	var err error
	dbGeo, err = openDb("/data/maxMind/GeoIP2-City.mmdb")
	if (err != nil || dbGeo == nil) {
  		log.Panic(err)
	}
	defer dbGeo.Close()
	dbIsp, err = openDb("/data/maxMind/GeoIP2-ISP.mmdb")
	if (err != nil || dbIsp == nil) {
  		log.Panic(err)
	}
	defer dbIsp.Close()

	// Start http server.
	fmt.Println("Starting http server")
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}

func handler(w http.ResponseWriter, r *http.Request) {
	// Get specified IP address for geo-location lookup.
    slicedUrl := strings.Split(r.URL.Path[1:], "/")
	ipAddress := slicedUrl[len(slicedUrl)-1]

	// If no IP address specified, get the requestor IP address.
	if (len(ipAddress) == 0 || len(strings.TrimSpace(ipAddress)) == 0) {
		ipAddress, _, _ = net.SplitHostPort(r.RemoteAddr)
//		requestorIp := r.Header.Get("x-forwarded-for")
	}

	netLocation := getInfo(ipAddress)
	outInfo, _ := json.Marshal(netLocation)
	fmt.Fprint(w, string(outInfo))
}

func openDb(dbPath string) (*maxminddb.Reader, error) {
	path, err := filepath.Abs(dbPath)
	if err != nil {
		return nil, err
	}
	db, err := maxminddb.Open(path)
	if err != nil {
		return nil, err
	}
	return db, err
}

func getInfo(ipAddress string) (*NetLocation) {
	fmt.Println("ipAddress: " + ipAddress)
	netLocation := &NetLocation{
        IpAddress: ipAddress}
 	ip := net.ParseIP(ipAddress)
	if (ip != nil) {
		// Get geo-location data.
		geoData, err := getGeo(ip)
		if (err != nil) {
			log.Print(err)
		} else {
			const language string = "en"
			netLocation.City = geoData.City.Names[language]
			netLocation.CountryCode = geoData.Country.IsoCode
			netLocation.Country = geoData.Country.Names[language]
			subdivisions := geoData.Subdivisions
			if (len(subdivisions) > 0) {
				subdivision := subdivisions[0]
				netLocation.RegionCode = subdivision.IsoCode
				netLocation.Region = subdivision.Names[language]
			}
			netLocation.Lat = geoData.Location.Latitude
			netLocation.Lon = geoData.Location.Longitude
			netLocation.Timezone = geoData.Location.Timezone
			netLocation.Postal = geoData.Postal.Code
		}
		
		// Get ISP data.
 		ispData, err := getIsp(ip)
 		if (err != nil) {
			log.Print(err)
		} else {
 			netLocation.Isp = ispData.Name
 		}
    }
    return netLocation
}

func getGeo(ip net.IP) (*geoData, error) {
	var record geoData
	err := dbGeo.Lookup(ip, &record)
	if err != nil {
		return nil, err
	}
	return &record, err
}

func getIsp(ip net.IP) (*ispData, error) {
	var record ispData
	err := dbIsp.Lookup(ip, &record)
	if err != nil {
		return nil, err
	}
	return &record, err
}

func getMaxmind(ip net.IP, db *maxminddb.Reader, record interface{}) error {
	err := db.Lookup(ip, &record)
	return err
}

type geoData struct {
	City struct {
		Names map[string]string `maxminddb:"names"`
	} `maxminddb:"city"`
	Country struct {
		IsoCode string `maxminddb:"iso_code"`
		Names map[string]string `maxminddb:"names"`
	} `maxminddb:"country"`
	Location struct {
		Latitude float64 `maxminddb:"latitude"`
        Longitude float64 `maxminddb:"longitude"`
        Timezone string `maxminddb:"time_zone"`
	} `maxminddb:"location"`
    Postal struct {
		Code string `maxminddb:"code"`
    } `maxminddb:"postal"`
	Subdivisions []struct {
		IsoCode string `maxminddb:"iso_code"`
		Names map[string]string `maxminddb:"names"`
	} `maxminddb:"subdivisions"`
}

type ispData struct {
	Name string `maxminddb:"isp"`
}

type NetLocation struct {
    IpAddress string `json:"ipAddress,omitempty"`
    CountryCode string `json:"countryCode,omitempty"`
    Country string `json:"country,omitempty"`
    RegionCode string `json:"regionCode,omitempty"`
    Region string `json:"region,omitempty"`
    City string `json:"city,omitempty"`
    Postal string `json:"postal,omitempty"`
    Lat float64 `json:"lat,omitempty"`
    Lon float64 `json:"lon,omitempty"`
    Timezone string `json:"timezone,omitempty"`
    Isp string `json:"isp,omitempty"`
}

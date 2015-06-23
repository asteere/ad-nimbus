var express = require('express');

// Constants
var PORT = 8080;

// From: 
var os = require('os');
var ifaces = os.networkInterfaces();
var ipAddress = "";

console.log("after networkInterfaces os.hostname: " + os.hostname() + " call ifaces: " + JSON.stringify(ifaces));

Object.keys(ifaces).forEach(function (ifname) {
console.log("begin forEach " + ifname + " ipAddress: " + ipAddress);

  var alias = 0;

  ifaces[ifname].forEach(function (iface) {
    if ('IPv4' !== iface.family || iface.internal !== false) {
      // skip over internal (i.e. 127.0.0.1) and non-ipv4 addresses
      return;
    }

    if (alias >= 1) {
      // this single interface has multiple ipv4 addresses
      console.log(ifname + ':' + alias + ' iface.address: ' +  iface.address);
    } else {
      // this interface has only one ipv4 adress
      console.log(ifname + ':' + alias + ' iface.address: ' +  iface.address);
    }
    ipAddress += iface.address + ", ";
  });
  ipAddress += ':' + PORT;

console.log("end forEach " + ifname + " ipAddress: " + ipAddress);
});

console.log(" after Object.keys ipAddress: " + ipAddress);

// App
var app = express();
app.get('/', function (req, res) {
  var msg = 'NODEJS: Requestor: ' + req.socket.localAddress + ' hostname: ' + os.hostname() + ' Responder:' + ipAddress + ' ' + new Date() + '\n';
  res.send(msg);
  console.log(msg);
});

app.listen(PORT);
console.log(new Date() + ' Running on host ' + os.hostname() + ' http://' + ipAddress);

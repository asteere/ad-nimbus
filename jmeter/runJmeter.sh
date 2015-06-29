#! /bin/bash

# Note: Conversion error com.thoughtworks.xstream.converters.ConversionException: is generally due to missing jmeter plugin libs
# From: http://stackoverflow.com/questions/25759977/conversion-error-when-opening-jmx-file-from-jmeter-2-7-in-jmeter-2-11

os=`uname -s`
if test "$os" = "Darwin"
then
    JMETER_HOME=/usr/local/Cellar/jmeter/2.13/libexec
    JMETER_TESTS="$adNimbusDir/jmeter"
else
    JMETER_HOME=/d/3rdparty/apache-jmeter-2.13
    JMETER_TESTS=/d/raptor/Automation/JMeter/913_LoadTests
fi

# TODO: Is the following useful?
# Get the log files to dump into the same folder to make it easier to find
cd "$JMETER_TESTS"

export JVM_ARGS="-Xms12G -Xmx12G" 
if test "$1" = "server"
then
    export JMETER_EXEC=jmeter-server
    "${JMETER_HOME}/bin/${JMETER_EXEC}" &
else
    export TEST_FILE="${JMETER_TESTS}"/NetLocation\ Load\ Test.jmx 
    # -Jremote_hosts=127.0.0.1,10.188.189.136

    # Have jMeter tell the slaves to connect to “localhost:51000″ for delivering their results. 
    # This of course ends up being tunneled back to your jMeter master machine.
    # From: https://rolfje.wordpress.com/2012/02/16/distributed-jmeter-through-vpn-and-ssl/
    #export JVM_ARGS="$JVM_ARGS -Djava.rmi.server.hostname=localhost"

    "${JMETER_HOME}/bin/jmeter" -Djava.rmi.server.hostname=localhost -Jclient.rmi.localport=60000 -t "${TEST_FILE}" -l jmeter_client_Samples.log -j jmeter_client.log $* 2>&1 > jmeter_client_SummaryResults.log & 
fi

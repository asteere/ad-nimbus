#! /bin/bash

os=`uname -s`
if test "$os" = "Darwin"
then
    JMETER_HOME=/usr/local/Cellar/jmeter/2.12/libexec
    JMETER_TESTS="$VAGRANT_CWD/LoadTests/JMeter"
else
    JMETER_HOME=/d/3rdparty/apache-jmeter-2.12
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
    export JMETER_EXEC=jmeter
    export TEST_FILE="${JMETER_TESTS}"/NetLocation\ Load\ Test.jmx 
    # -Jremote_hosts=127.0.0.1,10.188.189.136
    "${JMETER_HOME}/bin/${JMETER_EXEC}" -t "${TEST_FILE}" $* 2>&1 > jmeterSummaryResults.log & 
fi


#!/bin/bash

source props.sh

dnf install -y procps-ng net-tools

# sample cpu/memory every 30 seconds, for about 60 hours (really until end of job run), write to console in background, kill any currently running sar commands, so we don't clutter console too much
#killall sar || true
#sar -r -u -d -b 30 14400 &

# export PATH=$NATIVE_TOOLS/$JAVA18/bin:$PATH
# which java
# java -version

export TCK_HOME_DIR=$PWD

function createReport() {
    echo "skipping create report"

    cd $TS_HOME/bin
    java -verbose -Xint -cp javatest.jar:jh.jar:$TS_HOME/lib/tsharness.jar com.sun.javatest.cof.Main -o report.xml /tmp/JTwork &> tmp_log
    cp -r /tmp/JTwork $TCK_HOME_DIR
    cp -r /tmp/JTreport $TCK_HOME_DIR
    echo "show contents of tmp + jtwork + jtreport folders"
}
###################################
# Set up the archiving of results, logs, etc.
###################################
function copy_logs() {
   set +e

   createReport

   echo "copy logs"
   if [ -f "$JBOSS_HOME/appclient/log/server.log" ]; then
      cp --backup=existing --suffix=appclient_  $JBOSS_HOME/appclient/log/server.log $TCK_HOME_DIR/logs/appclientserver.log
   fi
   if [ -f "$JBOSS_HOME/standalone/log/server.log" ]; then
      cp --backup=existing $JBOSS_HOME/standalone/log/*server*.log $TCK_HOME_DIR/logs
   fi
   if [ -f "$JAVAEE_HOME_RI/domains/domain1/logs/server.log" ]; then
      cp --backup=existing --suffix=glassfish_ $JAVAEE_HOME_RI/domains/domain1/logs/server.log $TCK_HOME_DIR/logs
   fi
   echo "done copying logs"
   stopall
}
trap "{ copy_logs; }" EXIT INT QUIT TERM

stopall() {

   echo "stop all launched background processes"
   if [[ -n "$RI_STARTED" ]]; then
      $JAVAEE_HOME_RI/bin/asadmin stop-domain
   fi

   if [[ "$CTS_DB" == javadb ]]; then
      cd $DERBY_HOME/bin
      sh stopNetworkServer &> /dev/null &
   fi
   echo "stop wildfly"
   kill_jboss7
   echo "stop derby db"
   kill_derby
   echo "stop rmiiop server"
   kill_rmiiiopserver
   echo "stop glassfish"
   kill_glassfish
   echo "stop glassfish again"
   kill_sunri
   echo "stopped all..."
}

function kill_sunri {
 (
    ps -eaf --columns 5000 | grep 'J2EE 1.4 Server' | grep -v grep | awk '{ print $2; }' | xargs kill &> /dev/null
    ps -eaf --columns 5000 | grep 'J2EE 1.4 Server' | grep -v grep | awk '{ print $2; }' | xargs kill -9 &> /dev/null
    ps -eaf --columns 5000 | grep imqbroker | grep -v grep | awk '{ print $2; }' | xargs kill &> /dev/null
    ps -eaf --columns 5000 | grep imqbroker | grep -v grep | awk '{ print $2; }' | xargs kill -9 &> /dev/null
 ) || return 0
}


function kill_glassfish {
 (
    ps -eaf --columns 20000 | grep com.sun.enterprise.admin.server.core.jmx.AppServerMBeanServerBuilder | grep -v grep | awk '{ print $2; }' | xargs kill &> /dev/null
    ps -eaf --columns 20000 | grep com.sun.enterprise.admin.server.core.jmx.AppServerMBeanServerBuilder | grep -v grep | awk '{ print $2; }' | xargs kill -9 &> /dev/null
    jps -l | grep com.sun.enterprise.glassfish.bootstrap.ASMain | grep -v grep | awk '{ print $1; }' | xargs kill &> /dev/null
    jps -l | grep com.sun.enterprise.glassfish.bootstrap.ASMain | grep -v grep | awk '{ print $1; }' | xargs kill -9 &> /dev/null
 ) || return 0
}

function kill_rmiiiopserver {
 (
    ps -eaf --columns 12000 | grep RMIIIOPServer | grep -v grep | awk '{ print $2; }' | xargs kill &> /dev/null
    ps -eaf --columns 12000 | grep start.rmiiiop.server | grep -v grep | awk '{ print $2; }' | xargs kill &> /dev/null
 ) || return 0
}

function kill_derby {
 (
    ps -eaf --columns 2200 | grep org.apache.derby.drda.NetworkServerControl | grep -v grep | awk '{ print $2; }' | xargs kill &> /dev/null
    ps -eaf --columns 2200 | grep org.apache.derby.drda.NetworkServerControl | grep -v grep | awk '{ print $2; }' | xargs kill -9 &> /dev/null
 ) || return 0
}

function kill_jboss7 {
 (
  if [[ `uname -s` == 'Linux' ]]; then
   local PS='ps -eaf --columns 20000 | grep jboss-modules.jar | grep -v -w grep | awk '\''{ print $2; }'\'
   eval "$PS" | xargs kill -3 &> /dev/null
   sleep 1
   eval "$PS" | xargs kill &> /dev/null
   sleep 10
   eval "$PS" | xargs kill -9 &> /dev/null
  elif lsof -i TCP:8080 &> /dev/null; then
    local LSOF='lsof -t -i TCP:8080,8443,1099,1098,4444,4445,1093,1701'
    kill -3 `$LSOF` &> /dev/null
    sleep 1
    kill `$LSOF` &> /dev/null
    sleep 10
    kill -9 `$LSOF` &> /dev/null
  elif netstat -an | findstr LISTENING | findstr :8080 ; then
    netstat -aon | findstr LISTENING | findstr :8080 > tmp.txt
    cmd \/C FOR \/F "usebackq tokens=5" %i in \(tmp.txt\) do taskkill /F /T /PID %i
    rm tmp.txt
  elif jps &>/dev/null; then
    local PS='jps | grep jboss-modules.jar | grep -v -w grep | awk '\''{ print $1; }'\'

    case "`uname`" in
      CYGWIN*)
        jps | grep jboss-modules.jar | grep -v -w grep | awk '{print $1}'
        for i in `jps | grep jboss-modules.jar | grep -v -w grep | awk '{print $1}'`; do
           taskkill /F /T /PID $i;
        done
        ;;
      *)
        eval "$PS" | xargs kill -3 &> /dev/null
        sleep 1
        eval "$PS" | xargs kill &> /dev/null
        sleep 10
        eval "$PS" | xargs kill -9 &> /dev/null
        ;;
    esac

  else
    echo Not yet supported on `uname -s` UNIX favour without working lsof.
    return 1
  fi
 ) || return 0
}

echo $appserverconfig

rm -rf /tmp/JTwork
rm -rf /tmp/JTreport
mkdir -p /tmp/JTwork
mkdir -p /tmp/JTreport
stopall

WGET='wget -q --no-check-certificate'
SVN='svn --non-interactive --trust-server-cert'


unzip wildfly.zip > /dev/null && rm -f wildfly.zip
mv wildfly-* wildfly || true

if [ ! -f "glassfish.zip" ]
then
  echo "failed: glassfish.zip is missing, cannot run standalone JAXWS TCK tests"
  exit 1
fi
unzip -o glassfish.zip > /dev/null && rm -f glassfish.zip

echo "using glassfish.version:"
cat glassfish.version
echo "using glassfish.cksum:"
cat glassfish.cksum

# get tck
curl -k https://download.eclipse.org/jakartaee/xml-web-services/2.3/jakarta-xml-ws-tck-2.3.0.zip -o jakarta-xml-ws-tck-2.3.0.zip
unzip -o jakarta-xml-ws-tck-2.3.0.zip > /dev/null && rm -f jakarta-xml-ws-tck-2.3.0.zip
mv xml-ws-tck javaeetck
mkdir -p $TCK_HOME_DIR/logs
ls

if [[ -z $JBOSS_HOME ]]; then
  export JBOSS_HOME=$PWD/wildfly
  export JBOSS_HOME=`echo $JBOSS_HOME`
fi

export TS_HOME=$PWD/javaeetck

# need to setup ant, since ant is no longer in $TS_HOME/tools/ant
#$WGET https://www-us.apache.org/dist//ant/binaries/apache-ant-1.10.6-bin.zip
curl -k https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.6-bin.zip -o apache-ant-1.10.6-bin.zip
unzip -o apache-ant-1.10.6-bin.zip > /dev/null && rm -f apache-ant-1.10.6-bin.zip
export ANT_HOME=$PWD/apache-ant-1.10.6
curl -k https://repo1.maven.org/maven2/ant-contrib/ant-contrib/1.0b3/ant-contrib-1.0b3.jar -o ant-contrib-1.0b3.jar
# $WGET http://central.maven.org/maven2/ant-contrib/ant-contrib/1.0b3/ant-contrib-1.0b3.jar
mv ant-contrib-1.0b3.jar "$ANT_HOME/lib"

export JEETCK_MODS=$PWD/javaeetck/tckmods
export JAVAEE_HOME=$JBOSS_HOME
export JAVAEE_HOME_RI=$PWD/glassfish5/glassfish
export DERBY_HOME=$JAVAEE_HOME_RI/../javadb
ANT_OPTS="$ANT_OPTS -Xmx512M"
export ANT_OPTS="$ANT_OPTS -Djava.endorsed.dirs=${JAVAEE_HOME_RI}/modules/endorsed"
export PATH=$TS_HOME/bin:$ANT_HOME/bin:$PATH
echo "testFolder=$testFolder"
echo TS_HOME = $TS_HOME
echo JBOSS_HOME = $JBOSS_HOME
echo JAVAEE_HOME = $JAVAEE_HOME
echo JAVAEE_HOME_RI = $JAVAEE_HOME_RI
echo DERBY_HOME = $DERBY_HOME
echo JAVA_HOME = $JAVA_HOME
echo ANT_HOME = $ANT_HOME
echo $PATH

# get tck configuration files and copy into /javaeetck/tckmods
# TODO: eliminate assumptions that tckmods is under javaeetck, so we don't need to copy it
if [ ! -d "tckmods" ]
then
  echo "failed: tckmods folder is missing, cannot run standalone JAXWS TCK tests"
  exit 1
fi
cp -r tckmods $JEETCK_MODS
cd $JEETCK_MODS

pwd
ls
echo jboss.home=$JBOSS_HOME > ant.properties
echo ts.home=$TS_HOME >> ant.properties
echo javaee.home=$JBOSS_HOME >> ant.properties
echo javaee.home.ri=$JAVAEE_HOME_RI >> ant.properties

ant

#configure VI
cd $TS_HOME/bin
ant config.vi

#start up RI
cd $TS_HOME/bin
ant config.ri

JBOSS_OPTS=""
if [[ "$testFolder" == connector ]]; then
   JBOSS_OPTS="$JBOSS_OPTS -P file:///$JBOSS_HOME/bin/jca-tck-properties.txt"
fi

JAVA_OPTS="-noSecurityManager -Xms512m -Xmx800m -XX:MaxPermSize=512m -Xss1m -XX:+HeapDumpOnOutOfMemoryError -XX:-UseGCOverheadLimit -Dtest.ejb.stateful.timeout.wait.seconds=70 -Djava.net.preferIPv4Stack=true -Dorg.jboss.resolver.warning=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
JAVA_OPTS="$JAVA_OPTS -Djboss.modules.system.pkgs=$JBOSS_MODULES_SYSTEM_PKGS -Djava.awt.headless=true"

echo "startup appserver"
cd $JBOSS_HOME/bin
echo "run: ./standalone.sh  -Dee8.preview.mode=true $SECURITY_MANAGER_OPTION $JBOSS_OPTS"
./standalone.sh $JBOSS_OPTS& > /dev/null

sleep 30

# pool until app server listening port is open
NUM="0"
echo "check if appserver is listening on port 9990"
while [[ $(netstat -an | grep -c ':9990') = 0 ]]; do
NUM=$[$NUM + 1]
if (("$NUM" > "30")); then
    echo "Application server isn't listening on port 9999, we waited long enough, try to proceed and see if testing happens to work"
    netstat -an

    break
else
    echo "sleep 10 seconds and check app server port again"
fi
sleep 10
done
echo "app server started"

cd $TS_HOME/src/com/sun/ts/tests/jaxws
ant -Dbuild.vi=true clean build
ant clean build
ant deploy

if [[ ! -z "$testFolder" && "$testFolder" != "" ]]; then
  cd "$testFolder"
fi
ant runclient $runclientArgs

echo "ant runclient finished, time to clean up..."


dnf install -y wget

source props.sh

# export PATH=$NATIVE_TOOLS/$JAVA18/bin:$PATH
which java
java -version

if [[ -n "$customWorkspaceName" ]]; then
  export customWorkspaceName="standalonewebsocket"
fi  

echo "customWorkspaceName=$customWorkspaceName"
export TCK_HOME_DIR=$PWD

###################################
# Set up the archiving of results, logs, etc.
###################################
function copy_logs() {
   if [ -d "$JBOSS_HOME/appclient/log/" ]; then
      cp $JBOSS_HOME/appclient/log/*.log $TCK_HOME_DIR/logs
   fi
   if [ -d "$JBOSS_HOME/standalone/log/" ]; then
      cp --backup=existing --suffix=appclient_ $JBOSS_HOME/standalone/log/*.log $TCK_HOME_DIR/logs
   fi
}
trap "{ copy_logs; }" EXIT INT QUIT TERM

function runtck7 {
 (
     ant $RUNCLIENT_OPTS runclient
 ) || return 0
}

function runejb3tck6 {
 (
     ant $RUNCLIENT_OPTS -Dmultiple.tests="com/sun/ts/tests/ejb30/assembly com/sun/ts/tests/ejb30/bb com/sun/ts/tests/ejb30/misc com/sun/ts/tests/ejb30/sec com/sun/ts/tests/ejb30/tx com/sun/ts/tests/ejb30/zombie com/sun/ts/tests/ejb30/timer com/sun/ts/tests/ejb30/lite com/sun/ts/tests/ejb30/webservice" runclient
 ) || return 0
}

function runjpaentitytck7 {
 (
     ant $RUNCLIENT_OPTS -Dmultiple.tests="com/sun/ts/tests/jpa/core/EntityGraph com/sun/ts/tests/jpa/core/entityManager com/sun/ts/tests/jpa/core/entityManager2 com/sun/ts/tests/jpa/core/entityManagerFactory com/sun/ts/tests/jpa/core/entityManagerFactoryCloseExceptions com/sun/ts/tests/jpa/core/entitytest com/sun/ts/tests/jpa/core/entityTransaction" runclient
 ) || return 0
}


function runjpamisctck7 {
 (
     ant $RUNCLIENT_OPTS -Dmultiple.tests="com/sun/ts/tests/jpa/core/annotations com/sun/ts/tests/jpa/core/basic com/sun/ts/tests/jpa/core/cache com/sun/ts/tests/jpa/core/callback com/sun/ts/tests/jpa/core/convert com/sun/ts/tests/jpa/core/enums com/sun/ts/tests/jpa/core/exceptions com/sun/ts/tests/jpa/core/inheritance com/sun/ts/tests/jpa/core/lock com/sun/ts/tests/jpa/core/nestedembedding com/sun/ts/tests/jpa/core/override com/sun/ts/tests/jpa/core/persistenceUtil com/sun/ts/tests/jpa/core/persistenceUtilUtil com/sun/ts/tests/jpa/core/relationship com/sun/ts/tests/jpa/core/types com/sun/ts/tests/jpa/core/versioning" runclient
 ) || return 0
}

stopall() {
   ###################################
   # Teardown Environment
   ##################################
   if [[ -n "$RI_STARTED" ]]; then
      $JAVAEE_HOME_RI/bin/asadmin stop-domain
   fi

   if [[ "$CTS_DB" == javadb ]]; then
      cd $DERBY_HOME/bin
      sh stopNetworkServer &> /dev/null & 
   fi

   kill_jboss7
   kill_derby
   kill_rmiiiopserver
   kill_glassfish
   kill_sunri
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
    ps -eaf --columns 20000 | grep com.sun.enterprise.admin.server.core.jmx.AppServerMBeanServerBuilder | grep -v grep | awk '{ print $2; }' | xargs kill
    ps -eaf --columns 20000 | grep com.sun.enterprise.admin.server.core.jmx.AppServerMBeanServerBuilder | grep -v grep | awk '{ print $2; }' | xargs kill -9
    jps -l | grep com.sun.enterprise.glassfish.bootstrap.ASMain | grep -v grep | awk '{ print $1; }' | xargs kill
    jps -l | grep com.sun.enterprise.glassfish.bootstrap.ASMain | grep -v grep | awk '{ print $1; }' | xargs kill -9
 ) || return 0
}

function kill_rmiiiopserver {
 (
    ps -eaf --columns 12000 | grep RMIIIOPServer | grep -v grep | awk '{ print $2; }' | xargs kill
    ps -eaf --columns 12000 | grep start.rmiiiop.server | grep -v grep | awk '{ print $2; }' | xargs kill
 ) || return 0
}

function kill_derby {
 (
    ps -eaf --columns 2200 | grep org.apache.derby.drda.NetworkServerControl | grep -v grep | awk '{ print $2; }' | xargs kill
    ps -eaf --columns 2200 | grep org.apache.derby.drda.NetworkServerControl | grep -v grep | awk '{ print $2; }' | xargs kill -9
 ) || return 0
}

function kill_jboss7 {
 (
  if [[ `uname -s` == 'Linux' ]]; then
   local PS='ps -eaf --columns 20000 | grep jboss-modules.jar | grep -v -w grep | awk '\''{ print $2; }'\'
   eval "$PS" | xargs kill -3
   sleep 1
   eval "$PS" | xargs kill
   sleep 10
   eval "$PS" | xargs kill -9
  elif lsof -i TCP:8080 &> /dev/null; then
    local LSOF='lsof -t -i TCP:8080,8443,1099,1098,4444,4445,1093,1701'
    kill -3 `$LSOF`
    sleep 1
    kill `$LSOF`
    sleep 10
    kill -9 `$LSOF`
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
        eval "$PS" | xargs kill -3
        sleep 1
        eval "$PS" | xargs kill
        sleep 10
        eval "$PS" | xargs kill -9
        ;;
    esac

  else
    echo Not yet supported on `uname -s` UNIX favour without working lsof.
    return 1
  fi
 ) || return 0
}

echo $appserverconfig

stopall

WGET='wget -q --no-check-certificate'

$WGET https://download.eclipse.org/jakartaee/websocket/1.1/jakarta-websocket-tck-1.1.1.zip
unzip -qo jakarta-websocket-tck-1.1.1.zip
mv websocket-tck websockettck
export TS_HOME=$PWD/websockettck
ls $TS_HOME

# copy ts.jte.wildfly file into tck bin folder
cp ts.jte.wildfly $TS_HOME/bin/

rm -rf wildfly
unzip wildfly.zip > /dev/null && rm -f wildfly.zip
rm -rf modules
mv wildfly-* wildfly || true

if [[ -z $JBOSS_HOME ]]; then
  export JBOSS_HOME=$PWD/wildfly
  export JBOSS_HOME=`echo $JBOSS_HOME`
fi

# $WGET https://www-us.apache.org/dist/ant/binaries/apache-ant-1.10.6-bin.zip
$WGET https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.6-bin.zip
unzip -o apache-ant-1.10.6-bin.zip > /dev/null && rm -f apache-ant-1.10.6-bin.zip
export ANT_HOME=$PWD/apache-ant-1.10.6

#$WGET http://central.maven.org/maven2/ant-contrib/ant-contrib/1.0b3/ant-contrib-1.0b3.jar
$WGET https://repo1.maven.org/maven2/ant-contrib/ant-contrib/1.0b3/ant-contrib-1.0b3.jar
mv ant-contrib-1.0b3.jar "$ANT_HOME/lib"

export JAVAEE_HOME=$JBOSS_HOME
export JAVAEE_HOME_RI=$PWD/glassfish4/glassfish
export DERBY_HOME=$JAVAEE_HOME_RI/../javadb
ANT_OPTS="$ANT_OPTS -Xmx512M"
export ANT_OPTS="$ANT_OPTS -Djava.endorsed.dirs=${JAVAEE_HOME_RI}/modules/endorsed"
export PATH=$TS_HOME/bin:$ANT_HOME/bin:$PATH
echo TS_HOME = $TS_HOME
echo JBOSS_HOME = $JBOSS_HOME
echo JAVAEE_HOME = $JAVAEE_HOME
echo JAVAEE_HOME_RI = $JAVAEE_HOME_RI
echo DERBY_HOME = $DERBY_HOME
echo JAVA_HOME = $JAVA_HOME
echo ANT_HOME = $ANT_HOME
echo $PATH

RUNCLIENT_OPTS="-Dfailonerror=false"
if [[ -n "${SINGLE_TEST}" ]]; then
   RUNCLIENT_OPTS="${RUNCLIENT_OPTS} -Dtest=${SINGLE_TEST}"
fi

################################
# configure server configuration
################################
echo "modifying server configuration"
cd $JBOSS_HOME/standalone/configuration
sed "s%buffer-pool name=\"default\"%buffer-pool name=\"default\" direct-buffers=\"false\"%" -i standalone.xml

JEE7TCK_MODS_OPTS=""

###################################
# configure TCK
###################################
getArtifactName() {
  local filter="${1}"
  local patchHistory="${2}"

  jarFiles=$(find -name "${filter}")
  for version in $patchHistory; do
    selectedJarFile=$(echo "${jarFiles}" | grep "${version}" || true)
    if [[ "${selectedJarFile}x" != "x" ]]; then
      echo "${selectedJarFile}" | sed "s|^\\./||g"
      return 0
    fi
  done
  echo "${jarFiles}" | sed "s|^\\./||g"
  return 0
}

cd $JBOSS_HOME
patchHistory=$(./bin/jboss-cli.sh  --command="patch history" | grep -o "patch-id\"[^\"]*\"[^\"]*" | grep -o "[^\"]*$" || true)
echo "patchHistory in provided server:\n${patchHistory}\n"

websocketapi=$(getArtifactName jboss-websocket-api_1.1_spec*.jar "${patchHistory}")
websocketimpl=$(getArtifactName undertow-websockets-jsr*.jar "${patchHistory}")
webservlet=$(getArtifactName undertow-servlet*.jar "${patchHistory}")
webcore=$(getArtifactName undertow-core-*.jar "${patchHistory}")
servletapi=$(getArtifactName jboss-servlet-api_4.0*.jar "${patchHistory}")
cdiapi=$(getArtifactName cdi-api-2.0*.jar "${patchHistory}")

echo "TCK run will use the following versions of Websocket jars: $websocketapi, $websocketimpl, $webservlet, $webcore, $servletapi, $cdiapi"

cd $TS_HOME/bin
sed "s%modules/system/layers/base/javax/websocket/api/main/jboss-websocket-api.jar%${websocketapi}%" -i ts.jte.wildfly
sed "s%modules/system/layers/base/io/undertow/websocket/main/undertow-websockets-jsr.jar%${websocketimpl}%" -i ts.jte.wildfly
sed "s%modules/system/layers/base/io/undertow/servlet/main/undertow-servlet.jar%${webservlet}%" -i ts.jte.wildfly
sed "s%modules/system/layers/base/io/undertow/core/main/undertow-core.jar%${webcore}%" -i ts.jte.wildfly
sed "s%modules/system/layers/base/javax/servlet/api/main/jboss-servlet-api.jar%${servletapi}%" -i ts.jte.wildfly
sed "s%modules/system/layers/base/javax/enterprise/api/main/cdi-api.jar%${cdiapi}%" -i ts.jte.wildfly
sed "s%@web.home@%${JBOSS_HOME}%" -i ts.jte.wildfly
sed "s%@javaee.home@%${JBOSS_HOME}%" -i ts.jte.wildfly
sed "s%jbossweb-[^j]*[^a]*[^r]*.jar%${jbossweb}%" -i ts.jte.wildfly
sed "s%jboss-logging-[^j]*[^a]*[^r]*.jar%${jbosslogging}%" -i ts.jte.wildfly
sed "s%^harness\.log\.traceflag=.*$%harness.log.traceflag=true%" -i ts.jte.wildfly

cp ts.jte.wildfly ts.jte

mkdir -p $TCK_HOME_DIR/logs

JBOSS_OPTS=""

cd $JBOSS_HOME/bin
./standalone.sh &> /dev/null &

sleep 60

netstat -an | grep ':8080' | grep LISTEN > /dev/null || WEB_PORT_OPEN=$?
if [[ $WEB_PORT_OPEN == 1 ]]; then
   echo "app server failed to start up!" && exit 1
fi

cd $TS_HOME/bin

mv "${WORKSPACE}/deploy.xml" .
mkdir -p xml/impl/wildfly/
cp deploy.xml xml/impl/wildfly/deploy.xml
cp deploy.xml xml/impl/deploy.xml

# Deploy test archives
ant deploy.all

echo "deployment complete, run the signature + websocket tests next"

cd $TS_HOME/src/com/sun/ts/tests/signaturetest
ant runclient ${RUNCLIENT_OPTS} > $TCK_HOME_DIR/logs/test.log
cd $TS_HOME/src/com/sun/ts/tests/websocket
ant runclient ${RUNCLIENT_OPTS} >> $TCK_HOME_DIR/logs/test.log

###################################
# Create report for Hudson
###################################
cd $TS_HOME/lib
unzip -n javatest.zip > /dev/null && rm javatest.zip
cd   $TS_HOME/bin
#java -verbose -Xint -cp javatest.jar:jh.jar:$TS_HOME/lib/tsharness.jar com.sun.javatest.cof.Main -o report.xml JTwork &> tmp_log
java -verbose -Xint -cp $TS_HOME/lib/javatest.jar:jh.jar:$TS_HOME/lib/tsharness.jar com.sun.javatest.cof.Main -o report.xml JTWork

stopall


#!/bin/bash

yum install -y wget procps-ng net-tools

testFolder="securityapi"
securityManager="true"
profile="full-profile"
reverse="false"

WGET='wget -q --no-check-certificate --tries=100'

echo "${JAVA_HOME}"

#if [[ "$jdkVendor" == "OpenJDK11" ]]; then
#  echo "using JDK11"
#  export JAVA_HOME="/qa/tools/opt/x86_64/openjdk11_last"
#  java -version
#elif [[ "$jdkVendor" == "IBM" ]]; then
#  echo "using IBM JDK"
#  export JAVA_HOME="/qa/tools/opt/x86_64/ibm-java-80"
#else
#  echo "using Oracle JDK"
#  export JAVA_HOME="/qa/tools/opt/x86_64/jdk1.8.0_191"
#  # Jakarta EE 8 GlassFish should use at least jdk1.8.0_191
#fi   

export JDK_HOME=$JAVA_HOME
export PATH=$JDK_HOME/bin:$PATH
echo "$testFolder will run with $JAVA_HOME"


# https://wildflycts-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/tck7-runner/tck7-runnerlast/artifact/
export ARTIFACTS="$JENKINS_URLjob/$JOB_NAME/tck7-runneralias$BUILD_NUMBER/artifact"
echo "build artifacts will be saved to alias $ARTIFACTS"
if [[ -n "$customWorkspaceName" ]]; then
  # default to testFolder value with replacement of forwardslash to '_'
  export customWorkspaceName="${testFolder//\//_}"
fi  

echo "customWorkspaceName=$customWorkspaceName"
export TCK_HOME_DIR=$PWD

function createReport() {

    
    echo "create report"
    
    cd $TS_HOME/bin
# TODO: switch to javatest.zip replacement in Jakarta EE 8    
    unzip -n javatest.zip 
    rm javatest.zip
    java -verbose -Xint -cp javatest.jar:jh.jar:$TS_HOME/lib/tsharness.jar com.sun.javatest.cof.Main -o report.xml JTwork &> tmp_log

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
   stopall
}
trap "{ copy_logs; }" EXIT INT QUIT TERM

function runtck7 {
 (
     echo "runtck7"
     if [[ -n "$reverse" ]]; then
       if [[ "$profile" == web-profile ]]; then
         ant -Dkeywords=\(javaee_web_profile\|connector_web_profile\|jms\)\&\!\(ejbembed_vehicle\) runclient
       else
         ant -Dkeywords=\(javaee\|jms\)\&\!\(ejbembed_vehicle\) runclient
       fi  
     else 
       echo "running reverse tests"
       if [[ "$profile" == web-profile ]]; then
         ant -Dkeywords=\(javaee_web_profile\|connector_web_profile\|jms\)\&\!\(ejbembed_vehicle\)\&\(reverse\) runclient
       else
         ant -Dkeywords=\(javaee\|jms\)\&\!\(ejbembed_vehicle\)\&\(reverse\) runclient
       fi  
     fi 
     

 ) || return 0
}

function runbatch {
 (
   echo "runbatch"
   ant runclient
 ) || return 0
}

function runjavaeetests {
 (
     echo "runjavaeetests"
     ant runclient
 ) || return 0
}

function runejb3tck6 {
 (
     echo "runejb3tck6"
     if [[ "$profile" == web-profile ]]; then
       ant -Dkeywords=\(javaee_web_profile\|connector_web_profile\|jms\)\&\!\(ejbembed_vehicle\) -Dmultiple.tests="com/sun/ts/tests/ejb30/assembly com/sun/ts/tests/ejb30/bb com/sun/ts/tests/ejb30/misc com/sun/ts/tests/ejb30/sec com/sun/ts/tests/ejb30/tx com/sun/ts/tests/ejb30/zombie com/sun/ts/tests/ejb30/timer com/sun/ts/tests/ejb30/lite com/sun/ts/tests/ejb30/webservice" runclient
     else
       ant -Dkeywords=\(javaee\|jms\)\&\!\(ejbembed_vehicle\) -Dmultiple.tests="com/sun/ts/tests/ejb30/assembly com/sun/ts/tests/ejb30/bb com/sun/ts/tests/ejb30/misc com/sun/ts/tests/ejb30/sec com/sun/ts/tests/ejb30/tx com/sun/ts/tests/ejb30/zombie com/sun/ts/tests/ejb30/timer com/sun/ts/tests/ejb30/lite com/sun/ts/tests/ejb30/webservice" runclient
     fi
) || return 0
}

function runjpaentitytck7 {
 (
     echo "runjpaentitytck7"
     if [[ "$profile" == web-profile ]]; then
       ant -Dkeywords=\(javaee_web_profile\|connector_web_profile\|jms\)\&\!\(ejbembed_vehicle\) -Dmultiple.tests="com/sun/ts/tests/jpa/core/EntityGraph com/sun/ts/tests/jpa/core/entityManager com/sun/ts/tests/jpa/core/entityManager2 com/sun/ts/tests/jpa/core/entityManagerFactory com/sun/ts/tests/jpa/core/entityManagerFactoryCloseExceptions com/sun/ts/tests/jpa/core/entitytest com/sun/ts/tests/jpa/core/entityTransaction" runclient
     else
       ant -Dkeywords=\(javaee\|jms\)\&\!\(ejbembed_vehicle\) -Dmultiple.tests="com/sun/ts/tests/jpa/core/EntityGraph com/sun/ts/tests/jpa/core/entityManager com/sun/ts/tests/jpa/core/entityManager2 com/sun/ts/tests/jpa/core/entityManagerFactory com/sun/ts/tests/jpa/core/entityManagerFactoryCloseExceptions com/sun/ts/tests/jpa/core/entitytest com/sun/ts/tests/jpa/core/entityTransaction" runclient
     fi  
 ) || return 0
}

stopall() {
   
   echo "stop all launched background processes"
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

stopall

unzip wildfly.zip > /dev/null && rm -f wildfly.zip
mv wildfly-* wildfly || true

# get glassfish
unzip -o glassfish.zip > /dev/null && rm -f glassfish.zip

# get Red Hat TCK files
unzip -o mods.zip > /dev/null && rm -f mods.zip

# get latest hacking build of tck
mv jakartaeetck*.zip jakartaeetck.zip
unzip -o jakartaeetck.zip > /dev/null && rm -f jakartaeetck.zip


# $WGET https://www-us.apache.org/dist/ant/binaries/apache-ant-1.10.6-bin.zip
# we now copy ant from apacheant job
$WGET https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.6-bin.zip
if [ ! -f apache-ant-1.10.6-bin.zip ]; then
    echo "wget of apache-ant-1.10.6-bin.zip failed as file doesn't exist, exiting with failure"
    exit 1
fi
ls -l apache-ant-1.10.6-bin.zip
unzip -o apache-ant-1.10.6-bin.zip > /dev/null && rm -f apache-ant-1.10.6-bin.zip
export ANT_HOME=$PWD/apache-ant-1.10.6

$WGET https://repo1.maven.org/maven2/ant-contrib/ant-contrib/1.0b3/ant-contrib-1.0b3.jar
# $WGET http://central.maven.org/maven2/ant-contrib/ant-contrib/1.0b3/ant-contrib-1.0b3.jar
mv ant-contrib-1.0b3.jar "$ANT_HOME/lib"

if [[ -z $JBOSS_HOME ]]; then
  export JBOSS_HOME=$PWD/wildfly
  export JBOSS_HOME=`echo $JBOSS_HOME`
fi

export TS_HOME=$PWD/jakartaeetck

export JEETCK_MODS=$PWD/cts-8-mods
export JAVAEE_HOME=$JBOSS_HOME
export JAVAEE_HOME_RI=$PWD/glassfish5/glassfish
export DERBY_HOME=$JAVAEE_HOME_RI/../javadb
# export ANT_HOME=$TS_HOME/tools/ant
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

# set CTS_DB, the fourth parameter or 'javadb' as default
CTS_DB=${4:-javadb}

##CTS-102 - needs additional testing

if [[ ! -z "$appserverconfig" && "$appserverconfig" != "" ]]; then
   cd cts-8-mods/etc
   echo "switch to use custom application server configuration file $appserverconfig"
   if [[ "$3" == web-profile ]]; then
     echo "using web-profile, replace current standalone-web.xml contents with $appserverconfig"
     cp -f "$appserverconfig" standalone-web.xml
   else 
     echo "using full EE profile, replace current standalone-full.xml contents with $appserverconfig"
     cp -f "$appserverconfig" standalone-full.xml
   fi
fi

JEE7TCK_MODS_OPTS=""
if [[ "$profile" == web-profile ]]; then
   JEE7TCK_MODS_OPTS="$JEE7TCK_MODS_OPTS -Dprofile=web"
   RUNCLIENT_OPTS="-Dkeywords=\"\(javaee_web_profile\|connector_web_profile\) \& \!\(ejbembed_vehicle\)\""
   if [[ "$testFolder" == connector* ]]; then
      RUNCLIENT_OPTS="-Dkeywords=\"\(javaee_web_profile\|connector\)\&\(jsp_vehicle\|servlet_vehicle\)\&\!\(connector_jta\) \& \!\(connector_mdb\)\""
   fi
fi

if [[ "$CTS_DB" == postgresql ]]; then
   JEE7TCK_MODS_OPTS="$JEE7TCK_MODS_OPTS -Dcts.db=${CTS_DB} -Ddatasource-mapping=\"PostgreSQL 8.0\""
fi

cd $JEETCK_MODS
ant clean
ant $JEE7TCK_MODS_OPTS

mkdir -p $TCK_HOME_DIR/logs

if [[ "$CTS_DB" == javadb ]]; then
  cd $DERBY_HOME/bin
  source setNetworkServerCP
  sh startNetworkServer -noSecurityManager &> $TCK_HOME_DIR/logs/javadb.log &
  sleep 30
  # sleep up to 60*5 seconds until Derby listening port is open
  # after 3 minutes of waiting, kill derby and restart, continue looping
  NUM="0"
  echo "check if Derby is listening on port 1527"
  while [[ $(netstat -an | grep -c ':1527') = 0 ]]; do 
   NUM=$[$NUM + 1]
   if (("$NUM" > "60")); then
     echo "timed out waiting for Derby server to start"
     netstat -an
     exit 1
   elif (("$NUM" == "30")); then
     echo "Restart Derby server, in case it was a listening port in use issue that is now resolved"
     kill-derby
     sleep 30
     cd $DERBY_HOME/bin
     source setNetworkServerCP
     sh startNetworkServer -noSecurityManager &> $TCK_HOME_DIR/logs/javadb.log &
     sleep 25
   else
     echo "sleep 5 seconds and check derby port again"
   fi
   sleep 5
  done
  echo "Derby is listening on port 1527"
fi

cd $TS_HOME/bin
ant init.${CTS_DB}
ant config.vi -Dcts.db=${CTS_DB}

# initialize ldap for securityapi tests
if [[ "$testFolder" == securityapi ]]; then 
 ant init.ldap
fi 

# disable security-manager if disable-security-manager was specified 
# Sept 13, 2019 SPM: we previously ran web-profile without security-manager, 
# but since we will also run securityapi + connector now as part of web profile, we will
if [[ "$securityManager" == false ]]; then
   awk '/<subsystem xmlns="urn:jboss:domain:security-manager:1.0">/,/<\/subsystem>/ { next } 1' $JBOSS_HOME/standalone/configuration/standalone.xml > $JBOSS_HOME/standalone/configuration/standaloneNOSEC.xml
   cp $JBOSS_HOME/standalone/configuration/standaloneNOSEC.xml $JBOSS_HOME/standalone/configuration/standalone.xml
   echo "security-manager is disabled"
elif [[ "$securityManager" == true ]]; then
   echo "security-manager subsystem settings will be enabled via -secmgr option (ee server + client container)"
   # add -secmgr for EE server container 
   export SECURITY_MANAGER_OPTION="-secmgr"
   # add -secmgr for EE client container
   cd $TS_HOME/bin
   sed "s%appclient.sh%appclient.sh -secmgr%" -i ts.jte
   echo "customized running of appclient.sh in ts.jte to include -secmgr option"
fi

if [[ "$testFolder" == interop* || "$testFolder" == jws || "$testFolder" == jaxws* || "$testFolder" == webservices12 ]]; then 
   echo "Starting RI for interop tests"
   cd $TS_HOME/bin
   ant config.ri
   RI_STARTED=$?
   if [[ "$testFolder" == interop/tx-enabled ]]; then
      ant enable.ri.tx.interop 
   elif [[ "$testFolder" == interop/tx-disabled ]]; then
      ant disable.ri.tx.interop 
   fi
else
   echo "do not start GlassFish"
fi

if [[ "$testFolder" == javamail ]]; then
   cd $TS_HOME/bin
   echo "populateMailbox"
   ant populateMailbox
fi

if [[ "$testFolder" == interop/csiv2* ]]; then 
   echo "enable csiv2"
   cd $TS_HOME/bin
   ant enable.csiv2
   cd $JEETCK_MODS
   ant csiv2-certs
fi
if [[ "$testFolder" == interop/csiv2* || "$testFolder" == ejb30/lite* || "$testFolder" == xa ]]; then
   # JBQA-4092 for ejb30/lite tests
   cd $TS_HOME/bin
   ant init.javadbEmbedded
fi

if [[ "$testFolder" == jaspic ]]; then 
   cd $TS_HOME/bin
   ant enable.jaspic
fi

if [[ "$testFolder" == jacc ]]; then 
   cd $TS_HOME/bin
   ant enable.jacc
fi

if [[ "$testFolder" == jaxrs ]]; then 
   cd $TS_HOME/bin
   ant update.jaxrs.wars
fi


JBOSS_OPTS=""
if [[ "$testFolder" == connector* ]]; then
   JBOSS_OPTS="$JBOSS_OPTS -P file:///$JBOSS_HOME/bin/jca-tck-properties.txt"
fi

JAVA_OPTS="-Xms512m -Xmx800m -XX:MaxPermSize=512m -Xss1m -XX:+HeapDumpOnOutOfMemoryError -XX:-UseGCOverheadLimit -Dtest.ejb.stateful.timeout.wait.seconds=70 -Djava.net.preferIPv4Stack=true -Dorg.jboss.resolver.warning=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000"
JAVA_OPTS="$JAVA_OPTS -Djboss.modules.system.pkgs=$JBOSS_MODULES_SYSTEM_PKGS -Djava.awt.headless=true"

if [[ "$custombranch" == "jpa22_orm53_5" ]]; then
   JAVA_OPTS="$JAVA_OPTS -Dwildfly.jpa.defaultprovidermodule=org.hibernate.orm:5.3"
fi

# uncomment the following to hack in DEBUG logging in appclient.xml
#cd $JBOSS_HOME/appclient/configuration
#sed -i 's/INFO/DEBUG/1' -i appclient.xml
#sed -i 's/com.arjuna/org.jboss.as.security/1' -i appclient.xml
#sed -i 's/sun.rmi/org.wildfly.iiop.openjdk/1' -i appclient.xml
#sed -i 's/WARN/DEBUG/1' -i appclient.xml
#sed -i 's/WARN/DEBUG/1' -i appclient.xml
#cat appclient.xml

#CSIV2 REMOVEME
echo "" >> $JBOSS_HOME/bin/standalone.conf
echo 'JAVA_OPTS="$JAVA_OPTS -DwebServerHost.2=localhost -DwebServerPort.2=8002"' >> $JBOSS_HOME/bin/standalone.conf

echo "startup appserver"
cd $JBOSS_HOME/bin
echo "run: ./standalone.sh  -Dee8.preview.mode=true $SECURITY_MANAGER_OPTION $JBOSS_OPTS"
./standalone.sh  -Dee8.preview.mode=true $SECURITY_MANAGER_OPTION $JBOSS_OPTS &> /dev/null &
JAVA_OPTS=

sleep 30

NUM=0
while true
do  

NUM=$[$NUM + 1]
if (("$NUM" > "60")); then
    echo "Application server failed to start up! Will skip testing and exit with failure code 1" 
    netstat -an
    exit 1
elif ./jboss-cli.sh --connect command=':read-attribute(name=server-state)' | grep running; then
    echo "server is running"
    break
fi
    echo "server is not yet running"
    sleep 10
done

# more setup for securityapi tests
if [[ "$testFolder" == securityapi ]]; then 
 cd $TS_HOME/bin
 ant -f xml/impl/wildfly/deploy.xml init.security.api
fi 

if [[ "$testFolder" == jacc ]]; then 
  echo "enable trace log for jacc test"

  cd $TS_HOME/bin
  # harness.log.traceflag=false
  sed "s%^harness\.log\.traceflag=.*$%harness.log.traceflag=true%" -i ts.jte
  grep traceflag ts.jte
  echo "enabled traceflag for jacc"
 fi  

echo "app server is running"
#echo "enable debug logging for finding cause of ORB init failures"
#./jboss-cli.sh -c --command='/subsystem=logging/logger=org.jboss.security:add(level=DEBUG)'
#./jboss-cli.sh -c --command='/subsystem=logging/logger=org.wildfly.iiop.openjdk:add(level=DEBUG)'

# cd $TS_HOME/bin
# cat ts.jte

####################################
# Run tests
###################################


#CSIV2 DEBUG
#echo 'JAVA_OPTS="$JAVA_OPTS -Dcom.sun.CORBA.ORBDebug=transport -Djavax.net.debug=all"' >> $JBOSS_HOME/bin/appclient.conf



if [[ "$testFolder" == rmiiiop ]]; then
   cd $TS_HOME/bin
   ant start.rmiiiop.server &> /dev/null &
   sleep 5
fi
if [[ "$testFolder" == connector* || "$testFolder" == xa || "$testFolder" == ejb30/bb ]]; then
   cd $TS_HOME/bin
   ant -f xml/impl/wildfly/deploy.xml deploy.all.rars
   if [[ "$testFolder" == xa ]]; then
   ant -f xml/impl/wildfly/deploy.xml deploy.Tsr.ear
   fi
fi
if [[ "$testFolder" == jws || "$testFolder" == jaxws* || "$testFolder" == webservices12 ]]; then
   cd $TS_HOME/bin
   ant -Dbuild.vi=true tsharness
   if [[ "$testFolder" == webservices12 ]]; then
      ant build.special.webservices.clients -Dbuild.vi=true
   else
      cd $TS_HOME/src/com/sun/ts/tests/$testFolder
      ant -Dts.home=$TS_HOME -Dbuild.vi=true clean build
   fi
fi
if [[ "$testFolder" == ejb30/assembly || "$testFolder" == ejb30/misc || "$testFolder" == ejb30/lite* ]]; then
   cd $TS_HOME/bin
   ant configure.datasource.tests
fi

if [[ "$testFolder" == interop/tx-enabled ]]; then
   cd $TS_HOME/src/com/sun/ts/tests/interop/tx
elif [[ "$testFolder" == interop/tx-disabled ]]; then
   cd $TS_HOME/src/com/sun/ts/tests/interop/tx
elif [[ "$testFolder" == batch ]]; then
   cd $TS_HOME/src/com/ibm/jbatch/tck/tests
else
   cd $TS_HOME/src/com/sun/ts/tests/$testFolder
fi

echo "running tests in $PWD"

###  Currently with TCK 7, the ejb30 tests are run as individual jobs not via the runejb3tck6 function.
###  This may be changed in the future and the runejb3tck6 function updated accordingly but preserved here for now.
if [[ "$testFolder" == ejb30 ]]; then
   echo "runejb3tck6"
   runejb3tck6 > $TCK_HOME_DIR/logs/test.log
elif [[ "$testFolder" == jpa/core/entitytest ]]; then
   echo "runjpaentitytck7 "
   runjpaentitytck7 > $TCK_HOME_DIR/logs/test.log
elif [[ "$testFolder" == javaee* ]]; then
   echo "runjavaeetests"
   runjavaeetests | tee $TCK_HOME_DIR/logs/test.log
elif [[ "$testFolder" == batch ]]; then
   echo "runbatch"
   runbatch | tee $TCK_HOME_DIR/logs/test.log
else
   echo "runtck7 "
   runtck7 | tee $TCK_HOME_DIR/logs/test.log
fi




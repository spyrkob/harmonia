#!/bin/bash

source props.sh

dnf install -y procps-ng net-tools

function kill_agent {
 (
    ps -eaf --columns 20000 | grep com.sun.javatest.agent.AgentMain | grep -v grep | awk '{ print $2; }' | xargs kill &> /dev/null
    ps -eaf --columns 20000 | grep com.sun.javatest.agent.AgentMain | grep -v grep | awk '{ print $2; }' | xargs kill -9 &> /dev/null
 ) || return 0
}

which java
java -version

if [[ -n "$customWorkspaceName" ]]; then
  # default to testFolder value with replacement of forwardslash to '_'
  export customWorkspaceName="${testFolder//\//_}"
fi  

echo "customWorkspaceName=$customWorkspaceName"

rm -rf wildfly
unzip wildfly.zip > /dev/null && rm -f wildfly.zip
mv wildfly-* wildfly || true

curl -k https://download.eclipse.org/jakartaee/xml-binding/2.3/jakarta-xml-binding-tck-2.3.0.zip - o jakarta-xml-binding-tck-2.3.0.zip
unzip -o jakarta-xml-binding-tck-2.3.0.zip > /dev/null && rm -f jakarta-xml-binding-tck-2.3.0.zip

java -jar JAXB-TCK-2.3.jar
rm JAXB-TCK-2.3.jar
# as mentioned in README-alt02.txt, ensure that certain named files are writable
chmod -R +rwx JAXB-TCK-2.3
ls
# Prepares env
export WORK_DIR=`pwd`
export JBOSS_HOME=$WORK_DIR/wildfly
export TCK_HOME=$WORK_DIR/JAXB-TCK-2.3
echo "JAVA_HOME=$JAVA_HOME"
echo "JBOSS_HOME=$JBOSS_HOME"
echo "TCK_HOME=$TCK_HOME"
mkdir -p $TCK_HOME/logs
mkdir $TCK_HOME/client
mkdir $TCK_HOME/endorsed
ls "$TCK_HOME/endorsed"
ls "$TCK_HOME/lib"

cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/jaxb-runtime-*.jar $TCK_HOME/endorsed/jaxb-impl.jar || true
# cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/jaxb-core-*.jar $TCK_HOME/endorsed/jaxb-core.jar || true
cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/jaxb-xjc-*.jar $TCK_HOME/client/jaxb-xjc.jar || true
cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/jaxb-jxc-*.jar $TCK_HOME/client/jaxb-jxc.jar || true
cp -p $JBOSS_HOME/modules/system/layers/base/org/apache/xerces/main/xercesImpl*.jar $TCK_HOME/endorsed/xerces-impl.jar || true

cp -p $JBOSS_HOME/modules/system/layers/base/javax/xml/bind/api/main/jboss-jaxb-api_2.3*.jar $TCK_HOME/endorsed/jboss-jaxb-api_2.3_spec.jar || true
if [ -d "$JBOSS_HOME/modules/system/layers/base/com/sun/istack/main/" ]; then
    cp -p $JBOSS_HOME/modules/system/layers/base/com/github/relaxng/main/relaxng*.jar $TCK_HOME/endorsed/relaxngDatatype.jar || true
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/istack/main/istack-commons-runtime-*.jar $TCK_HOME/endorsed/istack-commons-runtime.jar || true
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/istack/main/istack-commons-tools*.jar $TCK_HOME/endorsed/istack-commons-tools.jar || true	
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/txw2/main/txw2-*.jar $TCK_HOME/endorsed/txw2.jar || true
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xsom/main/xsom-*.jar $TCK_HOME/client/xsom.jar || true
else
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/relaxng*.jar $TCK_HOME/endorsed/relaxngDatatype.jar || true
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/istack-commons-runtime-*.jar $TCK_HOME/endorsed/istack-commons-runtime.jar || true
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/istack-commons-tools*.jar $TCK_HOME/endorsed/istack-commons-tools.jar || true
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/txw2-*.jar $TCK_HOME/endorsed/txw2.jar || true
    cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/xsom-*.jar $TCK_HOME/client/xsom.jar || true
fi

cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/codemodel-*.jar $TCK_HOME/client/codemodel.jar || true
cp -p $JBOSS_HOME/modules/system/layers/base/com/sun/xml/bind/main/rngom-*.jar $TCK_HOME/client/rngom.jar || true

pwd
ls JAXB-TCK-2.3

# Prepares configuration file
echo "
INTERVIEW=com.sun.jaxb_tck.interview.JAXBTCKParameters
LOCALE=cs_CZ
QUESTION=jck.epilog
TESTSUITE=$TCK_HOME
WORKDIR=$TCK_HOME/work_directory
jck.concurrency.concurrency=3
jck.env.description=JAXB 2.3 TCK for WildFly
jck.env.envName=jaxb23_as70x
jck.env.jaxb.agent.agentPassiveHost=localhost
jck.env.jaxb.agent.agentPassivePort=
jck.env.jaxb.agent.agentType=passive
jck.env.jaxb.agent.useAgentPortDefault=Yes
jck.env.jaxb.schemagen.run.schemagenWrapperClass=com.sun.jaxb_tck.lib.SchemaGen
jck.env.jaxb.schemagen.skipJ2XOptional=Yes
jck.env.jaxb.testExecute.cmdAsFile=$JAVA_HOME/bin/java
jck.env.jaxb.testExecute.otherEnvVars=JBOSS_HOME\=$JBOSS_HOME JAXB_HOME\=$TCK_HOME/client JAVA_HOME\=$JAVA_HOME
jck.env.jaxb.testExecute.otherOpts=-Xmx512m -Xms256m -Djava.endorsed.dirs\=$TCK_HOME/endorsed
jck.env.jaxb.xsd_compiler.defaultOperationMode=Yes
jck.env.jaxb.xsd_compiler.run.compilerWrapperClass=com.sun.jaxb_tck.lib.SchemaCompiler
jck.env.jaxb.xsd_compiler.skipValidationOptional=Yes
jck.env.testPlatform.local=Yes
jck.env.testPlatform.multiJVM=No
jck.excludeList.customFiles=$TCK_HOME/lib/jaxb_tck23.jtx
jck.excludeList.excludeListType=custom
jck.excludeList.latestAutoCheck=No
jck.excludeList.latestAutoCheckInterval=7
jck.excludeList.latestAutoCheckMode=everyXDays
jck.excludeList.needExcludeList=Yes
jck.keywords.keywords.mode=expr
jck.keywords.needKeywords=No
jck.priorStatus.needStatus=No
jck.priorStatus.status=
jck.tests.needTests=No
jck.tests.tests=
jck.tests.treeOrFile=tree
jck.timeout.timeout=1

" > default_configuration.jti

# ensure agent isn't already running
kill_agent

mkdir $WORK_DIR/work_directory

# update the following line in testsuite.jtd
# finder=com.sun.javatest.finder.BinaryTestFinder -binary /home/jenkins/workspace/jaxb-tck_master/jaxb-tck-build/JAXB-TCK-2.3/tests/testsuite.jtd
# to use correct setting for local machine
FIND=/home/jenkins/workspace/jaxb-tck_master/jaxb-tck-build/JAXB-TCK-2.3/tests/testsuite.jtd
REPLACE=$TCK_HOME/tests/testsuite.jtd
sed -i "s|$FIND|$REPLACE|g" $TCK_HOME/testsuite.jtt

# Starts agent
echo "Starting Agent ...."
java -server -Xmx1024m -Xms128m -Djava.endorsed.dirs=$TCK_HOME/endorsed \
     -classpath $TCK_HOME/lib/javatest.jar:$TCK_HOME/lib/jtlegacy.jar:$TCK_HOME/classes:$TCK_HOME/endorsed/jaxb-impl.jar:$TCK_HOME/classes:$TCK_HOME/endorsed/jaxb-core.jar:$TCK_HOME/client/jaxb-jxc.jar:$TCK_HOME/client/jaxb-xjc.jar:$TCK_HOME/endorsed/jboss-jaxb-api_2.3_spec.jar:$TCK_HOME/endorsed/relaxngDatatype.jar:$TCK_HOME/endorsed/istack-commons-runtime.jar:$TCK_HOME/endorsed/istack-commons-tools.jar:$TCK_HOME/endorsed/txw2.jar:$TCK_HOME/client/codemodel.jar:$TCK_HOME/client/xsom.jar:$TCK_HOME/client/rngom.jar \
     -Djava.security.policy=$TCK_HOME/lib/tck.policy \
     com.sun.javatest.agent.AgentMain \
     -passive 1>agent.log 2>agent-err.log &
AGENT_ID=`echo $!`
echo "Agent is started with ID $AGENT_ID"

# Starts test
# try running with less memory than -Xmx512m -Xms512m for agent and test
# agent seems to be using 1.3 gig of memory + 70% of cpu, so maybe increase agent mem + 
#   decrease test memory next
echo "Starting test ..."
java -Xmx512m -Xms128m -Djava.endorsed.dirs=$TCK_HOME/endorsed -jar $TCK_HOME/lib/javatest.jar \
      -verbose:stop,progress -testSuite $TCK_HOME \
      -workdir -create $WORK_DIR/work_directory \
      -config ./default_configuration.jti \
      -concurrency 3 -timeoutFactor 5 \
      -runtests || TEST_STATUS=$?
echo "Done"


echo "Creating reports ..."
java -jar $TCK_HOME/lib/javatest.jar \
      -verbose -testSuite $TCK_HOME \
      -workdir $WORK_DIR/work_directory \
      -config ./default_configuration.jti \
      -writereport $WORK_DIR/report || REPORT_STATUS=$?
echo "Done"

echo "Generating xml report for Hudson ..."
cd $WORK_DIR

# unzip /home/hudson/hudson_repository/tck/tck6/javatest.zip
# java -Xint -cp javatest.jar:jh.jar com.sun.javatest.cof.Main -o report.xml work_directory/

# java -Djava.endorsed.dirs=$TCK_HOME/endorsed -Xint -classpath $TCK_HOME/lib/javatest.jar:$TCK_HOME/lib/jtlegacy.jar:$TCK_HOME/classes:$TCK_HOME/endorsed/jaxb-impl.jar:$TCK_HOME/classes:$TCK_HOME/client/jaxb-jxc.jar:$TCK_HOME/client/jaxb-xjc.jar:$TCK_HOME/endorsed/jboss-jaxb-api_2.3_spec.jar:$TCK_HOME/endorsed/relaxngDatatype.jar:$TCK_HOME/endorsed/istack-commons-runtime.jar:$TCK_HOME/endorsed/istack-commons-tools.jar:$TCK_HOME/endorsed/txw2.jar:$TCK_HOME/client/codemodel.jar:$TCK_HOME/client/xsom.jar:$TCK_HOME/client/rngom.jar com.sun.javatest.cof.Main -o report.xml work_directory/

java -Djava.endorsed.dirs=$TCK_HOME/endorsed \
 -Xint -classpath $TCK_HOME/lib/javatest.jar:$TCK_HOME/lib/jtlegacy.jar:$TCK_HOME/classes:$TCK_HOME/endorsed/jaxb-impl.jar:$TCK_HOME/classes:$TCK_HOME/endorsed/jaxb-core.jar:$TCK_HOME/client/jaxb-jxc.jar:$TCK_HOME/client/jaxb-xjc.jar:$TCK_HOME/endorsed/jboss-jaxb-api_2.3_spec.jar:$TCK_HOME/endorsed/relaxngDatatype.jar:$TCK_HOME/endorsed/istack-commons-runtime.jar:$TCK_HOME/endorsed/istack-commons-tools.jar:$TCK_HOME/endorsed/txw2.jar:$TCK_HOME/client/codemodel.jar:$TCK_HOME/client/xsom.jar:$TCK_HOME/client/rngom.jar com.sun.javatest.cof.Main -o report.xml work_directory/ 
     
echo "Done"

kill_agent

echo "Killing agent process"
kill -9 $AGENT_ID || true
pwd
#find -name *index_XmlAdapter*.jtr
# pwd = /mnt/hudson_workspace/workspace/jakartaee-ee8/jaxb23
# work_directory/api/javax_xml/bind/annotation/adapters/index_XmlAdapter.jtr
exit 0

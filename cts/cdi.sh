#!/bin/bash

source ../props.sh

pwd
ls -alF


# TODO: should checkout in the pipeline, but we don't know the branch until later
dnf install -y git

# export PATH=$NATIVE_TOOLS/$JAVA18/bin:$PATH
which java
java -version
mount
echo " mount of qa/m2 didn't seem to work, so avoid in MAVEN_OPTS: -Dorg.apache.maven.user-settings=/qa/m2/settings.xml -Dmaven.repo.local=/qa/m2/repository"
export MAVEN_VERSION=3.2.5
export PATH=$MAVEN_HOME/bin:$PATH
# MAVEN_OPTS="-XX:+UseGCOverheadLimit -Xmx1024m -Xms512m -XX:PermSize=256m -XX:MaxPermSize=768m -Dorg.apache.maven.user-settings=/qa/m2/settings.xml -Dmaven.repo.local=/qa/m2/repository"

MAVEN_OPTS="-XX:+UseGCOverheadLimit -Xmx1024m -Xms512m -XX:PermSize=256m -XX:MaxPermSize=768m"
export MAVEN_OPTS
export JBOSS_DIR=wildfly
export JBOSS_ZIP=./wildfly.zip

unzip wildfly.zip > /dev/null && rm -f wildfly.zip
mv wildfly-* $JBOSS_DIR || true

cd wildfly
# find the weld-core-impl jar in wildfly
jarname=$(find -name *weld-core-impl*.jar | sed "s/-redhat-[0-9]*//g" | cut -d / -f 11 | cut -d - -f 4)

if [ -z "${jarname}" ]; then
  echo "Could not find *weld-core-impl*.jar in wildfly folder, so will return failure so Jenkins will 'marked build as failure'"
  exit -1
fi
echo "remove extension from $jarname"
WELD_CORE_VERSION=${jarname%.*}
echo "Weld core version is $WELD_CORE_VERSION"
cd ..

cd cdi-tck-2.0.6/artifacts
bash artifact-install.sh

cd $WORKSPACE
git clone https://github.com/weld/core.git weld
cd weld
# weld version is used merely to execute TCK in the latest version, hence using master makes sure you are on latest TCK
echo "checking out Weld Core version $WELD_CORE_VERSION"
git checkout $WELD_CORE_VERSION
# git checkout 3.1.5.Final
# switch from master to 3.1 branch due to EE 9 changes on master
# git checkout 3.1

#git checkout master

cd $WORKSPACE

#echo "copy cdi-tck-2.0.6/artifacts/cdi-tck-impl-2.0.6-suite.xml over weld/jboss-tck-runner/src/test/tck12/tck-tests.xml (also update tck20)"
echo "weld/jboss-tck-runner/src/test/tck12/tck-tests.xml contents:"
cat weld/jboss-tck-runner/src/test/tck12/tck-tests.xml

echo "cdi-tck-2.0.6/artifacts/cdi-tck-impl-2.0.6-suite.xml contents:"
cat cdi-tck-2.0.6/artifacts/cdi-tck-impl-2.0.6-suite.xml

echo "weld/jboss-tck-runner/src/test/tck12/tck-tests.xml contents:"
cat weld/jboss-tck-runner/src/test/tck12/tck-tests.xml

echo "weld/jboss-tck-runner/src/test/tck20/tck-tests.xml contents:"
cat weld/jboss-tck-runner/src/test/tck20/tck-tests.xml

# set TCK version to use in installing ext-lib and running tests
#export TCK_VERSION=2.0.5.SP1
export TCK_VERSION=2.0.6.SP1

# JBOSS_HOME is used by jboss-tck-runner and has to point to WFLY
export JBOSS_HOME=${WORKSPACE}/${JBOSS_DIR}

cd weld
# Run embedded container tests:
# mvn clean verify -f jboss-tck-runner/pom.xml
mvn clean package -Dtck -Dcdi.tck.version=${TCK_VERSION} -f jboss-as/pom.xml
mvn clean verify -f jboss-tck-runner/pom.xml -Dincontainer -Dcdi.tck.version=${TCK_VERSION} -Dmaven.test.failure.ignore=true

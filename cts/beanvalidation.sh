#!/bin/bash

source props.sh
# hack around mvn-wrapper trying to force us in workdir folder
cd ../
WORKSPACE=$(pwd)
echo "WORKSPACE: ${WORKSPACE}"

# TODO: should checkout in the pipeline, but we don't know the branch until later
dnf install -y git

export PATH=$MAVEN_HOME/bin:$PATH

java -version

WILDFLY_DIR=wildfly

unzip wildfly.zip > /dev/null && rm -f wildfly.zip
mv wildfly-* $WILDFLY_DIR || true
JBOSS_HOME=${WORKSPACE}/${WILDFLY_DIR}

# determine hibernate validator version
getModuleXml() {
  local filter="${1}"
  local patchHistory="${2}"

  moduleXml=$(find "${PWD}" -name module.xml | grep "${filter}" || true)
  for version in $patchHistory; do
    selectedModuleXml=$(echo "${moduleXml}" | grep "${version}" || true)
    if [[ "${selectedModuleXml}x" != "x" ]]; then
      echo "${selectedModuleXml}" | sed "s|^\\./||g"
      return 0
    fi
  done
  echo "${moduleXml}"
  return 0
}
pushd $JBOSS_HOME
patchHistory=$(./bin/jboss-cli.sh  --command="patch history" | grep -o "patch-id\"[^\"]*\"[^\"]*" | grep -o "[^\"]*$" || true)
MODULE_FILE=$(getModuleXml "org/hibernate/validator/main" "${patchHistory}")
popd
DIST_HIBERNATE_VALIDATOR_VERSION=$(grep "hibernate-validator-6.0" $MODULE_FILE | cut -d '-' -f 4 | sed "s#.jar.*##")

# Jakarta EE 8 use https://download.eclipse.org/jakartaee/bean-validation/2.0/beanvalidation-tck-dist-2.0.5.zip

wget -q https://download.eclipse.org/jakartaee/bean-validation/2.0/beanvalidation-tck-dist-2.0.5.zip
sha256sum beanvalidation-tck-dist-2.0.5.zip
unzip -q beanvalidation-tck-dist-2.0.5.zip
cd beanvalidation-tck-dist-2.0.5/src
# install tck
# mvn clean install -s settings-example.xml
mvn clean install -B
cd $WORKSPACE

# setup to use https://github.com/hibernate/hibernate-validator/tree/master/tck-runner
# old way HV is below

git clone git://github.com/hibernate/hibernate-validator.git
# git clone https://github.com/scottmarlow/hibernate-validator.git

cd hibernate-validator

if [ -n "${version_org_hibernate_validator}" ]; then
  git checkout $version_org_hibernate_validator
else
  git checkout $DIST_HIBERNATE_VALIDATOR_VERSION
fi

cd build-config
mvn clean install -DskipTests=true

# skip install, as we already installed jakarta bean validation
#cd ${WORKSPACE}/hibernate-validator/build-config
#mvn install -Dmaven.repo.local=${WORKSPACE}/myrepository

cd ${WORKSPACE}/hibernate-validator/tck-runner

sed -i.bak 's/-DincludeJavaFXTests=true//' pom.xml
echo "removed JavaFXTests from pom.xml"
cat pom.xml

# for 6.0.18.Final, instead of removing lines 245-310, remove 266 - 331
# HV tck-runner uses mvn resources plugin to download, unpack and patch wildfly, remove those lines from pom
if [ "$DIST_HIBERNATE_VALIDATOR_VERSION" == "6.0.18.Final" ]; then
  sed -i.bak '266,331d' pom.xml
  echo "removed lines 266 - 331 pom.xml"
elif [ "$DIST_HIBERNATE_VALIDATOR_VERSION" == "6.0.17.Final" ]; then
  sed -i.bak '245,310d' pom.xml
  echo "removed lines 245 - 310 pom.xml"
fi

cat pom.xml

# if beanvalidation.tck.version property isn't empty, append version to mvn command
if [ -n "${beanvalidation_tck_version}" ]; then
  ADDITIONAL_OPTS="-Dtck.version=$beanvalidation_tck_version"
fi

# add ee8.preview.mode property
$JBOSS_HOME/bin/jboss-cli.sh --commands="embed-server --admin-only=true,/system-property=ee8.preview.mode:add(value=true),stop-embedded-server"

mvn --strict-checksums -B -U -f ./pom.xml clean install test -Dincontainer -Dmaven.test.failure.ignore=true -D"checkstyle.skip"=true -Dwildfly.target-dir=$JBOSS_HOME $ADDITIONAL_OPTS
# mvn --strict-checksums -B -U -Dmaven.repo.local=${WORKSPACE}/myrepository -f ./pom.xml clean install test -Dincontainer -Dmaven.test.failure.ignore=true -D"checkstyle.skip"=true -Dwildfly.target-dir=$JBOSS_HOME $ADDITIONAL_OPTS
# mvn --strict-checksums -B -U -s $WORKSPACE\beanvalidation-tck-dist-2.0.5/src/settings-example.xml -f ./pom.xml clean install test -Dincontainer -Dmaven.test.failure.ignore=true -D"checkstyle.skip"=true -Dwildfly.target-dir=$JBOSS_HOME $ADDITIONAL_OPTS

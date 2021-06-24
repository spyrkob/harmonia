#!/bin/bash

source ../props.sh

if [[ -n "$weldVersion" ]]; then
  # TODO: look inside of appserver zip and locate wild-core, extract version from that
  #       for example, weld-core-impl-3.1.2.Final.jar should == 3.1.2.Final
  #       Alternative would be to pass the WF/EAP version in and use different versions of the Weld TCK runner based on WF version specified.
  export weldVersion="3.1.2.Final"
fi  

pwd
mkdir repo
repo="$PWD/repo"

#export MAVEN_VERSION=3.2.5
#export M2_HOME=/qa/tools/opt/maven-${MAVEN_VERSION}
#export PATH=$M2_HOME/bin:$PATH
#MAVEN_OPTS="-XX:+UseGCOverheadLimit -Xmx1024m -Xms512m -XX:PermSize=256m -XX:MaxPermSize=768m -Dmaven.repo.local=$repo -Dorg.apache.maven.user-settings=/qa/m2/settings.xml"
MAVEN_OPTS="-XX:+UseGCOverheadLimit -Xmx1024m -Xms512m -XX:PermSize=256m -XX:MaxPermSize=768m"
export MAVEN_OPTS="$MAVEN_OPTS -Dmaven.repo.local=$repo"

#echo "show the maven repo location"
#mvn help:evaluate -Dexpression=settings.localRepository

mkdir download
cd download
# wget http://download.eclipse.org/ee4j/cdi/jakarta.inject-tck-1.0-bin.zip
wget http://download.eclipse.org/jakartaee/dependency-injection/1.0/jakarta.inject-tck-1.0-bin.zip

echo "sha256sum of jakarta.inject-tck-1.0-bin.zip:"
sha256sum jakarta.inject-tck-1.0-bin.zip
unzip jakarta.inject-tck-1.0-bin.zip
cd jakarta.inject-tck-1.0/
echo "copy tck to local maven repo jakarta.inject:jakarta.jakarta.inject-api:jar:1.0"
mvn org.apache.maven.plugins:maven-install-plugin:3.0.0-M1:install-file -Dfile=jakarta.inject-tck-1.0.jar \
  -DgroupId=jakarta.inject \
  -DartifactId=jakarta.inject-api \
  -Dversion=1.0 \
  -Dpackaging=jar \
  -DlocalRepositoryPath=$repo
cd $WORKSPACE

echo "build javax.inject"
git clone https://github.com/eclipse-ee4j/injection-api
cd injection-api
git checkout 1.0
mvn clean install
cd $WORKSPACE

#echo "build tck in $PWD"
#ls 
mvn clean install
ls target
cd example
echo "run tck"
mvn compile test -Dweld.version=$weldVersion

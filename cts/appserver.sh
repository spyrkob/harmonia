#!/bin/bash

source props.sh

preBuiltAppServerZip="${PREBUILD_URL}"

echo "use prebuilt wildfly zip $preBuiltAppServerZip"
mkdir -p build/target
mkdir wf
cd wf
curl -k "$preBuiltAppServerZip" -o wildfly.zip
unzip -q wildfly.zip
rm wildfly.zip
mv * tempname
mv tempname wildfly-prebuilt
zip -r ../build/target/wildfly.zip .
cd ..
ls
echo "custom prebuilt WildFly zip" > build.name
echo "pulling $preBuiltAppServerZip" > build.txt
exit 0;

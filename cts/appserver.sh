#!/bin/bash

yum install -y wget

preBuiltAppServerZip="${BUILD_COMMAND}"

echo "use prebuilt wildfly zip $preBuiltAppServerZip"
mkdir -p build/target
mkdir wf
cd wf
wget --no-check-certificate "$preBuiltAppServerZip" --output-document=wildfly.zip
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

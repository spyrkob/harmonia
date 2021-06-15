#!/bin/bash

yum install -y wget

WGET='wget -q --no-cache --no-check-certificate'

$WGET http://download.eclipse.org/glassfish/glassfish-5.1.0.zip

mv glassfish-5.1.0.zip glassfish.zip

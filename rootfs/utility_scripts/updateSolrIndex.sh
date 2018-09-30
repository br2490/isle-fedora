#!/bin/bash

echo "Okay! Reindexing your Fedora repository. This may take a while..."
cd $CATALINA_HOME/webapps/fedoragsearch/client
fgsUserName=$FEDORA_GSEARCH_USER fgsPassword=$FEDORA_GSEARCH_PASS ./runRESTClient.sh http://localhost:8080 updateIndex fromFoxmlFiles

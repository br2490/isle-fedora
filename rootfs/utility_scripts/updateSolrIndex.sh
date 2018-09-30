#!/bin/bash

echo "Okay! Reindexing your Fedora repository. This may take a while..."
fgsUserName=$FEDORA_GSEARCH_USER fgsPassword=$FEDORA_GSEARCH_PASS .$CATALINA_HOME/webapps/fedoragsearch/client/runRESTClient.sh http://localhost:8080 updateIndex fromFoxmlFiles

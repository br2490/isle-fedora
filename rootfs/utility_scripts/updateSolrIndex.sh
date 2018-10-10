#!/bin/bash

echo 'FedoraGenericSearch (FGS) update Solr index from Fedora helper script.'
RUNNING='ps x --no-headers | grep updateIndex | wc -l'

if [ `eval $RUNNING` -lt 2 ]; then
    echo -e "Starting to reindex your Fedora repository. This process runs in the background and may take some time.\n"
    cd $CATALINA_HOME/webapps/fedoragsearch/client
    fgsUserName=$FEDORA_GSEARCH_USER \
    fgsPassword=$FEDORA_GSEARCH_PASS \
    nohup ./runRESTClient.sh http://localhost:8080 updateIndex fromFoxmlFiles >> $CATALINA_HOME/logs/fgs-update-foxml.out 2>> $CATALINA_HOME/logs/fgs-update-foxml.err < /dev/null &
fi

if [ `eval $RUNNING` -gt 1 ]; then
    echo -e "Checked and this operation is still running. You may disconnect and the process will continue to run.\nFind logs at $CATALINA_HOME/logs/fgs-update-foxml.out and $CATALINA_HOME/logs/fgs-update-foxml.err.\nYou can watch log file 'tail -f $CATALINA_HOME/logs/fedoragsearch.daily.log' as the process runs."
else
    echo 'FAILURE: Operation did not start or is not running as expected. Please contact the Islandora ISLE Google Group @ https://groups.google.com/forum/#!forum/islandora-isle'
fi

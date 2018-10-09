#!/bin/bash

FEDORA_RUNNING=`curl --user $TOMCAT_ADMIN_USER:$TOMCAT_ADMIN_PASS http://localhost:8080/manager/text/list | grep fedora:running | wc -l`
if [ ${FEDORA_RUNNING} -eq "1" ]; then
        echo "Stopping FEDORA."
        curl --user $TOMCAT_ADMIN_USER:$TOMCAT_ADMIN_PASS http://localhost:8080/manager/text/stop?path=/fedora
fi

echo 'Starting the rebuild process in the background. This may take a while depending on your Fedora repository size.'
echo 'To watch the log and process run: tail -f $CATALINA_HOME/logs/fedora-rebuild.out'

cd $FEDORA_HOME/server/bin || exit;
echo 'Truncating old SQL tables.'
mysql -hmysql -u$FEDORA_DB_USER -p$FEDORA_DB_PASS $FEDORA_DB --execute 'TRUNCATE TABLE dcDates; TRUNCATE TABLE doFields; TRUNCATE TABLE doRegistry; TRUNCATE TABLE pidGen;'

sleep 10; # Let the user read.

nohup bash -c 'fedora-rebuild.sh -r org.fcrepo.server.resourceIndex.ResourceIndexRebuilder && \
fedora-rebuild.sh -r org.fcrepo.server.utilities.rebuild.SQLRebuilder && \
curl --user $TOMCAT_ADMIN_USER:$TOMCAT_ADMIN_PASS http://localhost:8080/manager/text/start?path=/fedora' >> $CATALINA_HOME/logs/fedora-rebuild.out 2>> $CATALINA_HOME/logs/fedora-rebuild.err < /dev/null &

echo 'Automatically tailing the log file...'
echo 'Press CTRL+C to stop watching at any time. This will NOT stop the rebuild process.'
sleep 10; # Let the user read.
tail -f $CATALINA_HOME/logs/fedora-rebuild.out

echo 'To watch the log and process run: tail -f $CATALINA_HOME/logs/fedora-rebuild.out'

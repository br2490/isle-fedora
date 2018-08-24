FROM benjaminrosner/isle-tomcat:serverjre8

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG MAVEN_MAJOR
ARG MAVEN_VERSION
ARG ANT_VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="ISLE Fedora Services" \
      org.label-schema.description="ISLE Fedora image, responsible for storing and serving archival repository data." \
      org.label-schema.url="https://islandora-collaboration-group.github.io" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/Islandora-Collaboration-Group/isle-fedora" \
      org.label-schema.vendor="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0" \
      traefik.enable="true" \
      traefik.port="8080" \
      traefik.backend="isle-fedora"

## Dependencies 
RUN GEN_DEP_PACKS="mysql-client \
    python-mysqldb \
    default-libmysqlclient-dev \
    openssl \
    libxml2-dev" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install -y --no-install-recommends $GEN_DEP_PACKS && \
    ## Cleanup phase.
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## Set up environmental variables for tomcat & dependencies installation
ENV FEDORA_HOME=/usr/local/fedora \
    FEDORA_PATH=$PATH:/usr/local/fedora/server/bin:/usr/local/fedora/client/bin \
    PATH=$PATH:/usr/local/fedora/server/bin:/usr/local/fedora/client/bin:/opt/maven/bin:/opt/ant/bin \
    MAVEN_HOME=/opt/maven \
    ANT_HOME=/opt/ant \
    MAVEN_MAJOR=${MAVEN_MAJOR:-3} \
    MAVEN_VERSION=${MAVEN_VERSION:-3.5.4} \
    ANT_VERSION=${ANT_VERSION:-1.10.5}

## ANT AND MAVEN
RUN mkdir -p $ANT_HOME $MAVEN_HOME && \
    cd /tmp && \
    curl -O -L "https://www.apache.org/dyn/closer.cgi?action=download&filename=maven/maven-$MAVEN_MAJOR/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz" && \
    tar xzf /tmp/apache-maven-$MAVEN_VERSION-bin.tar.gz -C $MAVEN_HOME --strip-components=1 && \
    curl -O -L "https://www.apache.org/dyn/closer.cgi?action=download&filename=ant/binaries/apache-ant-$ANT_VERSION-bin.tar.gz" && \
    tar xzf /tmp/apache-ant-$ANT_VERSION-bin.tar.gz -C $ANT_HOME --strip-components=1 && \
    cd $ANT_HOME && \
    ant -f fetch.xml -Ddest=system && \
    ## Cleanup phase.
    rm -rf /tmp/* /var/tmp/* $ANT_HOME/bin/*.bat 

## Copy installation configuration files.
COPY install_properties/ /

## Fedora Installation with Drupalfilter
RUN mkdir -p $FEDORA_HOME /tmp/fedora &&\
    cd /tmp/fedora && \
    wget "https://github.com/fcrepo3/fcrepo/releases/download/v3.8.1/fcrepo-installer-3.8.1.jar" && \
    java -jar fcrepo-installer-3.8.1.jar /usr/local/install.properties && \
    $CATALINA_HOME/bin/startup.sh && \
    ## Docker Hub Auto-builds need some time.
    sleep 90 && \
    rm /usr/local/install.properties && \
    # Setup XACML Policies
    cd $FEDORA_HOME/data/fedora-xacml-policies/repository-policies && \
    git clone https://github.com/Islandora/islandora-xacml-policies.git islandora && \
    cd $FEDORA_HOME/data/fedora-xacml-policies/repository-policies/default && \
    rm deny-inactive-or-deleted-objects-or-datastreams-if-not-administrator.xml && \
    rm deny-policy-management-if-not-administrator.xml && \
    rm deny-unallowed-file-resolution.xml&& \
    rm deny-purge-datastream-if-active-or-inactive.xml && \
    rm deny-purge-object-if-active-or-inactive.xml && \
    rm deny-reloadPolicies-if-not-localhost.xml && \
    cd $FEDORA_HOME/data/fedora-xacml-policies/repository-policies/islandora && \
    rm permit-apim-to-anonymous-user.xml && \
    rm permit-upload-to-anonymous-user.xml && \
    # Drupal Filter
    cd $CATALINA_HOME/webapps/fedora/WEB-INF/lib/ && \
    wget "https://github.com/Islandora/islandora_drupal_filter/releases/download/v7.1.9/fcrepo-drupalauthfilter-3.8.1.jar" && \
    ## Cleanup phase.
    rm -rf /tmp/* /var/tmp/*

###
# Fedora GSearch
# DGI GSearch extensions
##
RUN mkdir /tmp/fedoragsearch && \
    cd /tmp/fedoragsearch && \
    git clone https://github.com/discoverygarden/gsearch.git && \
    git clone https://github.com/discoverygarden/dgi_gsearch_extensions.git && \
    cd /tmp/fedoragsearch/gsearch/FedoraGenericSearch && \
    ant buildfromsource && \
    cd /tmp/fedoragsearch/dgi_gsearch_extensions && \
    mvn -q package && \
    ## Copy FGS and Extensions to their respective locations and deploy
    cp -v /tmp/fedoragsearch/gsearch/FgsBuild/fromsource/fedoragsearch.war $CATALINA_HOME/webapps && \
    unzip -o $CATALINA_HOME/webapps/fedoragsearch.war -d $CATALINA_HOME/webapps/fedoragsearch/ && \
    cp -v /tmp/fedoragsearch/dgi_gsearch_extensions/target/gsearch_extensions-0.1.*-jar-with-dependencies.jar $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/lib && \
    rm $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/lib/log4j-over-slf4j-1.5.10.jar && \
    ## Cleanup phase.
    rm -rf /tmp/* /var/tmp/*

    ## Configuration time. Why in another layer? caching during development.
RUN cd /tmp && \
    git clone --recursive -b 4.10.x https://github.com/discoverygarden/basic-solr-config.git && \
    sed -i "s#localhost:8080#solr:8080#g" /tmp/basic-solr-config/index.properties&& \
    sed -i "s#/usr/local/fedora/solr/collection1/data/index#NOT_USED#g" /tmp/basic-solr-config/index.properties&& \
    sed -i 's#/usr/local/fedora/tomcat#/usr/local/tomcat#g' /tmp/basic-solr-config/foxmlToSolr.xslt && \
    sed -i 's#/usr/local/fedora/tomcat#/usr/local/tomcat#g' /tmp/basic-solr-config/islandora_transforms/*.xslt && \
    cd $CATALINA_HOME/webapps/fedoragsearch/FgsConfig && \
    ## @TODO: ENV ALL OF THIS vvv
    ant -f fgsconfig-basic.xml -Dlocal.FEDORA_HOME=$FEDORA_HOME -DgsearchUser=fgsAdmin -DgsearchPass=ild_fgs_admin_2018 -DfinalConfigPath=$CATALINA_HOME/webapps/fedoragsearch/WEB-INF/classes -DlogFilePath=$FEDORA_HOME/logs -DfedoraUser=fedoraAdmin -DfedoraPass=ild_fed_admin_2018 -DobjectStoreBase=$FEDORA_HOME/data/objectStore -DindexDir=NOT_USED -DindexingDocXslt=foxmlToSolr -DlogLevel=DEBUG -propertyfile fgsconfig-basic-for-islandora.properties && \
    ## END @TODO ^^^
    cp -vr /tmp/basic-solr-config/islandora_transforms $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms && \
    cp -v /tmp/basic-solr-config/foxmlToSolr.xslt $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/foxmlToSolr.xslt && \
    cp -v /tmp/basic-solr-config/index.properties $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/index.properties && \
    ## Cleanup phase.
    rm -rf /tmp/* /var/tmp/* $CATALINA_HOME/webapps/fedora-demo*

COPY rootfs /

VOLUME /usr/local/fedora/data

EXPOSE 8080

ENTRYPOINT ["/init"]
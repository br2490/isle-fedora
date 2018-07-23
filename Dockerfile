FROM benjaminrosner/isle-tomcat:preRC

LABEL "io.github.islandora-collaboration-group.name"="isle-fedora" \
     "io.github.islandora-collaboration-group.description"="ISLE Fedora container, responsible for storing and serving archival repository data." \
     "io.github.islandora-collaboration-group.license"="Apache-2.0" \
     "io.github.islandora-collaboration-group.vcs-url"="git@github.com:Islandora-Collaboration-Group/ISLE.git" \
     "io.github.islandora-collaboration-group.vendor"="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com" \
     "io.github.islandora-collaboration-group.maintainer"="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com"

###
# Dependencies 
RUN GEN_DEP_PACKS="mysql-client \
    python-mysqldb \
    default-libmysqlclient-dev \
    maven \
    ant \
    git \
    openssl \
    libxml2-dev" && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install -y --no-install-recommends $GEN_DEP_PACKS && \
    ## Cleanup phase.
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy installation configuration files.
COPY install_properties/ /

# Set up environmental variables for tomcat & dependencies installation
ENV FEDORA_HOME=/usr/local/fedora \
     FEDORA_PATH=$PATH:/usr/local/fedora/server/bin:/usr/local/fedora/client/bin \
     KAKADU_HOME=/opt/adore-djatoka-1.1/lib/Linux-x86-64 \
     KAKADU_LIBRARY_PATH=/opt/adore-djatoka-1.1/lib/Linux-x86-64 \
     PATH=$PATH:/usr/local/fedora/server/bin:/usr/local/fedora/client/bin \
     CATALINA_OPTS="-Dkakadu.home=/opt/adore-djatoka-1.1/bin/Linux-x86-64 -Djava.library.path=/opt/adore-djatoka-1.1/lib/Linux-x86-64:/usr/local/tomcat/lib -DLD_LIBRARY_PATH=/opt/adore-djatoka-1.1/lib/Linux-x86-64:/usr/local/tomcat/lib"

###
# Djatoka
RUN cd /opt && \
    wget https://sourceforge.mirrorservice.org/d/dj/djatoka/djatoka/1.1/adore-djatoka-1.1.tar.gz && \
    tar -xzf adore-djatoka-1.1.tar.gz && \
    ln -s /opt/adore-djatoka-1.1/bin/Linux-x86-64/kdu_compress /usr/local/bin/kdu_compress && \
    ln -s /opt/adore-djatoka-1.1/bin/Linux-x86-64/kdu_expand /usr/local/bin/kdu_expand && \
    ln -s /opt/adore-djatoka-1.1/lib/Linux-x86-64/libkdu_a60R.so /usr/local/lib/libkdu_a60R.so && \
    ln -s /opt/adore-djatoka-1.1/lib/Linux-x86-64/libkdu_jni.so /usr/local/lib/libkdu_jni.so && \
    ln -s /opt/adore-djatoka-1.1/lib/Linux-x86-64/libkdu_v60R.so /usr/local/lib/libkdu_v60R.so && \
    cp /opt/adore-djatoka-1.1/dist/adore-djatoka.war /usr/local/tomcat/webapps/adore-djatoka.war && \
    unzip -o /usr/local/tomcat/webapps/adore-djatoka.war -d /usr/local/tomcat/webapps/adore-djatoka/ && \
    rm adore-djatoka-1.1.tar.gz && \
    rm /opt/adore-djatoka-1.1/bin/*.bat && \
    sed -i 's#DJATOKA_HOME=`pwd`#DJATOKA_HOME=/opt/adore-djatoka-1.1#g' /opt/adore-djatoka-1.1/bin/env.sh && \
    sed -i 's|`uname -p` = "x86_64"|`uname -m` = "x86_64"|' /opt/adore-djatoka-1.1/bin/env.sh && \
    echo "/opt/adore-djatoka-1.1/lib/Linux-x86-64" > /etc/ld.so.conf.d/kdu_libs.conf && \
    ldconfig && \
    sed -i 's/localhost/isle.localdomain/g' /usr/local/tomcat/webapps/adore-djatoka/index.html

###
# Fedora Installation with Drupalfilter
RUN mkdir -p /tmp/fedora &&\
    cd /tmp/fedora && \
    wget "https://github.com/fcrepo3/fcrepo/releases/download/v3.8.1/fcrepo-installer-3.8.1.jar" && \
    java -jar fcrepo-installer-3.8.1.jar /usr/local/install.properties && \
    $CATALINA_HOME/bin/startup.sh && \
    sleep 45 && \
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
# Place `all the things` in /tmp during install phase: remove cleanup phase to inspect.
RUN mkdir /tmp/fedoragsearch && \
    cd /tmp/fedoragsearch && \
    git clone https://github.com/discoverygarden/dgi_gsearch_extensions.git && \
    cd dgi_gsearch_extensions && \
    mvn -q package && \
    cd /tmp/fedoragsearch && \
    git clone https://github.com/discoverygarden/gsearch.git && \
    cd gsearch/FedoraGenericSearch && \
    ant buildfromsource && \
    git clone -b master https://github.com/discoverygarden/islandora_transforms.git /tmp/islandora_transforms && \
    sed -i 's#/usr/local/fedora/tomcat#/usr/local/tomcat#g' /tmp/islandora_transforms/*.xslt && \
    ## Copy files to their home.
    cp -v /tmp/fedoragsearch/gsearch/FgsBuild/fromsource/fedoragsearch.war $CATALINA_HOME/webapps && \
    unzip -o $CATALINA_HOME/webapps/fedoragsearch.war -d $CATALINA_HOME/webapps/fedoragsearch/ && \
    cp -v /tmp/fedoragsearch/dgi_gsearch_extensions/target/gsearch_extensions-0.1.*-jar-with-dependencies.jar $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/lib && \
    cd $CATALINA_HOME/webapps/fedoragsearch/FgsConfig && \
    ant -f fgsconfig-basic-ISLE.xml && \
    cp -Rv /usr/local/tomcat/webapps/fedoragsearch/FgsConfig/configForIslandora/fgsconfigFinal/. $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/ && \
    cp -Rv /tmp/islandora_transforms $CATALINA_HOME/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms && \
    ## Cleanup phase.
    rm -rf /tmp/* /var/tmp/* $CATALINA_HOME/webapps/fedora-demo*

COPY rootfs /

VOLUME /usr/local/fedora/data

EXPOSE 8080

ENTRYPOINT ["/init"]
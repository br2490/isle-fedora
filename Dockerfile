FROM benjaminrosner/isle-tomcat:latest

LABEL "io.github.islandora-collaboration-group.name"="isle-fedora" \
     "io.github.islandora-collaboration-group.description"="ISLE Fedora container, responsible for storing and serving archival repository data." \
     "io.github.islandora-collaboration-group.license"="Apache-2.0" \
     "io.github.islandora-collaboration-group.vcs-url"="git@github.com:Islandora-Collaboration-Group/ISLE.git" \
     "io.github.islandora-collaboration-group.vendor"="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com" \
     "io.github.islandora-collaboration-group.maintainer"="Islandora Collaboration Group (ICG) - islandora-consortium-group@googlegroups.com"

# Copy installation configuration files first, please.
COPY install_properties/ /

# Set up environmental variables for tomcat & dependencies installation
ENV KAKADU_HOME=/opt/adore-djatoka-1.1/bin/Linux-x86-64 \
     FEDORA_HOME=/usr/local/fedora \
     FEDORA_PATH="$PATH:$FEDORA_HOME/server/bin:$FEDORA_HOME/client/bin" \
     KAKADU_LIBRARY_PATH=/opt/adore-djatoka-1.1/lib/Linux-x86-64 \
     KAKADU_HOME=/opt/adore-djatoka-1.1/lib/Linux-x86-64 \
     LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CATALINA_HOME/lib \
     PATH=$PATH:$FEDORA_HOME/server/bin:$FEDORA_HOME/client/bin \
     CATALINA_OPTS="-Djava.net.preferIPv4Stack=true -Dkakadu.home=/opt/adore-djatoka-1.1/bin/Linux-x86-64 -Djava.library.path=/opt/adore-djatoka-1.1/lib/Linux-x86-64 -DLD_LIBRARY_PATH=/opt/adore-djatoka-1.1/lib/Linux-x86-64"

###
# Dependencies 
RUN GEN_DEP_PACKS="cron \
    tmpreaper \
    mysql-client \
    python-mysqldb \
    default-libmysqlclient-dev \
    maven \
    dnsutils \
    ca-certificates \
    openssl \
    libxml2-dev" && \
	echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install -y $GEN_DEP_PACKS && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "0 */12 * * * root /usr/sbin/tmpreaper -am 4d /tmp >> /var/log/cron.log 2>&1" | tee /etc/cron.d/tmpreaper-cron && \
    chmod 0644 /etc/cron.d/tmpreaper-cron && \
    touch /var/log/cron.log

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
    /sbin/ldconfig && \
    /bin/cp /opt/adore-djatoka-1.1/dist/adore-djatoka.war /usr/local/tomcat/webapps/adore-djatoka.war && \
    /usr/bin/unzip -o /usr/local/tomcat/webapps/adore-djatoka.war -d /usr/local/tomcat/webapps/adore-djatoka/ && \
    rm adore-djatoka-1.1.tar.gz && \
    sed -i 's/DJATOKA_HOME=`pwd`/DJATOKA_HOME=\/opt\/adore-djatoka-1.1/g' /opt/adore-djatoka-1.1/bin/env.sh && \
    sed -i 's|`uname -p` = "x86_64"|`uname -m` = "x86_64"|' /opt/adore-djatoka-1.1/bin/env.sh && \
    touch /etc/ld.so.conf.d/kdu_libs.conf && \
    echo "/opt/adore-djatoka-1.1/lib/Linux-x86-64" > /etc/ld.so.conf.d/kdu_libs.conf && \
    chmod 444 /etc/ld.so.conf.d/kdu_libs.conf && \
    chown root:root /etc/ld.so.conf.d/kdu_libs.conf && \
    sed -i 's/localhost/fedora/g' /usr/local/tomcat/webapps/adore-djatoka/index.html

###
# Fedora Installation with Drupalfilter
RUN cd /usr/local/ && \
    wget "https://github.com/fcrepo3/fcrepo/releases/download/v3.8.1/fcrepo-installer-3.8.1.jar" && \
    /usr/bin/java -jar /usr/local/fcrepo-installer-3.8.1.jar /usr/local/install.properties && \
    /usr/local/tomcat/bin/startup.sh && \
    sleep 45 && \
    rm /usr/local/install.properties && \
    mkdir /usr/local/fedora/data/fedora-xacml-policies/repository-policies/islandora && \
    rm /usr/local/fedora/data/fedora-xacml-policies/repository-policies/default/deny-policy-management-if-not-administrator.xml && \
    rm /usr/local/fedora/data/fedora-xacml-policies/repository-policies/default/deny-purge-datastream-if-active-or-inactive.xml && \
    rm /usr/local/fedora/data/fedora-xacml-policies/repository-policies/default/deny-purge-object-if-active-or-inactive.xml && \
    rm /usr/local/fcrepo-installer-3.8.1.jar && \
    cd /usr/local/tomcat/webapps/fedora/WEB-INF/lib/ && \
    wget "https://github.com/Islandora/islandora_drupal_filter/releases/download/v7.1.9/fcrepo-drupalauthfilter-3.8.1.jar"

###
# Gsearch
#
# Removing log4j-over-slf4j-1.5.10.jar allows gsearch to startup properly.
RUN wget -O /tmp/fedoragsearch-2.8.1.zip https://github.com/discoverygarden/gsearch/releases/download/v2.8.1/fedoragsearch-2.8.1.zip && \
    /usr/bin/unzip -o /tmp/fedoragsearch-2.8.1.zip -d /tmp && \
    /bin/cp -v /tmp/fedoragsearch-2.8.1/fedoragsearch.war /usr/local/tomcat/webapps/ && \
    /usr/bin/unzip -o /usr/local/tomcat/webapps/fedoragsearch.war -d /usr/local/tomcat/webapps/fedoragsearch/ && \
    rm -f /usr/local/tomcat/webapps/fedoragsearch/WEB-INF/lib/log4j-over-slf4j-1.5.10.jar && \
    rm -rf /tmp/gsearch && \
    rm -rf /tmp/fedoragsearch-2.8.1 && \
    /usr/bin/ant -f /usr/local/tomcat/webapps/fedoragsearch/FgsConfig/fgsconfig-basic-ISLE.xml && \
    cp -Rv /usr/local/tomcat/webapps/fedoragsearch/FgsConfig/configForIslandora/fgsconfigFinal/. /usr/local/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/ && \
    /usr/bin/git clone https://github.com/discoverygarden/dgi_gsearch_extensions.git /tmp/dgi_gsearch_extensions && \
    cd /tmp/dgi_gsearch_extensions && \
    /usr/bin/mvn package && \
    /bin/cp /tmp/dgi_gsearch_extensions/target/gsearch_extensions-0.1.3-jar-with-dependencies.jar /usr/local/tomcat/webapps/fedoragsearch/WEB-INF/lib/gsearch_extensions-0.1.3-jar-with-dependencies.jar && \
    /usr/bin/git clone -b master https://github.com/discoverygarden/islandora_transforms.git /tmp/islandora_transforms && \
    sed -i 's#/usr/local/fedora/tomcat#/usr/local/tomcat#g' /tmp/islandora_transforms/*.xslt && \
    /bin/cp -Rv /tmp/islandora_transforms /usr/local/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms && \
    rm -rf /tmp/dgi_gsearch_extensions && \
    rm -rf /tmp/islandora_transforms

COPY rootfs /

VOLUME /usr/local/fedora/data

EXPOSE 8080
CMD ["catalina.sh", "run"]

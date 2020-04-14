FROM tomcat:9.0-jre8

ENV JASPERSERVER_VERSION 7.2.0

# Extract phantomjs, move to /usr/local/share/phantomjs, link to /usr/local/bin.
# In case you wish to download from a different location you can manually
# download the archive and copy from resources/ at build time. Note that you
# also # need to comment out the preceding RUN command
COPY resources/phantomjs*bz2 /tmp/phantomjs.tar.bz2
RUN tar -xjf /tmp/phantomjs.tar.bz2 -C /tmp && \
   rm -f /tmp/phantomjs.tar.bz2 && \
   mv /tmp/phantomjs*linux-x86_64 /usr/local/share/phantomjs && \
   ln -sf /usr/local/share/phantomjs/bin/phantomjs /usr/local/bin

# Execute all in one layer so that it keeps the image as small as possible
# RUN wget "https://sourceforge.net/projects/jasperserver/files/JasperServer/JasperReports%20Server%20Community%20Edition%20${JASPERSERVER_VERSION}/TIB_js-jrs-cp_${JASPERSERVER_VERSION}_bin.zip/download" \
#          -O /tmp/jasperserver.zip  && \
#     unzip /tmp/jasperserver.zip -d /usr/src/ && \
#     rm /tmp/jasperserver.zip && \
#     mv /usr/src/jasperreports-server-cp-${JASPERSERVER_VERSION}-bin /usr/src/jasperreports-server && \
#     rm -r /usr/src/jasperreports-server/samples
#
# To speed up local testing
# Download manually the jasperreport server release to working dir
# Uncomment ADD & RUN commands below and comment out above RUN command
ADD resources/TIB_js-jrs-cp_${JASPERSERVER_VERSION}_bin.zip /tmp/jasperserver.zip
RUN unzip /tmp/jasperserver.zip -d /usr/src/ && \
    rm /tmp/jasperserver.zip && \
    mv /usr/src/jasperreports-server-cp-$JASPERSERVER_VERSION-bin /usr/src/jasperreports-server && \
    rm -r /usr/src/jasperreports-server/samples

# Used to wait for the database to start before connecting to it
# This script is from https://github.com/vishnubob/wait-for-it
# as recommended by https://docs.docker.com/compose/startup-order/
ADD scripts/wait-for-it.sh /wait-for-it.sh

# Used to bootstrap JasperServer the first time it runs and start Tomcat each
ADD scripts/entrypoint.sh /entrypoint.sh
ADD scripts/.do_deploy_jasperserver /.do_deploy_jasperserver

#Execute all in one layer so that it keeps the image as small as possible
RUN chmod a+x /entrypoint.sh && \
    chmod a+x /wait-for-it.sh

# This volume allows JasperServer export zip files to be automatically imported when bootstrapping
VOLUME ["/jasperserver-import"]

# By default, JasperReports Server only comes with Postgres & MariaDB drivers
# Copy over other JBDC drivers the deploy-jdbc-jar ant task will put it in right location
ADD resources/db2jcc4-no-pdq-in-manifest.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/app-srv-jdbc-drivers/db2jcc4.jar
ADD resources/mysql-connector-java-5.1.44-bin.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/app-srv-jdbc-drivers/mysql-connector-java-5.1.44-bin.jar
ADD resources/mssql-jdbc-7.4.1.jre8.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/mssql-jdbc-7.4.1.jre8.jar

# Copy web.xml with cross-domain enable
ADD resources/web.xml /usr/local/tomcat/conf/

# Add WebServiceDataSource plugin
#RUN wget https://community.jaspersoft.com/sites/default/files/releases/jaspersoft_webserviceds_v1.5.zip -O /tmp/webserviceds.zip
ADD resources/jaspersoft_webserviceds_v1.5.zip /tmp/webserviceds.zip
RUN unzip /tmp/webserviceds.zip -d /tmp/ && \
    cp -rfv /tmp/JRS/WEB-INF/* /usr/src/jasperreports-server/buildomatic/conf_source/ieCe/ && \
    sed -i 's/queryLanguagesPro/queryLanguagesCe/g' /usr/src/jasperreports-server/buildomatic/conf_source/ieCe/applicationContext-WebServiceDataSource.xml && \
    rm -rf /tmp/*

# Use the minimum recommended settings to start-up
# as per http://community.jaspersoft.com/documentation/jasperreports-server-install-guide/v561/setting-jvm-options-application-servers
ENV JAVA_OPTS="-Xms1024m -Xmx2048m -XX:PermSize=32m -XX:MaxPermSize=512m -Xss2m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled"

# Wait for DB to start-up, start up JasperServer and bootstrap if required
ENTRYPOINT ["/entrypoint.sh"]

FROM fedora:latest

ENV APP_HOME=/opt/app/
WORKDIR $APP_HOME

#https://github.com/coldfix/certbot-dns-netcup/issues/11
RUN dnf update -y &&\
     dnf install -y certbot python3-pip cronie cronie-anacron &&\
    pip3 install 'dns-lexicon==3.5' &&\ 
    pip3 install certbot-dns-netcup

#copy scripts and make them executable
COPY entrypoint renew ./
RUN chmod +x entrypoint renew

#Create crontab for certificate renewal
ENV RENEW_SH_FILE=${APP_HOME}renew
ENV CRONTAB_FILE=/var/spool/cron/crontabs/root
ENV ENV_FILE=/etc/environment
ENV CRON_LOG_FILE=/var/log/cron
RUN mkdir -p /var/spool/cron/crontabs &&\
    touch ${CRON_LOG_FILE} &&\
    echo "0 */12 * * * ${RENEW_SH_FILE} >> ${CRON_LOG_FILE} \n" >> ${CRONTAB_FILE}

ENV debug="false"

RUN dnf install -y nginx httpd-tools &&\
    useradd -U -M www-data

CMD [ "./entrypoint" ]
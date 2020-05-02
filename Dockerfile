FROM ubuntu:xenial-20200326

ENV APP_HOME=/opt/app/
WORKDIR $APP_HOME

# install certbot and netcup addon
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y software-properties-common
RUN add-apt-repository universe
RUN add-apt-repository ppa:certbot/certbot
RUN apt-get update
RUN apt-get install -y certbot python3 python3-pip
RUN pip3 install certbot-dns-netcup

# install nginx
RUN apt-get install -y nginx 

#copy scripts and make them executable
COPY ./*.sh ./
RUN chmod +x entrypoint.sh renew.sh

#Create crontab for certificate renewal
ENV RENEW_SH_FILE=${APP_HOME}renew.sh
ENV CRONTAB_FILE=/var/spool/cron/crontabs/root
ENV ENV_FILE=/etc/environment
ENV CRON_LOG_FILE=/var/log/cron.log
RUN touch ${CRON_LOG_FILE}
RUN echo "0 */12 * * * ${RENEW_SH_FILE} >> ${CRON_LOG_FILE} 2>&1\n" >> ${CRONTAB_FILE}

ENV debug="false"

CMD [ "./entrypoint.sh" ]
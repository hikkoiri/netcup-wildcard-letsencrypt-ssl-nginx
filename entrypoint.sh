#!/bin/sh

echo "Starting netcup-wildcard-letsencrypt-ssl-nginx"

echo
echo 'Checking if all mandatory env vars are set:'
if [ -z ${domain+x} ]; then
    echo "domain is unset. Exiting";
    exit 1
else
    echo "domain is set"
fi
if [ -z ${email+x} ]; then
    echo "email is unset. Exiting";
    exit 1
else
    echo "email is set"
fi
if [ -z ${netcup_customer_nr+x} ]; then
    echo "netcup_customer_nr is unset. Exiting";
    exit 1
else
    echo "netcup_customer_nr is set"
fi
if [ -z ${netcup_api_key+x} ]; then
    echo "netcup_api_key is unset. Exiting";
    exit 1
else
    echo "netcup_api_key is set"
fi
if [ -z ${netcup_api_password+x} ]; then
    echo "netcup_api_password is unset. Exiting";
    exit 1
else
    echo "netcup_api_password is set"
fi

echo "debug is set to $debug";
if [ $debug = "true" ]; then
    DEBUG_FLAG='--test-cert'
elif [ $debug = "false" ]; then
    DEBUG_FLAG=''
else
    echo "debug can only be set to 'true' or 'false'. Exiting"
    exit 1
fi

echo
NGINX_CONF_FILE=/usr/share/nginx/nginx.conf
echo "Checking if $NGINX_CONF_FILE  exists"
if [ -f "$NGINX_CONF_FILE" ]; then
    echo "$NGINX_CONF_FILE exist"
fi

echo
NETCUP_CREDENTIALS_FILE=${APP_HOME}input/netcup_credentials.ini
echo "Saving netcup credentials in $NETCUP_CREDENTIALS_FILE"
echo "certbot_dns_netcup:dns_netcup_customer_id  = $netcup_customer_nr" >> $NETCUP_CREDENTIALS_FILE
echo "certbot_dns_netcup:dns_netcup_api_key      = $netcup_api_key" >> $NETCUP_CREDENTIALS_FILE
echo "certbot_dns_netcup:dns_netcup_api_password = $netcup_api_password" >> $NETCUP_CREDENTIALS_FILE

echo
echo "Saving current env vars to ${ENV_FILE} for cron job"
env > ${ENV_FILE}

echo
echo 'check if certificate exists and is valid for more that 24 hours'
if openssl x509 -checkend 86400 -noout -in ${APP_HOME}output/cert.pem
then
    echo "Certificate is good for another day!"
else
    echo "Certificate has expired or will do so within 24 hours!"
    echo "(or is invalid/not found)"
    
    # delete the expired certs in case they are invalid
    rm -rf ${APP_HOME}output/*
    
    # fetch certificates with certbot
    certbot certonly \
    --authenticator certbot-dns-netcup:dns-netcup \
    --certbot-dns-netcup:dns-netcup-propagation-seconds 900 \
    --certbot-dns-netcup:dns-netcup-credentials $NETCUP_CREDENTIALS_FILE \
    --no-self-upgrade \
    --keep-until-expiring \
    --non-interactive \
    --expand \
    --server https://acme-v02.api.letsencrypt.org/directory \
    -d $domain \
    -d "*.$domain" \
    --agree-tos \
    --email $email \
    $DEBUG_FLAG
    
    echo
    echo "DONE receiving certificate"
    
    #copy necessary credentials to mounted host directory
    echo
    echo 'Copying certificates into a safe location'
    cp /etc/letsencrypt/live/$domain/cert.pem ${APP_HOME}output
    cp /etc/letsencrypt/live/$domain/privkey.pem ${APP_HOME}output
    
    # delete interim folders
    rm -rf /etc/letsencrypt
    
    #stop certbot doing renewal stuff automagically
    rm -rf /etc/cron.d/certbot
fi

# start nginx with ssl configured
echo
echo "Starting nginx"
nginx -c $NGINX_CONF_FILE


#start the periodoc command scheduler cron for certificate renewal
echo
echo "Starting cron daemon and tailing cron logs:"
crontab $CRONTAB_FILE
cron
tail -f ${CRON_LOG_FILE}

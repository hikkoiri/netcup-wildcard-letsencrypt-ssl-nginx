#!/bin/sh

echo
echo "Checking if certificate is still valid for the next 24 hrs"
echo "Current date & time: $(date)"
if openssl x509 -checkend 86400 -noout -in ${APP_HOME}output/cert.pem
then
    echo "Certificate is good for another day!"
else
    echo "Certificate has expired or will do so within 24 hours!"
    echo "(or is invalid/not found)"
    
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
    
    # delete the expired certs
    rm -rf ${APP_HOME}output/*
    
    #copy necessary credentials to mounted host directory
    echo
    echo 'Copying certificates into a safe location'
    cp /etc/letsencrypt/live/$domain/cert.pem ${APP_HOME}output
    cp /etc/letsencrypt/live/$domain/privkey.pem ${APP_HOME}output
    
    # delete interim folders
    rm -rf /etc/letsencrypt
    
    #stop certbot doing renewal stuff automagically
    rm -rf /etc/cron.d/certbot
    
    #restart nginx
    echo
    echo 'Reloading nginx service'
    service nginx reload
fi
echo END
# netcup-wildcard-letsencrypt-ssl-nginx

> Project is in progess and not tested.

## About

I know, I know, the project is very specific and not interesting for the vast majority. But all I need is a reverse proxy with SSL offloading, which supports wildcard domains.
And of course dockerized. We live in the year 2020.

## Prerequisites

A domain from [netcup](https://www.netcup.de/) and the corresponding customer number, API key and API password.

## Context

HTTPS is the secured version of the application protocol HTTP, which encrypts data in transit and is more or less standard in the world wide web (at least for websites, which handle sensitive information, like login credentials).
The encryption takes place at the Transport Layer Security (TLS) or, formerly, its predecessor, the Secure Sockets Layer (SSL).
That requires encryption keys and certificates, which assure the consumer, that the webserver can be trusted.
These certificates normally cost money. Or you use [LetsEncrypt](https://letsencrypt.org/) - A nonprofit Certificate Authority providing TLS certificates to 200 million websites.

Since March 2018, [Letsencrypt also allows wildcard certificates](https://community.letsencrypt.org/t/acme-v2-and-wildcard-certificate-support-is-live/55579).
That means you only need **ONE** certificate for all of your subdomains( like `foo.example.com` and `bar.example.com`, etc...).
Unfortunately you can only fetch your wildcard certificate over the ACMEv2 protocol, which requires you to use the DNS-01 challenge type. This means that you’ll need to modify DNS TXT records in order to demonstrate control over a domain for the purpose of obtaining a wildcard certificate.
Sounds complicated, but the problem is already solved:
[certbot](https://certbot.eff.org/) is a tool provided by LetsEncrypt, which helps yout to fetch your certificates. You can use different types of authenticators to verify your identity. One of them is the
[certbot-dns-netcup authenticator](https://pypi.org/project/certbot-dns-netcup/), which  is perfect for us, since we bought our domain from Netcup. Hooray!!!

Finally, nginx is a webserver, which is able to consume the certificates and is the totally appropriate for our reverse-proxy use case.

## Functionalities

Goal of this nginx project is to hide away and automate everything in regard to the certificate handling, since it is very complicated for non-experts and a pain to setup.
The app automatically fetches the certificates after startup. When dooing that the first time, the DNS challenge will require 15 minutes, in which the webserver will not be available. After the challenge was executed succesfully, you can use the certificates and serve HTTPS connection.
> Once you received the certificates, they are stored inside the container. To avoid the 15 minute idling every time you spin up a new container, you can reuse the certificates. Just mount the certificates to the host file system and let each container also use this file mount. If the certificates are already present during the container startup, the application will skip the certificate pull process and will reuse the existing certificates.

This application will also check every 12 hours, if the certificates are valid for another day. LetsEncrypt certificates by default expire after 3 month. But don't worry. This application will fetch new certificates, when the old ones are about to expire and will switch them under the hood, without you even noticing.

For testing purposes, this application also provides a debug flag, which will tell the certbot tool to fetch non-production certificates, to avoid running into [rate limit](https://letsencrypt.org/docs/rate-limits/) problems.

## Build the application

### Build and run it on your own

```bash
# plain docker
docker build -t netcup-wildcard-letsencrypt-ssl-nginx:0.0.1 .
docker run \
  -e "debug=true" \
  -e "email=$email" \
  -e "domain=$domain" \
  -e "netcup_customer_nr=$netcup_customer_nr" \
  -e "netcup_api_key=$netcup_api_key" \
  -e "netcup_api_password=$netcup_api_password" \
  -p 80:80 \
  -p 443:443 \
  -v "./:/opt/app/output" \
  -v "./nginx.conf:/usr/share/nginx/nginx.conf" \
  netcup-wildcard-letsencrypt-ssl-nginx:0.0.1

#docker-compose template
cd samples
docker-compose up --build
```

### Be lazy and use the image from Dockerhub

Here is the link: https://hub.docker.com/repository/docker/hikkoiri/netcup-wildcard-letsencrypt-ssl-nginx

Just `docker pull hikkoiri/netcup-wildcard-letsencrypt-ssl-nginx:0.0.1`

## Configuration Possibilities

You can configure the application over environment variables. The key needs to be written in lower case.

|env var|mandatory?| default value | description|
|---|---|---|---|
|debug|no|false| when set to `true` the certificate will be fetched from a staging server. Use that for testing and developing to avoid running into [rate limit](https://letsencrypt.org/docs/rate-limits/) problems|
|email|yes|n/a| needed by certbot|
|domain|yes|n/a| for example: `example-domain.de`|
|netcup_customer_nr|yes|n/a|available from netcup ccp|
|netcup_api_key|yes|n/a| available from netcup ccp|
|netcup_api_password|yes|n/a| available from netcup ccp|

The container most probably needs to expose ports. This configuration can be project specific, but for the most common use case you want to serve:

|protocol|port|
|---|---|
|http|80|
|https|443|

Volume mounts, which are relevant:

|container path|files| description|
|---|---|---|
|/opt/app/output|<ul><li>**cert.pem** - public certificate</li><li>**privkey.pem** - private key, NEVER SHARE THIS ONE WITH SOMEONE</li></ul>|To reuse the certificates, you should mount the following container folders to your host file system|
|/usr/share/nginx/ |<ul><li>**nginx.conf**</li></ul>| This nginx configuration is loaded by the nginx service and needs to be provided by you. To you use the certificates, use the oath above and have a look into the sample nginx.conf provided by me.|

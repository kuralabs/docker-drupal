# Drupal Docker Container

## About

Drupal is a free, open source and online accounting software designed for
small businesses and freelancers. It is built with modern technologies such as
Laravel, Bootstrap, jQuery, RESTful API etc. Thanks to its modular structure,
Drupal provides an awesome App Store for users and developers.

- https://drupal.com/

This repository holds the source of the all-in-one Drupal Docker image
available at:

- https://hub.docker.com/r/kuralabs/docker-drupal/


## Usage

Adapt the following script to your needs:

```bash
#!/usr/bin/env bash

set -o errexit
set -o nounset

# Create mount points
sudo mkdir -p /srv/drupal/mysql
sudo mkdir -p /srv/drupal/logs
sudo mkdir -p /srv/drupal/config

# Stop the running container
docker stop drupal || true

# Remove existing container
docker rm drupal || true

# Pull the new image
docker pull kuralabs/docker-drupal:latest

# Run the container
docker run --detach --init \
    --hostname drupal \
    --name drupal \
    --restart always \
    --publish 8080:8080 \
    --volume /srv/drupal/mysql:/var/lib/mysql \
    --volume /srv/drupal/logs:/var/log \
    --volume /srv/drupal/config:/var/www/drupal/config \
    --env MYSQL_ROOT_PASSWORD="[YOUR_AWESOME_MYSQL_ROOT_PASSWORD]" \
    kuralabs/docker-drupal:latest
```

If you need to set the container to the same time zone as your host machine you
may use the following options:

```
    --env TZ=America/New_York \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
```

You may use the following website to find your time zone:

- http://timezonedb.com/

Then, open `http://localhost:8080/` (or corresponding URL) in your browser
and finish the installation using the web UI.

You can find the parameters for the "Database Setup" step in your container
logs:

```
docker logs drupal
```


### Using behind a SSL terminating reverse proxy

A very common use case is to use a container behind a web server configured as
a reverse proxy and handling the HTTPS connection.

To enable Drupal to work behind a reverse proxy first configure the trusted
proxies. From your host (where you mounted the Drupal configuration files):

```
sudo nano /srv/drupal/config/trustedproxy.php
```

In many cases, and depending on your setup and firewall, the following might be
sufficient:

```
/*
 * Or, to trust all proxies that connect
 * directly to your server, uncomment this:
 */
'proxies' => '*',
```

#### Apache

Use the following configuration to setup the reverse proxy in Apache for
Drupal:

```
# Reverse proxy
ProxyPreserveHost On
ProxyPass / http://0.0.0.0:8080/
ProxyPassReverse / http://0.0.0.0:8080/

RequestHeader set X-Forwarded-Proto "https"
RequestHeader set X-Forwarded-Port "443"
```


#### NGINX

The following is just a guess and hasn't been tested, so if you use Nginx
please confirm if the following configuration works as expected.

```
location / {
    proxy_pass http://0.0.0.0:8080/;

    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Port   443;
    proxy_set_header X-Forwarded-Proto  https;
}
```


### Configuring email to use GSuite - Gmail SMTP

A common setup is to use a Gmail / GSuite account to send emails. To configure
Drupal edit mail configuration as follows:

```
sudo nano /srv/drupal/config/mail.php
```

And change keys to:

```
'driver' => 'smtp',
'host' => 'smtp.gmail.com',
'port' => 587,
'from' => [
    'address' => 'your.email@your-domain.com',
    'name' => 'Your Company Name',
],

'encryption' => 'tls',
'username' => 'your.email@your-domain.com',
'password' => 'YOUR_SMTP_PASSWORD',
```


## Development

Build me with:

```
docker build --tag kuralabs/docker-drupal:latest .
```

In development, run me with:

```
MYSQL_ROOT_PASSWORD=[MYSQL SECURE ROOT PASSWORD] ./run/drupal-dev.sh
```


## License

```
Copyright (C) 2017-2018 KuraLabs S.R.L

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
```

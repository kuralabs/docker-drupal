# Drupal Docker Container

## About

Drupal is content management software. It's used to make many of the websites
and applications you use every day. Drupal has great standard features, like
easy content authoring, reliable performance, and excellent security. But what
sets it apart is its flexibility; modularity is one of its core principles. Its
tools help you build the versatile, structured content that dynamic web
experiences need.

- https://www.drupal.org/

This repository holds the source of the all-in-one Drupal Docker image
available at:

- https://hub.docker.com/r/kuralabs/docker-drupal/


## Usage

Adapt the following script to your needs:

```bash
#!/usr/bin/env bash

set -o errexit
set -o nounset

DRUPAL_APP="myapp"
MYSQL_ROOT_PASSWORD="[YOUR_MYSQL_ROOT_PASSWORD]"

# Create mount points
sudo mkdir -p "/srv/${DRUPAL_APP}/mysql"
sudo mkdir -p "/srv/${DRUPAL_APP}/logs"
sudo mkdir -p "/srv/${DRUPAL_APP}/site"

# Stop the running container
docker stop "${DRUPAL_APP}" || true

# Remove existing container
docker rm "${DRUPAL_APP}" || true

# Pull the new image
docker pull kuralabs/docker-drupal:latest

# Run the container
docker run --detach --init \
    --hostname "${DRUPAL_APP}" \
    --name "${DRUPAL_APP}" \
    --restart always \
    --publish 8080:8080 \
    --volume "/srv/${DRUPAL_APP}/mysql":/var/lib/mysql \
    --volume "/srv/${DRUPAL_APP}/logs":/var/log \
    --volume "/srv/${DRUPAL_APP}/site":/var/www/drupal/sites/default \
    --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    --env DRUPAL_APP="${DRUPAL_APP}" \
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
docker logs "${DRUPAL_APP}"
```


## Development

Build me with:

```
docker build --tag kuralabs/docker-drupal:latest .
```

In development, run me with:

```
MYSQL_ROOT_PASSWORD="[YOUR_MYSQL_ROOT_PASSWORD]" DRUPAL_APP="[YOUR_DRUPAL_APP]" ./run/drupal-dev.sh
```


## License

```
Copyright (C) 2018 KuraLabs S.R.L

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

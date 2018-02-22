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
    --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    --env TZ=America/Costa_Rica \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    kuralabs/docker-drupal:latest

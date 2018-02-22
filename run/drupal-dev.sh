#!/usr/bin/env bash

set -o errexit
set -o nounset

sudo mkdir -p /srv/drupal/mysql
sudo mkdir -p /srv/drupal/logs
sudo mkdir -p /srv/drupal/config

docker stop drupal || true
docker rm drupal || true

docker run --interactive --tty \
    --hostname drupal \
    --name drupal \
    --volume /srv/drupal/mysql:/var/lib/mysql \
    --volume /srv/drupal/logs:/var/log \
    --volume /srv/drupal/config:/var/www/drupal/config \
    --publish 8080:8080 \
    --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    --env TZ=America/Costa_Rica \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    kuralabs/docker-drupal:latest bash

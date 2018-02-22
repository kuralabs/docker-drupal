#!/usr/bin/env bash

set -o errexit
set -o nounset

sudo mkdir -p "/srv/${DRUPAL_APP}/mysql"
sudo mkdir -p "/srv/${DRUPAL_APP}/logs"
sudo mkdir -p "/srv/${DRUPAL_APP}/site"

docker stop "${DRUPAL_APP}" || true
docker rm "${DRUPAL_APP}" || true

docker run --interactive --tty \
    --hostname "${DRUPAL_APP}" \
    --name "${DRUPAL_APP}" \
    --volume "/srv/${DRUPAL_APP}/mysql":/var/lib/mysql \
    --volume "/srv/${DRUPAL_APP}/logs":/var/log \
    --volume "/srv/${DRUPAL_APP}/site":/var/www/drupal/sites/default \
    --publish 8080:8080 \
    --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    --env DRUPAL_APP="${DRUPAL_APP}" \
    --env TZ=America/Costa_Rica \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    kuralabs/docker-drupal:latest bash

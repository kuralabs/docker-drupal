#!/usr/bin/env bash

set -o errexit
set -o nounset

# Create mount points
sudo mkdir -p "/srv/${DRUPAL_APP}/mysql"
sudo mkdir -p "/srv/${DRUPAL_APP}/logs"
sudo mkdir -p "/srv/${DRUPAL_APP}/config"

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
    --volume "/srv/${DRUPAL_APP}/config":"/var/www/${DRUPAL_APP}/config" \
    --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    --env DRUPAL_APP="${DRUPAL_APP}" \
    --env TZ=America/Costa_Rica \
    --volume /etc/timezone:/etc/timezone:ro \
    --volume /etc/localtime:/etc/localtime:ro \
    kuralabs/docker-drupal:latest

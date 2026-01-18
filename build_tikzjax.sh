#!/usr/bin/env bash

# Has issues when pushing new commits to remote
docker compose up --build -d

# Clear all previous layers
# docker compose build --no-cache
# docker compose up # --build --force-recreate -d

mkdir -p output
docker compose cp develop:/code/tikzjax/dist/fonts.css ./output
docker compose cp develop:/code/tikzjax/dist/tikzjax.js ./output

mkdir -p tex_files
docker compose cp develop:/code/tikzjax/tex_files .

docker compose down
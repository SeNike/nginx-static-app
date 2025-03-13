#!/bin/bash

docker build -t nginx-static-app .
yc container registry configure-docker
docker tag nginx-static-app cr.yandex/crpoa9bq12dseorjv6jl/nginx-static-app:latest
docker push cr.yandex/crpoa9bq12dseorjv6jl/nginx-static-app:latest
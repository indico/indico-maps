# Build stage
FROM debian:buster as builder

RUN apt-get update
RUN apt-get install -y build-essential liblua5.1-0 liblua5.1-0-dev libprotobuf-dev libsqlite3-dev protobuf-compiler\
                       shapelib libshp-dev libboost-all-dev osmctools git

RUN mkdir -p /maps/out

RUN cd /tmp && \
    git clone https://github.com/systemed/tilemaker.git && \
    cd tilemaker &&\
    git checkout 6c8c990c662a650475a09e6f2df964ab4510a46f && \
    make && \
    make install

# config file and process script for tilemaker
COPY tilemaker/tiles.json tilemaker/process.lua /maps/
COPY shapes/* maps/shapes/

WORKDIR /maps

# get Switzerland map and crop it to the CERN area
RUN wget https://planet.osm.ch/switzerland.pbf && \
    osmconvert ./switzerland.pbf --complete-ways --out-pbf -b=5.9992195,46.2,6.1225052,46.3168303 > ./cern.osm.pbf

# transform OSM data into vector tiles (.mbtiles file)
RUN tilemaker ./cern.osm.pbf --config tiles.json --output ./out/cern.mbtiles

# second stage, the tile server
# we're not using klokantech/tileserver-gl-light directly because
# it sets /data as a VOLUME, and we want the data to be included
# in the image
FROM node:18-bullseye-slim

ENV NODE_ENV="production"

RUN mkdir /var/run/tileserver && chmod a+w /var/run/tileserver
RUN mkdir /data
RUN mkdir -p /usr/src/app

# maplibre-gl-native install guide for Debian 11 Bullseye
# https://github.com/maplibre/maplibre-gl-native/blob/main/platform/linux/README.md
RUN apt-get -qq update && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    curl \
    wget \
    ccache \
    cmake \
    ninja-build \
    pkg-config \
    xvfb \
    libcurl4-openssl-dev \
    libglfw3-dev \
    libuv1-dev \
    g++-10 \
    libc++-9-dev \
    libc++abi-9-dev \
    libpng-dev \
    libgl1-mesa-dev \
    libgl1-mesa-dri && \
    wget http://archive.ubuntu.com/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8_2.0.3-0ubuntu1_amd64.deb && \
    apt install ./libjpeg-turbo8_2.0.3-0ubuntu1_amd64.deb && \
    wget http://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu66_66.1-2ubuntu2_amd64.deb && \
    apt install ./libicu66_66.1-2ubuntu2_amd64.deb && \
    apt-get clean

RUN cd /usr/src/app && npm install tileserver-gl

# let's take the final product of the build stage
COPY --from=builder /maps/out/cern.mbtiles /data
COPY tileserver/config.json /data/
COPY styles /data/styles
COPY tileserver/run.sh /usr/src/app

EXPOSE 8080
WORKDIR /data
ENTRYPOINT ["/bin/bash", "/usr/src/app/run.sh"]

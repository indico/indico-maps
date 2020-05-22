# Build stage
FROM debian:stretch as builder

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
FROM node:8-stretch

RUN mkdir /var/run/tileserver && chmod a+w /var/run/tileserver
RUN mkdir /data
RUN mkdir -p /usr/src/app

RUN apt-get -qq update \
&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
    apt-transport-https \
    curl \
    unzip \
    build-essential \
    python \
    libcairo2-dev \
    libgles2-mesa-dev \
    libgbm-dev \
    libllvm3.9 \
    libprotobuf-dev \
    libxxf86vm-dev \
    xvfb \
&& apt-get clean

RUN cd /usr/src/app && npm install tileserver-gl

# let's take the final product of the build stage
COPY --from=builder /maps/out/cern.mbtiles /data
COPY tileserver/config.json /data/
COPY styles /data/styles
COPY tileserver/run.sh /usr/src/app

EXPOSE 8080
WORKDIR /data
ENTRYPOINT ["/bin/bash", "/usr/src/app/run.sh"]

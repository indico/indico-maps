# Indico Tile Server (CERN)

This is a simple tile server microservice that we are publishing in hopes of being helpful to others who want to use the map functionality in [Indico 2.2](https://github.com/indico/indico) without a commercial provider.

This repository contains the following assets:
 * **tilemaker** configurations (JSON config file and `process.lua`) that extract relevant features from the OSM data;
 * **map style** that highlights CERN buildings, following the [Mapbox Style Specification](https://www.mapbox.com/mapbox-gl-js/style-spec/);
 * **Dockerfile** which prepares a container that is capable of serving the tiles, based on klokantech's [tileserver-gl](https://github.com/klokantech/tileserver-gl);

The Dockerfile is made up of two stages:
 * the first one downloads the [OpenStreetMap data](https://planet.osm.ch/), crops it to a bounding box and generates an `*.mbtiles` file containing relevant data;
 * the second one sets up a lightweight tileserver-gl using the data generated above;

It should be quite easy to fork this repo and adapt it to your own context. Shape files were generated using [QGIS](https://qgis.org), from OSM data.

This was possible thanks to the [OpenStreetMap project](https://www.openstreetmap.org/).

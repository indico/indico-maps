# Indico Tile Server (CERN)

This is a simple tile server microservice that we are publishing in hopes of being helpful to others who want to use the 
map functionality in [Indico 2.2](https://github.com/indico/indico) without a commercial provider.


## Introduction

The Indico Tile Server is based on the [TileServer GL](https://github.com/klokantech/tileserver-gl) application. Tiles are
the map pieces that are served to the client through HTTP. They are stored in a file
that can be built with the [tilemaker](ttps://github.com/systemed/tilemaker/blob/master/CONFIGURATION.md) application.

`tilemaker` is using [OpenStreetMap](https://www.openstreetmap.org) (OSM) maps as input and
applies some rendering instructions (style) to the input map, using the [Lua](https://www.lua.org)
scripting language. The rendering definition can be based on shapes, typically polygons, that
define areas of the map that must be rendered specifically (for example to highlight the
buildings of your laboratory in a campus). Shapes must be built with a tool like
[QGIS](https://www.qgis.org) and stored in a [shapefile](https://wiki.openstreetmap.org/wiki/Shapefiles).

Even though it is not mandatory, the tile server as provided in this repository is intended to 
be run as a Docker container.  For this reason, this repository provides, in
 addition to configuration files for `tileserver` and `tilemaker`, a Dockerfile to build
the container.
All these files are based on CERN configuration and can be used as templates to build your own
configuration. The documentation below describes the main parameters that need to be customized.

## Building the tileserver container

### Dockerfile

The Dockerfile is made up of two stages: each stage produces a different container.

* the first one downloads the [OpenStreetMap data](https://planet.osm.ch/), crops it to a bounding box and generates an 
`*.mbtiles` file containing relevant data;
  * Relies on [osmconvert](https://wiki.openstreetmap.org/wiki/Osmconvert) tool to extract the region
of interest from an OSM map.
* the second one sets up a lightweight tileserver-gl using the data generated above;

The Dockerfile must be customized to use the proper GPS coordinates and the configuration files you will create in
the next steps, in particular:

* the shapefile passed as a `tilemaker` argument
* the tile file name you want to use for your site, used as the output for the `osmconvert` command and as an argument
to `tilemaker`

### Shapefile

To build a shapefile, you need to use [QGIS](https://www.qgis.org) or a similar tool. See links below for the QGIS
documentation.

The basic steps to create a shapefile are (based on QGIS 3.8):

1. Extract the OSM map of your site. Look at the Dockerfile to see how to do it: it typically involves downloading your OSM region
map from [Geofabrik](https://download.geofabrik.de) and running `osmconvert` to extract the region of interest. Be aware
that loading a region map into QGIS generally doesn't work because it is too big.
1. Open QGIS and create a new project if one was already open
1. Use menu `Layer` -> `Add a layer` -> `Add a vector layer...`. In the `Source` pane, select the file containing your 
OSM site map (extracted during first step) and click the `Add` button: the new layer should appear in the
bottom left pane of the QGIS window.  Click the `Close` button.
1. Use menu `Layer` -> `Create a layer` -> `Create a new shapefile...`. Enter the shapefile file name (it must match
the parameter passed to `tilemaker` in the Dockerfile) and for the
geometry type, select `Polygon`. Accept all other defaults. Click the `Add` button: the shapefile layer should appear in
the bottom left pane of the QGIS window. Click `Close` button.
1. With the shapefile layer selected in the bottom left pane of the QGIS window, click on the pencil icon and then
on the `Add a polygon` button, to the right of the pencil button.
1. On your map, draw a polygon around your site or laboratory buildings, clicking at the position of each vertex. Once
you are done with the polygon, do a right click and accept the default ID (`null`).
1. Repeating the previous step, draw a polygon around each set of buildings you want to identify as part of your
site/laboratory.
1. Once you are done, click again on the pencil button: you should be asked a confirmation that you want to save your
shapefile modifications.
1. Copy the files with `.shq`, `.shx` and `.dbf` extensions to the `shapes` directory of the repository checkout.

### tilemaker configuration

`tilemaker` is using 2 files to drive the tile file creation, located in the `tilemaker` directory:

* tiles.json: defines the different layers (building, roads, waterway...) to add to the tile file. It is important
that each type of object in the map is associated with the proper layer for the rendering customization (styles) to work
as it is based on layers rather than object types. In the CERN `tiles.json`, a layer called "cern_buildings" is created
where all the buildings inside the shapefile polygons are placed. In the `settings` part of this file, you need to
customize the `name` and `description`.
* process.lua: a [Lua](https://www.lua.org) script with a function, `way function()` called for each object in the map.
This function is responsible for defining the attributes of the object that must be displayed. Its main feature is
the selection of whether a building belongs to the site (e.g. CERN) or not. Site-specific buildings are added to a
specific layer ("cern_buildings" in the CERN configuration) and others to the layer "buildings". Also, in the CERN
configuration, only the CERN buildings have their names displayed: it can be easily changed by moving the following
lines out of the "if way:Intersects("cern_sites") then":

```
            if name ~= "" then
                way:LayerAsCentroid("building_names")
                way:Attribute("name", name)
            end
```

You need to ensure that the name of the site-specific layer is the same in the `tiles.json` file and in the 
`process.lua` file.

### Styles

Styles define the rendering applied to the various elements. They are defined in a JSON file stored in the `styles`
directory of the repository. To create your own style, start from the CERN style (`styles/cern.json`) and edit what
is relevant. One of the CERN style features is that buildings are rendered differently depending on whether they
are CERN buildings (buildings located inside the polygons that are part of the shapefile created before) or not.
Normal buildings are rendered in grey whereas CERN buildings are rendered in green.

### tileserver configuration

The `tileserver` configuration file is located in `tileserver/config.json` in the repository.
It contains 2 dictionaries which have normally one key each. The key must be the same in both
dictionaries and will be your site name (used in the tile server URL configured in Indico).

The 2 dictionaries are:

* `data`: it contains an entry `mbtiles` which is the name of the file that contains the map
tiles. It must match the name of the file produced by `tilemaker`.
* `styles`: this dictionary has 2 entries:
  * `styles`: must reflect your style configuration, i.e. the JSON file relative path in the repository
  (e.g. `styles/cern.json`).
  * `tilejson/bounds`: an array of GPS coordinates of your site OSM map (processed by tilemaker)
  for the south-west and the north-east corners with `latitude` the `longitude` for each one.

### Build the container image

As for any Docker container image that you want to build from a Dockerfile, go into the directory
containing the Dockerfile and run the following command:

```
$ docker build . -t indico-maps
```

''Note: `indico-maps` will be the tag of (name referring to) the image. You can use any
name you prefer: nothing in the configuration refers to this name.`

## Running the tile server

### Starting the tileserver

The typical command to run the tileserver container built previously is:

```
$  docker run -dit --restart unless-stopped -p 8080:8080 indico-maps
```

*Note: if you used an image tag different from `indico-maps` when you built the container,
use it when starting the container.*

The command above runs the container as a daemon (`-d`) and ensures it is restarted when Docker
starts (for example after a reboot). If you want to see the tileserver output (logs), you must
use the command `docker attach` with the container ID returned by the `run` command. Type CTRL+C
to exit `docker attach`.

### Testing the tile server

To test your tile server, the easiest way is to use a browser and connect to `http://yourhost:8080`.

### Configuring httpS access to the server

Since your production Indico instance is running on HTTPS, you 
need to use HTTPS for the tile server as well but `tileserver` doesn't support `HTTPS` natively. 
To allow access to the tileserver through HTTPS,
you need to put a reverse proxy in front of it. In the proxy configuration, you need
to ensure that you pass `Host`, `X-Forward-Host` and `X-Forwarded-Scheme` headers to the tileserver.
With nginx, this is done by adding the following lines to the host configuration:

```
proxy_pass_request_headers on;
proxy_set_header Host $http_host;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
```

*Note: `HTTPS` is considered as a requirement otherwise otherwise you will have a mix of HTTP and HTTPS, which 
will trigger a browser warning in the best-case scenario.*

### Using from Indico

To use the tile server in Indico room booking, go to the room booking administration panel and
in the tileserver URL field, enter something similar to:

```
https://your.tileserver.dom.ain/styles/<sitename>/{z}/{x}/{y}.png
```

`<sitename>` must be replaced by the key you used in the dictionaries of your tileserver 
configuration.

## Useful documentation

* tilemaker: see [project](https://github.com/systemed/tilemaker/blob/master/CONFIGURATION.md)
home page
* tileserver: [documentation](https://tileserver.readthedocs.io/en/latest/)
* QGIS: [documentation and tutorial](https://www.qgis.org/en/docs)

## Credits

This was possible thanks to the [OpenStreetMap project](https://www.openstreetmap.org/).

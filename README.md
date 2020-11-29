# Elm Location using Geocoding

Sample Elm application demonstrating model-view-update with ports and HTTP requests.

The app displays locations (latitude & longitude) of an address in the US or Canada you provide, or as fetched from your web browser's navigator.geolocation object.

Addresses are resolved using the geocod.io API as shown below,
  `curl "https://api.geocod.io/v1.6/geocode?q=1109+N+Highland+St%2c+Arlington+VA&api_key=YOUR_API_KEY"`

Register for an API_KEY at [https://geocod.io] and store in the environment variable `ELM_GEOCODIO_API_KEY`.~

NOTE: Prototyping using `http-server` which does not read Node Environment variables. The API_KEY is hardcoded in index.html.
Do not push git repo!


## Development steps

Compile - `npm run build` or `npm run build:debug`
  Recommend using `build:debug` for development as this will give you time traveling debugging in the browser.

Watch - `npm run watch`

Serve locally - `npm start`
  Serves web page on localhost:8080. Required to setup the `ports` and Geocod.io API_KEY.

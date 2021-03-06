# Elm Location using Geocoding

Sample Elm application demonstrating model-view-update with ports and HTTP requests.

The app displays locations (latitude & longitude) of an address in the US or Canada you provide, or as fetched from your web browser's navigator.geolocation object.

Addresses are resolved using the geocod.io API as shown below,
  `curl "https://api.geocod.io/v1.6/geocode?q=1109+N+Highland+St%2c+Arlington+VA&api_key=YOUR_API_KEY"`

## Acknowledgements

Display of the Google Map makes use of Simonh1000's modifications to the google-maps web component. Changed files for maps and markers are committed in the `assets` directory. See original notes: https://simonh1000.github.io/2019/08/elm-google-map-webcomponent/


## Development steps

Build - `npm run build` or `npm run build:debug`
  Recommend using `build:debug` for development as this will give you time traveling debugging in the browser.

Serve locally - `npm start`
  Serves web page on localhost:3000 via webpack-dev-server. This watches and reloads automatically. Required to setup the `ports`.

Build watching - `npm run watch`. Useful for compiling only.

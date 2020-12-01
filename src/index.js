'use strict';

require('./index.html');

import * as map from '../assets/@em-polymer/google-map/google-map';

const { Elm } = require('./Main.elm');

const flags = {
    geocodioApiKey: process.env.GEOCODIO_API_KEY,
    googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY,
}

var app = Elm.Main.init({
    flags: flags
});

app.ports.getLocation.subscribe(() => {
    if (navigator.geolocation) {
        //console.info('Called requested current location');
        navigator.geolocation.getCurrentPosition(
            function(position) {
                var data = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude
                };
                // elm 0.19 needs this to be async
                setTimeout(function () {
                    app.ports.setLocation.send(data);
                }, 0);
            },
            function(error) {
                //console.info(error.message, error.code);
                setTimeout(function () {
                    app.ports.onError.send(error.code);
                }, 0);
            });
    }
    else {
        console.error('navigator.geolocation not available.');
    }
});

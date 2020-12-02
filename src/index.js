'use strict';

import * as map from '../assets/@em-polymer/google-map/google-map';

const { Elm } = require('./Main.elm');

const flags = {
    geocodioApiKey: process.env.GEOCODIO_API_KEY,
    googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY,
}

const googleMapId = 'my-map-id';
const googleMapMarkerId = 'my-map-marker-id';

var app = Elm.Main.init({
    node: document.getElementById('main'),
    flags: flags
});

app.ports.getLocation.subscribe(() => {
    if (!navigator.geolocation) {
        console.error('navigator.geolocation not available.');
        return;
    }

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
});


app.ports.addMarker.subscribe((latLng) =>  {

    const { latitude, longitude } = latLng;

    var map = document.getElementById(googleMapId);
    if (!map) return;

    var marker = document.getElementById(googleMapMarkerId);
    if (!marker) return;

    console.info('setting latitude longitude on marker', JSON.stringify(latLng));

    map.setAttribute('latitude', latitude);
    map.setAttribute('longitude', longitude);
    map.setAttribute('zoom', '10');
    marker.setAttribute('latitude', latitude);
    marker.setAttribute('longitude', longitude);

});

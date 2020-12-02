port module Main exposing (main)

import Bootstrap.Button as Button
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Text as Text
import Bootstrap.Utilities.Spacing as Spacing
import Browser
import Html exposing (Html, div, h4, p, text)
import Html.Attributes as Attr
import Http
import Json.Decode as Decode exposing (Decoder, Error(..), Value, decodeValue)
import Json.Encode as Encode
import Url.Builder exposing (crossOrigin, string)


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Form =
    { street : String
    , city : String
    , state : String
    }


type alias ApiKeys =
    { googleApiKey : String
    , geocodioApiKey : String
    }


type LatLng
    = LatLng Float Float


type PageState
    = Idle
    | Loading
    | Error String


type alias Model =
    { form : Form
    , apiKeys : ApiKeys
    , latLng : Maybe LatLng
    , pageState : PageState
    }



-- trigger navigator.geolocation call


port getLocation : () -> Cmd msg


port setLocation : (Value -> msg) -> Sub msg


port onError : (Int -> msg) -> Sub msg


port addMarker : Value -> Cmd msg


empty =
    { form = Form "" "" "", latLng = Nothing, pageState = Idle, apiKeys = ApiKeys "" "" }


init : Value -> ( Model, Cmd Msg )
init value =
    case decodeFlags value of
        Ok flags ->
            ( { empty | apiKeys = flags }, Cmd.none )

        Err err ->
            ( { empty | pageState = Error ("Bad configuration. Missing API keys." ++ Decode.errorToString err) }, Cmd.none )


decodeFlags : Value -> Result Error ApiKeys
decodeFlags value =
    Decode.decodeValue flagsDecoder value


flagsDecoder : Decoder ApiKeys
flagsDecoder =
    Decode.map2 ApiKeys
        (Decode.field "googleMapsApiKey" Decode.string)
        (Decode.field "geocodioApiKey" Decode.string)


type Msg
    = FormStreetMsg String
    | FormCityMsg String
    | FormStateMsg String
    | FormSubmitMsg
    | FormSubmitResult (Result Http.Error (List LatLng))
    | GeoFetchMsg
    | LocationReceived (Result Decode.Error LatLng)
    | LocationError Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FormStreetMsg str ->
            ( { model | form = updateNestedField model.form (\f -> { f | street = str }) }, Cmd.none )

        FormCityMsg str ->
            ( { model | form = updateNestedField model.form (\f -> { f | city = str }) }, Cmd.none )

        FormStateMsg str ->
            ( { model | form = updateNestedField model.form (\f -> { f | state = str }) }, Cmd.none )

        FormSubmitMsg ->
            -- send address to geocod.io
            -- https://api.geocod.io/v1.6/geocode?q=1109+N+Highland+St%2c+Arlington+VA&api_key=YOUR_API_KEY
            -- result is res.results[0].location.{lat,lng}
            let
                url =
                    crossOrigin
                        "https://api.geocod.io"
                        [ "v1.6", "geocode" ]
                        [ string "q" (String.join " " [ model.form.street, model.form.city, model.form.state ])
                        , string "api_key" model.apiKeys.geocodioApiKey
                        ]
            in
            ( { model | latLng = Nothing, pageState = Loading }
            , Http.get
                { url = url
                , expect = Http.expectJson FormSubmitResult geocodioDecoder
                }
            )

        FormSubmitResult result ->
            case result of
                Ok val ->
                    let
                        maybeLatLng =
                            List.head val
                    in
                    case maybeLatLng of
                        Nothing ->
                            ( { model | latLng = Nothing, pageState = Idle }, Cmd.none )

                        Just latLng ->
                            ( { model | latLng = Just latLng, pageState = Idle }, encodeLocation latLng |> addMarker )

                Err err ->
                    case err of
                        Http.BadBody decodeErr ->
                            ( { model | latLng = Nothing, pageState = Error decodeErr }, Cmd.none )

                        Http.BadStatus _ ->
                            ( { model | latLng = Nothing, pageState = Error "No results. Check your input was a valid address." }, Cmd.none )

                        _ ->
                            ( { model | latLng = Nothing, pageState = Error "Request not completed. Server or network error occurred." }, Cmd.none )

        GeoFetchMsg ->
            ( { model | latLng = Nothing, pageState = Loading }, getLocation () )

        LocationReceived result ->
            case result of
                Ok val ->
                    let
                        latLng =
                            Just val
                    in
                    ( { model | latLng = latLng, pageState = Idle }, encodeLocation val |> addMarker )

                Err err ->
                    ( { model | latLng = Nothing, pageState = Error (Decode.errorToString err) }, Cmd.none )

        LocationError code ->
            ( { model | latLng = Nothing, pageState = errorCodeDesc code }, Cmd.none )


updateNestedField : form -> (form -> form) -> form
updateNestedField form fn =
    fn form


encodeLocation : LatLng -> Encode.Value
encodeLocation (LatLng lat lng) =
    Encode.object
        [ ( "latitude", Encode.float lat )
        , ( "longitude", Encode.float lng )
        ]


geocodioDecoder : Decoder (List LatLng)
geocodioDecoder =
    Decode.field "results" (Decode.list resultDecoder)


resultDecoder : Decoder LatLng
resultDecoder =
    Decode.field "location" geoResultLocationDecoder


geoResultLocationDecoder : Decoder LatLng
geoResultLocationDecoder =
    Decode.map2 LatLng
        (Decode.field "lat" Decode.float)
        (Decode.field "lng" Decode.float)


errorCodeDesc : Int -> PageState
errorCodeDesc e =
    case e of
        1 ->
            Error "PERMISSION_DENIED"

        2 ->
            Error "POSITION_UNAVAILABLE"

        3 ->
            Error "TIMEOUT"

        _ ->
            Error "UNKNOWN"


view : Model -> Html Msg
view model =
    div []
        [ pageContent model
        ]


pageContent : Model -> Html Msg
pageContent model =
    div []
        [ Grid.container [ Spacing.mt5 ]
            [ Grid.row
                gridRowOptions
                [ Grid.col
                    gridColOptions
                    (buildFormCard model)
                , Grid.col
                    gridColOptions
                    [ text "- OR -" ]
                , Grid.col
                    gridColOptions
                    (buildFetchCard model)
                ]
            , Grid.row
                gridRowOptions
                [ Grid.col
                    gridColOptions
                    (buildResultsView model)
                ]
            ]
        ]


gridRowOptions : List (Row.Option msg)
gridRowOptions =
    [ Row.middleMd, Row.centerMd, Row.attrs [ Spacing.py2 ] ]


gridColOptions : List (Col.Option msg)
gridColOptions =
    [ Col.lg
    , Col.textAlign Text.alignMdCenter
    ]


cardOptions : List (Card.Option msg)
cardOptions =
    [ Card.light, Card.outlineDark ]


blockOptions : List (Block.Option msg)
blockOptions =
    []


buildFormCard : Model -> List (Html Msg)
buildFormCard model =
    [ Card.config
        cardOptions
        |> Card.block
            blockOptions
            [ Block.titleH5 [] [ text "Enter your address" ]
            , Form.form
                []
                [ Form.group []
                    [ Form.label [ Attr.for "street" ] [ text "Street Address" ]
                    , Input.text
                        [ Input.id "street"
                        , isModelLoading model
                            |> Input.disabled
                        , Input.onInput FormStreetMsg
                        , Input.placeholder "123 Sesame Street"
                        ]
                    ]
                , Form.group []
                    [ Form.label [ Attr.for "city" ] [ text "City" ]
                    , Input.text
                        [ Input.id "city"
                        , isModelLoading model
                            |> Input.disabled
                        , Input.onInput FormCityMsg
                        , Input.placeholder "Hartford"
                        ]
                    ]
                , Form.group []
                    [ Form.label [ Attr.for "state" ] [ text "State" ]
                    , Input.text
                        [ Input.id "state"
                        , isModelLoading model
                            |> Input.disabled
                        , Input.onInput FormStateMsg
                        , Input.placeholder "CT, MA, TX"
                        ]
                    ]
                , Button.submitButton
                    [ Button.primary
                    , Button.onClick FormSubmitMsg
                    , isFormIncomplete model
                        || isModelLoading model
                        |> Button.disabled
                    ]
                    [ text "Lookup" ]
                ]
                |> Block.custom
            ]
        |> Card.view
    ]


buildFetchCard : Model -> List (Html Msg)
buildFetchCard model =
    [ Card.config
        cardOptions
        |> Card.block
            blockOptions
            [ Block.titleH5 [] [ text "Fetch your address" ]
            , Block.text [] [ text "We will query the location from your browser." ]
            , Button.button
                [ Button.primary
                , Button.onClick GeoFetchMsg
                , isApiKeyUnavailable model
                    || isModelLoading model
                    |> Button.disabled
                ]
                [ text "Fetch" ]
                |> Block.custom
            ]
        |> Card.view
    ]


buildResultsView : Model -> List (Html Msg)
buildResultsView model =
    [ h4 [] [ text "Your location info" ]
    , viewText model
    , googleMap model.apiKeys.googleApiKey
    ]


viewText : Model -> Html Msg
viewText model =
    case model.pageState of
        Loading ->
            p [] [ text "Retrieving results..." ]

        Error err ->
            p [] [ text err ]

        Idle ->
            case model.latLng of
                Nothing ->
                    p [] [ text "No results." ]

                Just latLng ->
                    p [] [ latLng |> toText |> text ]


googleMap : String -> Html Msg
googleMap apiKey =
    let
        -- default geographic center of USA 37.0902° N, 95.7129 W
        latLng =
            LatLng 37.0902 -95.7129
    in
    Html.node "google-map"
        [ Attr.id "my-map-id"
        , Attr.attribute "api-key" apiKey
        , Attr.attribute "latitude" <| String.fromFloat <| toLatitude latLng
        , Attr.attribute "longitude" <| String.fromFloat <| toLongitude latLng
        , Attr.attribute "zoom" "5"
        , Attr.style "height" "500px"
        ]
        [ googleMapMarker
        ]


googleMapMarker : Html Msg
googleMapMarker =
    Html.node "google-map-marker"
        [ Attr.id "my-map-marker-id"

        -- , Attr.attribute "latitude" <| String.fromFloat <| toLatitude latLng
        -- , Attr.attribute "longitude" <| String.fromFloat <| toLongitude latLng
        -- , Attr.attribute "label" "[Your address here]"
        ]
        []


toLatitude : LatLng -> Float
toLatitude (LatLng lat lng) =
    lat


toLongitude : LatLng -> Float
toLongitude (LatLng lat lng) =
    lng


isFormIncomplete : Model -> Bool
isFormIncomplete m =
    if m.form.street == "" || m.form.city == "" || m.form.state == "" then
        True

    else
        False


isModelLoading : Model -> Bool
isModelLoading m =
    case m.pageState of
        Loading ->
            True

        _ ->
            False


isApiKeyUnavailable : Model -> Bool
isApiKeyUnavailable model =
    model.apiKeys.geocodioApiKey == ""


toText : LatLng -> String
toText (LatLng lat lng) =
    String.fromFloat lat ++ " / " ++ String.fromFloat lng


locationDecoder : Decoder LatLng
locationDecoder =
    Decode.map2 LatLng
        (Decode.field "latitude" Decode.float)
        (Decode.field "longitude" Decode.float)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ setLocation (Decode.decodeValue locationDecoder >> LocationReceived)
        , onError LocationError
        ]

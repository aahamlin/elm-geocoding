port module Main exposing (main)

--import Html.Attributes.Extra exposing (attributeIf)

import Bootstrap.Button as Button
import Bootstrap.CDN as CDN
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Row
import Bootstrap.Text as Text
import Bootstrap.Utilities.Flex as Flex
import Bootstrap.Utilities.Spacing as Spacing exposing (m0)
import Browser
import Html exposing (Html, div, h4, p, text)
import Html.Attributes as Attr
import Http
import Json.Decode as Decode exposing (Decoder, Error(..), Value, decodeValue)
import Url.Builder exposing (crossOrigin, string)


main =
    Browser.document
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


type LatLng
    = LatLng Float Float


type PageState
    = Idle
    | Loading
    | Error String


type alias Model =
    { form : Form
    , apiKey : String
    , latLng : Maybe LatLng
    , pageState : PageState
    }



-- trigger navigator.geolocation call


port getLocation : () -> Cmd msg


port setLocation : (Value -> msg) -> Sub msg


port onError : (Int -> msg) -> Sub msg


empty =
    { form = Form "" "" "", latLng = Nothing, pageState = Idle, apiKey = "" }


init : String -> ( Model, Cmd Msg )
init geocodioApiKey =
    ( { empty | apiKey = geocodioApiKey }, Cmd.none )


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
            ( { model | form = formUpdate model.form (\f -> { f | street = str }) }, Cmd.none )

        FormCityMsg str ->
            ( { model | form = formUpdate model.form (\f -> { f | city = str }) }, Cmd.none )

        FormStateMsg str ->
            ( { model | form = formUpdate model.form (\f -> { f | state = str }) }, Cmd.none )

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
                        , string "api_key" model.apiKey
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
                    ( { model | latLng = List.head val, pageState = Idle }, Cmd.none )

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
                    ( { model | latLng = Just val, pageState = Idle }, Cmd.none )

                Err err ->
                    ( { model | latLng = Nothing, pageState = Error (Decode.errorToString err) }, Cmd.none )

        LocationError code ->
            ( { model | latLng = Nothing, pageState = errorCodeDesc code }, Cmd.none )


formUpdate : Form -> (Form -> Form) -> Form
formUpdate form fn =
    fn form


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


view : Model -> Browser.Document Msg
view model =
    { title = "Location example"
    , body =
        [ div []
            [ CDN.stylesheet
            , pageContent model
            ]
        ]
    }


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
                        |> orThen (isModelLoading model)
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
                    |> orThen (isModelLoading model)
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
    , case model.pageState of
        Loading ->
            p [] [ text "Retrieving results..." ]

        Error err ->
            p [] [ text err ]

        Idle ->
            case model.latLng of
                Nothing ->
                    p [] [ text "No results." ]

                Just latLng ->
                    loadMap latLng
    ]


loadMap : LatLng -> Html Msg
loadMap latLng =
    div []
        [ p [] [ latLng |> toText |> text ]
        , googleMap latLng
        ]


googleMap : LatLng -> Html Msg
googleMap latLng =
    Html.node "google-map"
        [ Attr.attribute "api-key" "AIzaSyCNArtmybelM_OqNmncJd82TBAf0xoBH9g"
        , Attr.attribute "latitude" <| String.fromFloat <| toLatitude latLng
        , Attr.attribute "longitude" <| String.fromFloat <| toLongitude latLng
        , Attr.style "height" "500px"
        ]
        [ googleMapMarker latLng
        ]


googleMapMarker : LatLng -> Html Msg
googleMapMarker latLng =
    Html.node "google-map-marker"
        [ Attr.attribute "latitude" <| String.fromFloat <| toLatitude latLng
        , Attr.attribute "longitude" <| String.fromFloat <| toLongitude latLng
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
    model.apiKey == ""


orThen : Bool -> Bool -> Bool
orThen a b =
    a || b


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

port module Main exposing (main)

import Bitwise exposing (complement)
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
import Bootstrap.Utilities.Spacing as Spacing
import Browser
import Html exposing (Html, div, h4, p, text)
import Html.Attributes as Attr
import Html.Attributes.Extra exposing (attributeIf)
import Html.Events as Evt
import Json.Decode as Decode exposing (Decoder, Error(..), Value, decodeValue)


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
    , latLng : Maybe LatLng
    , pageState : PageState
    }



-- trigger navigator.geolocation call


port getLocation : () -> Cmd msg


port setLocation : (Value -> msg) -> Sub msg


port onError : (Int -> msg) -> Sub msg


empty =
    { form = Form "" "" "", latLng = Nothing, pageState = Idle }


init : () -> ( Model, Cmd Msg )
init () =
    ( empty, Cmd.none )


type Msg
    = FormStreetMsg String
    | FormCityMsg String
    | FormStateMsg String
    | FormSubmitMsg
    | GeoFetchMsg
    | LocationReceived (Result Decode.Error LatLng)
    | LocationError Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Debug.log "update" msg of
        FormStreetMsg str ->
            ( { model | form = setStreet str model.form }, Cmd.none )

        FormCityMsg str ->
            ( { model | form = setCity str model.form }, Cmd.none )

        FormStateMsg str ->
            ( { model | form = setState str model.form }, Cmd.none )

        FormSubmitMsg ->
            ( model, Cmd.none )

        GeoFetchMsg ->
            ( { model | latLng = Nothing, pageState = Loading }, getLocation () )

        LocationReceived res ->
            case res of
                Ok val ->
                    ( { model | latLng = Just val, pageState = Idle }, Cmd.none )

                Err err ->
                    ( { model | latLng = Nothing, pageState = Error (Decode.errorToString err) }, Cmd.none )

        LocationError code ->
            ( { model | latLng = Nothing, pageState = errorCodeDesc code }, Cmd.none )


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


setStreet : String -> Form -> Form
setStreet val form =
    { form | street = val }


setState : String -> Form -> Form
setState val form =
    { form | state = val }


setCity : String -> Form -> Form
setCity val form =
    { form | city = val }


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
    let
        isFormIncomplete m =
            if m.form.street == "" || m.form.city == "" || m.form.state == "" then
                True

            else
                isModelLoading m

        isModelLoading m =
            case m.pageState of
                Loading ->
                    True

                _ ->
                    False
    in
    div []
        [ Grid.container [ Spacing.mt5 ]
            [ Grid.row
                [ Row.middleMd, Row.centerMd, Row.attrs [ Spacing.py5 ] ]
                [ Grid.col
                    [ Col.lg4 ]
                    [ Card.config [ Card.light, Card.outlineDark ]
                        |> Card.block []
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
                                        |> Button.disabled
                                    ]
                                    [ text "Lookup" ]
                                ]
                                |> Block.custom
                            ]
                        |> Card.view
                    ]
                , Grid.col
                    [ Col.lg2
                    , Col.textAlign Text.alignMdCenter
                    ]
                    [ text "- OR -" ]
                , Grid.col
                    [ Col.lg4 ]
                    [ Card.config [ Card.light, Card.outlineDark ]
                        |> Card.block []
                            [ Block.titleH5 [] [ text "Fetch your address" ]
                            , Block.text [] [ text "We will query the location from your browser." ]
                            , Button.button
                                [ Button.primary
                                , Button.onClick GeoFetchMsg
                                ]
                                [ text "Fetch" ]
                                |> Block.custom
                            ]
                        |> Card.view
                    ]
                ]
            , Grid.row
                [ Row.middleMd, Row.centerMd, Row.attrs [ Spacing.py5 ] ]
                [ Grid.col
                    [ Col.lg
                    , Col.textAlign Text.alignMdCenter
                    ]
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
                                    p [] [ latLng |> toText |> text ]
                    ]
                ]
            ]
        ]


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

module Main exposing (Model, Msg(..), init, main, update, view)

import Browser
import Dict exposing (Dict)
import File exposing (File)
import File.Download as Download
import File.Select as Select
import Html exposing (Html, button, div, p, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Task



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    { csv : Maybe String }


type alias SensorRecord =
    { timestamp : String
    , sensorId : Int
    , long : Float
    , lat : Float
    , cpm : Int
    }


type Direction
    = ASC
    | DESC


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model Nothing, Cmd.none )



-- UPDATE


type Msg
    = CsvRequested
    | TrajectoryAndSaveRequested
    | SimplifyAndSaveRequested
    | SegmentAndSaveRequested
    | CsvSelected File
    | CsvLoaded String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CsvRequested ->
            ( model
            , Select.file [ "text/csv" ] CsvSelected
            )

        CsvSelected file ->
            ( model
            , Task.perform CsvLoaded (File.toString file)
            )

        CsvLoaded content ->
            ( { model | csv = Just content }
            , Cmd.none
            )

        TrajectoryAndSaveRequested ->
            ( model, trajAndSave (model.csv |> Maybe.withDefault "No content") )

        SimplifyAndSaveRequested ->
            ( model, simplifyAndSave (model.csv |> Maybe.withDefault "No content") )

        SegmentAndSaveRequested ->
            ( model, segmentAndSave (model.csv |> Maybe.withDefault "No content") )


strToInt : String -> Int
strToInt =
    String.toInt >> Maybe.withDefault -1


strToFloat : String -> Float
strToFloat =
    String.toFloat >> Maybe.withDefault -1


simplifyAndSave : String -> Cmd msg
simplifyAndSave =
    let
        toRecord tokens =
            case tokens of
                [ ts, sid, lng, lat, cpm, _ ] ->
                    SensorRecord ts (strToInt sid) (strToFloat lng) (strToFloat lat) (strToFloat cpm |> round)

                _ ->
                    SensorRecord "" -1 -1 -1 -1

        fromRecord r =
            String.fromInt r.sensorId
                ++ ","
                ++ r.timestamp
                ++ ","
                ++ String.fromFloat r.long
                ++ ","
                ++ String.fromFloat r.lat
                ++ ","
                ++ String.fromInt r.cpm
                ++ "\n"
    in
    String.split "\n"
        >> List.drop 1
        >> List.map (String.split "," >> toRecord)
        >> thin
        >> List.map fromRecord
        >> String.concat
        >> (++) "sensorId,timestamp,long,lat,cpm\n"
        >> Download.string "simplified.csv" "text/csv"


trajAndSave : String -> Cmd msg
trajAndSave =
    let
        toRecord tokens =
            case tokens of
                [ ts, sid, lng, lat, cpm, _ ] ->
                    SensorRecord ts (strToInt sid) (strToFloat lng) (strToFloat lat) (strToFloat cpm |> round)

                _ ->
                    SensorRecord "" -1 -1 -1 -1

        fromRecord r =
            String.fromInt r.sensorId
                ++ ","
                ++ String.fromFloat r.long
                ++ ","
                ++ String.fromFloat r.lat
                ++ "\n"
    in
    String.split "\n"
        >> List.drop 1
        >> List.map (String.split "," >> toRecord)
        >> List.sortWith (by .sensorId ASC |> andThen .timestamp ASC)
        >> thinTraj
        >> List.map fromRecord
        >> String.concat
        >> (++) "sensorId,long,lat\n"
        >> Download.string "trajectories.csv" "text/csv"


{-| Requires a list of coordinates sorted by sid and time and will then remove
any consecutive records that share the same location.
-}
thinTraj : List SensorRecord -> List SensorRecord
thinTraj =
    let
        addIfNewLocation rec records =
            case records of
                [] ->
                    [ rec ]

                hd :: tl ->
                    if hd.long == rec.long && hd.lat == rec.lat then
                        records

                    else
                        rec :: records
    in
    List.foldr addIfNewLocation []


segmentAndSave : String -> Cmd msg
segmentAndSave input =
    let
        toRecord : List String -> SensorRecord
        toRecord tokens =
            case tokens of
                [ sid, ts, lng, lat, cpm ] ->
                    SensorRecord ts (strToInt sid) (strToFloat lng) (strToFloat lat) (strToFloat cpm |> round)

                _ ->
                    SensorRecord "" -1 -1 -1 -1

        fromRecord : Int -> Int -> SensorRecord -> String
        fromRecord seconds segNum r =
            String.fromInt r.sensorId
                ++ ","
                ++ r.timestamp
                ++ ","
                ++ String.fromInt seconds
                ++ ","
                ++ String.fromFloat r.long
                ++ ","
                ++ String.fromFloat r.lat
                ++ ","
                ++ String.fromInt r.cpm
                ++ ","
                ++ String.fromInt segNum
                ++ "\n"

        records : Int -> List SensorRecord
        records sid =
            input
                |> String.split "\n"
                |> List.drop 1
                |> List.map (String.split "," >> toRecord)
                |> List.filter (\r -> r.sensorId == sid)

        trajectories : Int -> List String -> List String
        trajectories sid trajs =
            trajs ++ (records sid |> List.map3 fromRecord (secondsColumn (records sid)) (distColumn (records sid)))
    in
    List.foldl trajectories [] (List.range 1 50)
        |> String.concat
        |> (++) "sensorId,timestamp,secondsFromStart,long,lat,cpm,segment\n"
        |> Download.string "segmented.csv" "text/csv"


distColumn : List SensorRecord -> List Int
distColumn =
    let
        distSq ( ( x1, y1 ), ( x2, y2 ) ) =
            (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)
    in
    List.map (\r -> ( r.long, r.lat ))
        >> neighbours
        >> List.map distSq
        >> scanl
            (\d segNum ->
                if d < 0.0001 then
                    segNum

                else
                    segNum + 1
            )
            0


secondsColumn : List SensorRecord -> List Int
secondsColumn =
    List.map (.timestamp >> tsToSeconds)


neighbours : List a -> List ( a, a )
neighbours items =
    case items of
        x :: xs ->
            --List.map2 Tuple.pair (x :: items) items
            List.map2 Tuple.pair items xs

        _ ->
            []


scanl : (a -> b -> b) -> b -> List a -> List b
scanl fn b =
    let
        scan a bs =
            case bs of
                hd :: tl ->
                    fn a hd :: bs

                _ ->
                    []
    in
    List.foldl scan [ b ] >> List.reverse


tsToSeconds : String -> Int
tsToSeconds ts =
    let
        day =
            ts |> String.right 11 |> String.left 2 |> strToInt

        hour =
            ts |> String.right 8 |> String.left 2 |> strToInt

        minute =
            ts |> String.right 5 |> String.left 2 |> strToInt

        second =
            ts |> String.right 2 |> strToInt
    in
    second + (minute * 60) + (hour * 3600) + ((day - 6) * 86400)


thin : List SensorRecord -> List SensorRecord
thin records =
    let
        toCoords : SensorRecord -> ( Float, Float )
        toCoords r =
            ( toFloat (tsToSeconds r.timestamp), toFloat r.cpm )

        filteredRecords : Int -> List SensorRecord -> List ( Int, SensorRecord )
        filteredRecords sid =
            List.filter (\r -> r.sensorId == sid)
                >> List.sortWith (by .sensorId ASC |> andThen .timestamp ASC)
                >> List.indexedMap Tuple.pair

        filteredDict : Int -> Dict Int SensorRecord
        filteredDict sid =
            filteredRecords sid records |> Dict.fromList

        simplified : List ( Int, SensorRecord ) -> Dict Int ( Float, Float )
        simplified =
            List.map (Tuple.mapSecond toCoords)
                >> Dict.fromList
                >> simplify (Pixels 10) High

        filterDict : List Int -> Dict Int SensorRecord -> Dict Int SensorRecord
        filterDict keys =
            Dict.filter (\k _ -> List.member k keys)

        thinned : Int -> List SensorRecord -> List SensorRecord
        thinned sid rs =
            rs
                ++ (filterDict (simplified (filteredRecords sid records) |> Dict.keys) (filteredDict sid)
                        |> Dict.values
                   )
    in
    List.foldl thinned [] (List.range 1 50)



-- VIEW


view : Model -> Html Msg
view model =
    case model.csv of
        Nothing ->
            button [ onClick CsvRequested ] [ text "Load CSV" ]

        Just content ->
            --p [ style "white-space" "pre" ] [ text content ]
            div []
                [ button [ onClick TrajectoryAndSaveRequested ] [ text "Create trajectories and save" ]
                , button [ onClick SimplifyAndSaveRequested ] [ text "Simplify and save" ]
                , button [ onClick SegmentAndSaveRequested ] [ text "Segment and save" ]
                ]



-- Sorting


by : (a -> comparable) -> Direction -> (a -> a -> Order)
by toCmp direction a b =
    case ( compare (toCmp a) (toCmp b), direction ) of
        ( LT, ASC ) ->
            LT

        ( LT, DESC ) ->
            GT

        ( GT, ASC ) ->
            GT

        ( GT, DESC ) ->
            LT

        ( EQ, _ ) ->
            EQ


andThen : (a -> comparable) -> Direction -> (a -> a -> Order) -> (a -> a -> Order)
andThen toCmp direction primary a b =
    case primary a b of
        EQ ->
            by toCmp direction a b

        ineq ->
            ineq


{-| Simplification pixel tolerance.
-}
type PixelTolerance
    = OnePixel
    | Pixels Float


{-| Simplification quality.
Two options:
\* Low = Radial Distance + Ramer-Douglas-Peucker
\* High = only Ramer-Douglas-Peucker
-}
type Quality
    = Low
    | High


{-| Simplify with Radial Distance and/or Ramer-Douglas-Peucker
-}
simplify : PixelTolerance -> Quality -> Dict Int ( Float, Float ) -> Dict Int ( Float, Float )
simplify tolerance quality points =
    if Dict.size points <= 2 then
        points

    else
        let
            sqTolerance =
                case tolerance of
                    OnePixel ->
                        1

                    Pixels p ->
                        p * p

            newPoints =
                case quality of
                    Low ->
                        simplifyRadialDistance points sqTolerance

                    High ->
                        points
        in
        simplifyDouglasPeucker newPoints sqTolerance


{-| Convenience function for the typical use case equal to:

    simplify OnePixel Low

-}
simplifyDefault : Dict Int ( Float, Float ) -> Dict Int ( Float, Float )
simplifyDefault points =
    simplify OnePixel Low points


{-| Basic distance-based simplification
-}
simplifyRadialDistance : Dict Int ( Float, Float ) -> Float -> Dict Int ( Float, Float )
simplifyRadialDistance points sqTolerance =
    let
        checkSqDist pointList sqt ( index, accum ) =
            case ( pointList, List.head accum ) of
                ( [], _ ) ->
                    ( index, accum )

                ( x :: [], _ ) ->
                    ( index + 1, ( index, x ) :: accum )

                ( x :: rest, Nothing ) ->
                    checkSqDist rest sqt ( index + 1, ( index, x ) :: accum )

                ( x :: rest, Just ( _, p ) ) ->
                    let
                        sqDist =
                            squareDistance x p
                    in
                    if sqDist > sqt then
                        checkSqDist rest sqt ( index + 1, ( index, x ) :: accum )

                    else
                        checkSqDist rest sqt ( index, accum )
    in
    checkSqDist (Dict.values points) sqTolerance ( 0, [] )
        |> (\( _, accum ) -> Dict.fromList accum)


{-| Square distance between 2 points.
-}
squareDistance : ( Float, Float ) -> ( Float, Float ) -> Float
squareDistance ( p1_x, p1_y ) ( p2_x, p2_y ) =
    let
        dx =
            p1_x - p2_x

        dy =
            p1_y - p2_y
    in
    (dx * dx) + (dy * dy)


{-| Simplification using Ramer-Douglas-Peucker algorithm
-}
simplifyDouglasPeucker : Dict Int ( Float, Float ) -> Float -> Dict Int ( Float, Float )
simplifyDouglasPeucker points sqTolerance =
    let
        firstIndex =
            0

        lastIndex =
            Dict.size points - 1

        firstPoint =
            Dict.get firstIndex points

        lastPoint =
            Dict.get lastIndex points
    in
    simplifyDPStep points firstIndex lastIndex sqTolerance ( [], [] )
        |> (\( _, accum ) ->
                case ( firstPoint, lastPoint ) of
                    ( Just fp, Just lp ) ->
                        ( firstIndex, fp ) :: ( lastIndex, lp ) :: accum |> Dict.fromList

                    _ ->
                        Debug.todo "Should not be here: something went wrong in the public interface"
           )


{-| -}
simplifyDPStep : Dict Int ( Float, Float ) -> Int -> Int -> Float -> ( List ( Int, Int ), List ( Int, ( Float, Float ) ) ) -> ( List ( Int, Int ), List ( Int, ( Float, Float ) ) )
simplifyDPStep points firstIndex lastIndex sqTolerance ( accumRanges, accumPoints ) =
    let
        ( maxSqDist, maxIndex, maxPoint ) =
            findMaxSquareSegmentDistance points firstIndex lastIndex sqTolerance
    in
    case maxSqDist > sqTolerance of
        False ->
            case accumRanges of
                [] ->
                    ( accumRanges, accumPoints )

                ( f, t ) :: rest ->
                    simplifyDPStep points f t sqTolerance ( rest, accumPoints )

        True ->
            let
                nextPoints =
                    ( maxIndex, maxPoint ) :: accumPoints

                nextRanges =
                    [ ( maxIndex - firstIndex > 1, ( firstIndex, maxIndex ) )
                    , ( lastIndex - maxIndex > 1, ( maxIndex, lastIndex ) )
                    ]
                        |> List.foldl
                            (\( cond, range ) accum ->
                                if cond then
                                    range :: accum

                                else
                                    accum
                            )
                            accumRanges
            in
            case nextRanges of
                [] ->
                    ( nextRanges, nextPoints )

                ( f, t ) :: rest ->
                    simplifyDPStep points f t sqTolerance ( rest, nextPoints )


{-| -}
findMaxSquareSegmentDistance : Dict Int ( Float, Float ) -> Int -> Int -> Float -> ( Float, Int, ( Float, Float ) )
findMaxSquareSegmentDistance points firstIndex lastIndex sqTolerance =
    let
        firstPoint =
            Dict.get firstIndex points

        lastPoint =
            Dict.get lastIndex points

        initialIndex =
            firstIndex + 1

        indexes =
            List.range initialIndex (lastIndex - 1)
    in
    Maybe.map2
        (\fp lp ->
            indexes
                |> List.foldl
                    (\i ( m, mi, mp ) ->
                        points
                            |> Dict.get i
                            |> Maybe.map
                                (\p ->
                                    let
                                        sqDist =
                                            squareSegmentDistance p fp lp
                                    in
                                    if sqDist > m then
                                        ( sqDist, i, p )

                                    else
                                        ( m, mi, mp )
                                )
                            |> Maybe.withDefault ( m, mi, mp )
                    )
                    ( sqTolerance, initialIndex, ( 0, 0 ) )
        )
        firstPoint
        lastPoint
        |> Maybe.withDefault ( sqTolerance, initialIndex, ( 0, 0 ) )


{-| Square distance from a point to a segment
-}
squareSegmentDistance : ( Float, Float ) -> ( Float, Float ) -> ( Float, Float ) -> Float
squareSegmentDistance ( p_x, p_y ) ( p1_x, p1_y ) ( p2_x, p2_y ) =
    let
        xy =
            ( p1_x, p1_y )

        dx =
            p2_x - p1_x

        dy =
            p2_y - p1_y

        newXY =
            if dx /= 0 || dy /= 0 then
                let
                    ( x, y ) =
                        xy
                in
                let
                    t =
                        (((p_x - x) * dx) + ((p_y - y) * dy)) / ((dx * dx) + (dy * dy))
                in
                if t > 1 then
                    ( p2_x
                    , p2_y
                    )

                else if t > 0 then
                    ( x + (dx * t)
                    , y + (dy * t)
                    )

                else
                    xy

            else
                xy
    in
    let
        ( x, y ) =
            newXY
    in
    ((p_x - x) * (p_x - x)) + ((p_y - y) * (p_y - y))

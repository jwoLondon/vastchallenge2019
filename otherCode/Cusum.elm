module Cusum exposing (addMobileCusum, addStaticCusum)

import Round
import Set


{-| Process the incoming string sent from JavaScript to generate a string that
will be passed back to JavaScript.
-}
addStaticCusum : String -> String
addStaticCusum lines =
    let
        readings =
            lines
                |> String.split "\n"
                |> List.drop 1
                |> List.map toStaticRecord

        earlyReadings =
            List.filter (\r -> r.dt < "2020-04-08 00:00:00") readings

        backgroundCpm =
            List.sum (List.map .cpm earlyReadings) / toFloat (List.length earlyReadings)

        ids =
            readings |> List.map .id |> Set.fromList |> Set.toList

        filterId id =
            List.filter (\r -> r.id == id) >> List.sortBy .dt

        toReadings id =
            (++) (staticCusum backgroundCpm (filterId id readings))
                >> List.sortBy .dt
    in
    List.foldl toReadings [] ids
        |> List.sortBy .dt
        |> List.map fromStaticRecord
        |> String.join "\n"
        |> (++) "timestamp,sensorId,cpm,cusum\n"


addMobileCusum : String -> String
addMobileCusum lines =
    let
        readings =
            lines
                |> String.split "\n"
                |> List.drop 1
                |> List.map toMobileRecord

        ids =
            List.range 1 50

        toReadings id =
            let
                readingsId =
                    readings |> List.filter (\r -> r.id == id) |> List.sortBy .dt

                earlyReadings =
                    readingsId
                        |> List.filter (\r -> r.dt < "2020-04-06 06:00:00")

                backgroundCpm =
                    List.sum (List.map .cpm earlyReadings) / toFloat (List.length earlyReadings)
            in
            (++)
                (mobileCusum
                    (if backgroundCpm == 0 then
                        25.86

                     else
                        backgroundCpm
                    )
                    readingsId
                )
    in
    List.foldl toReadings [] ids
        |> List.sortBy .dt
        |> List.map fromMobileRecord
        |> String.join "\n"
        |> (++) "sensorId,timestamp,secondsFromStart,long,lat,cpm,cusum\n"


type alias StaticReading =
    { dt : String
    , id : Int
    , cpm : Float
    , cusum : Float
    }


type alias MobileReading =
    { id : Int
    , dt : String
    , sfs : Int
    , lng : Float
    , lat : Float
    , cpm : Float
    , seg : Int
    , cusum : Float
    }


toStaticRecord : String -> StaticReading
toStaticRecord s =
    case String.split "," s of
        [ dt, id, cpm ] ->
            StaticReading dt
                (id |> String.trim |> String.toInt |> Maybe.withDefault 0)
                (cpm |> String.trim |> String.toFloat |> Maybe.withDefault 0)
                0

        _ ->
            StaticReading "" 0 0 0


toMobileRecord : String -> MobileReading
toMobileRecord s =
    case String.split "," s of
        [ id, dt, sfs, lng, lat, cpm, seg ] ->
            MobileReading (id |> String.trim |> String.toInt |> Maybe.withDefault 0)
                dt
                (sfs |> String.trim |> String.toInt |> Maybe.withDefault 0)
                (lng |> String.trim |> String.toFloat |> Maybe.withDefault 0)
                (lat |> String.trim |> String.toFloat |> Maybe.withDefault 0)
                (cpm |> String.trim |> String.toFloat |> Maybe.withDefault 0)
                (seg |> String.trim |> String.toInt |> Maybe.withDefault 0)
                0

        _ ->
            MobileReading 0 "" 0 0 0 0 0 0


fromStaticRecord : StaticReading -> String
fromStaticRecord r =
    r.dt ++ "," ++ String.fromInt r.id ++ "," ++ String.fromFloat r.cpm ++ "," ++ Round.round 2 r.cusum


fromMobileRecord : MobileReading -> String
fromMobileRecord r =
    String.fromInt r.id ++ "," ++ r.dt ++ "," ++ String.fromInt r.sfs ++ "," ++ String.fromFloat r.lng ++ "," ++ String.fromFloat r.lat ++ "," ++ String.fromFloat r.cpm ++ "," ++ Round.round 2 r.cusum


staticCusum : Float -> List StaticReading -> List StaticReading
staticCusum baseline =
    scanl (\r acc -> StaticReading r.dt r.id r.cpm (acc.cusum + (r.cpm - baseline)))
        (StaticReading "" 0 0 0)
        >> List.drop 1


mobileCusum : Float -> List MobileReading -> List MobileReading
mobileCusum baseline =
    scanl (\r acc -> MobileReading r.id r.dt r.sfs r.lng r.lat r.cpm r.seg (acc.cusum + (r.cpm - baseline)))
        (MobileReading 0 "" 0 0 0 0 0 0)
        >> List.drop 1


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

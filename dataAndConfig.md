---
id: litvis

narrative-schemas:
  - narrative-schemas/vastChallenge.yml

elm:
  dependencies:
    gicentre/elm-vegalite: latest
    gicentre/elm-vega: latest
    gicentre/tidy: latest
---

@import "css/vastChallenge.less"

```elm {l=hidden}
import Tidy exposing (..)
import Vega as V
import VegaLite exposing (..)
```

<!-- Everything above this line should probably be left untouched. -->

# 1. Data sources

## 1.1 Primary Data Sources

The core data sources provided for the three challenges

```elm {l}
mc1ReportData : Data
mc1ReportData =
    dataFromUrl "data/mc1ReportsTidy.csv" [ parse [ ( "location", foNum ), ( "intensity", foNum ) ] ]


mc2StaticSensorReadings : Data
mc2StaticSensorReadings =
    dataFromUrl "data/staticSensorReadings.csv" [ parse [ ( "sensorId", foNum ), ( "cpm", foNum ) ] ]


mc2MobileSensorReadings : Data
mc2MobileSensorReadings =
    -- Random sample for reduced file size download
    dataFromUrl "data/mobileSensorReadingsRandomSample.csv" [ parse [ ( "sensorId", foNum ), ( "cpm", foNum ) ] ]


mc3MessageData : Data
mc3MessageData =
    dataFromUrl "data/YInt.csv" []
```

## 1.2 Geographic Data Sources

Neighbourhood boundaries and centroids.

```elm {l}
neighbourhoodBounds : Data
neighbourhoodBounds =
    dataFromUrl "data/StHimark.json" [ topojsonFeature "StHimark" ]


neighbourhoodCentroids : Data
neighbourhoodCentroids =
    dataFromUrl "data/nhCentroids.csv" []
```

Points of interest (hosptals and power plant).

```elm {l}
pois : Data
pois =
    dataFromUrl "data/pois.csv" []
```

Road bridges (digitized separately).

```elm {l}
bridges : Data
bridges =
    dataFromUrl "data/bridges.json" [ topojsonFeature "bridges" ]
```

Gridded bridges and highway for entering/leaving St Himark.

```elm {l}
exitData : Data
exitData =
    dataFromUrl "data/exits.csv" []
```

Main quake shake contours (digitized separately).

```elm {l}
quakeContours : Data
quakeContours =
    dataFromUrl "data/quakeContours.json" [ topojsonFeature "quakeContours" ]
```

Location of the static sensors used in MC2.

```elm {l}
staticSensorLocations : Data
staticSensorLocations =
    dataFromUrl "data/staticSensorLocations.csv" []
```

## 1.3 Supporting Data

Date-times of nighttime periods for consistent symbolization of temporal sequences across all challenges.

```elm {l}
nightData : List DataColumn -> Data
nightData =
    dataFromColumns []
        << dataColumn "nightStart"
            (strs
                [ "2020-04-06 00:00:00"
                , "2020-04-06 18:00:00"
                , "2020-04-07 18:00:00"
                , "2020-04-08 18:00:00"
                , "2020-04-09 18:00:00"
                , "2020-04-10 18:00:00"
                ]
            )
        << dataColumn "nightEnd"
            (strs
                [ "2020-04-06 06:00:00"
                , "2020-04-07 06:00:00"
                , "2020-04-08 06:00:00"
                , "2020-04-09 06:00:00"
                , "2020-04-10 06:00:00"
                , "2020-04-10 23:59:59"
                ]
            )
```

## 1.4 Derived Data sources

### Data derived from the MC1 reports

The data provided for MC1 are not in [tidy](https://github.com/gicentre/tidy) format. The table can be restructured with some tidy gathering.

```elm {l}
reportTableSample : Table
reportTableSample =
    """timestamp,sewer_and_water,power,roads_and_bridges,medical,buildings,shake_intensity,location
        2020-04-08 17:50:00,10.0,6.0,10.0,3.0,8.0,,1
        2020-04-09 13:50:00,2.0,10.0,0.0,8.0,4.0,0.0,1
        2020-04-09 00:20:00,7.0,10.0,10.0,9.0,10.0,0.0,1
        2020-04-08 17:25:00,1.0,1.0,2.0,10.0,7.0,,1
        2020-04-08 02:50:00,9.0,7.0,1.0,6.0,9.0,,1
        2020-04-09 05:30:00,2.0,7.0,3.0,10.0,10.0,,1
        2020-04-08 04:30:00,2.0,10.0,1.0,2.0,8.0,,1
        2020-04-10 11:00:00,5.0,0.0,4.0,10.0,8.0,,1
        2020-04-10 19:40:00,10.0,7.0,7.0,1.0,3.0,0.0,1
        2020-04-07 22:00:00,6.0,6.0,5.0,7.0,2.0,,1
        2020-04-09 23:00:00,4.0,0.0,6.0,7.0,5.0,0.0,1
        2020-04-08 15:30:00,2.0,4.0,9.0,6.0,6.0,,1
        2020-04-08 20:10:00,2.0,2.0,2.0,7.0,4.0,,1
        2020-04-10 15:05:00,1.0,7.0,5.0,10.0,5.0,1.0,1"""
        |> fromCSV


tidyReport : Table -> Table
tidyReport =
    gather "rType"
        "intensity"
        [ ( "sewer_and_water", "sewerAndWater" )
        , ( "roads_and_bridges", "roadsBridges" )
        , ( "power", "power" )
        , ( "medical", "medical" )
        , ( "buildings", "buildings" )
        , ( "shake_intensity", "shake" )
        ]


reportTypeData : Data
reportTypeData =
    dataFromUrl "data/damageReportTypes.csv" []
```

### Data derived from MC2 mobile sensors

The MC2 mobile dataset is very large with many consecutive sensor readings with similar values. We can apply [Douglas-Peucker simplification](../otherCode/simplify/src/SimplifySignal.elm) to thin the singal without losing signficant changes in radiation values. The amount of thinning is controlled by a parameter which varies below between 5 (least thinning) to 20 (most thinning).

```elm {l}
mobileSensorReadingsThinned5 : Data
mobileSensorReadingsThinned5 =
    dataFromUrl "data/mobileSensorReadingsThinned5.csv"
        [ parse
            [ ( "secondsFromStart", foNum )
            , ( "cpm", foNum )
            , ( "sensorId", foNum )
            ]
        ]


mobileSensorReadingsThinned10 : Data
mobileSensorReadingsThinned10 =
    dataFromUrl "data/mobileSensorReadingsThinned10.csv"
        [ parse
            [ ( "secondsFromStart", foNum )
            , ( "cpm", foNum )
            , ( "sensorId", foNum )
            ]
        ]


mobileSensorReadingsThinned20 : Data
mobileSensorReadingsThinned20 =
    dataFromUrl "data/mobileSensorReadingsThinned20.csv"
        [ parse
            [ ( "secondsFromStart", foNum )
            , ( "cpm", foNum )
            , ( "sensorId", foNum )
            ]
        ]
```

Registered names of all 50 mobile sensors.

```elm {l}
sensorNameData : Data
sensorNameData =
    dataFromUrl "data/sensorNames.csv" [ parse [ ( "sensorId", foNum ) ] ]
```

A random sample from the full dataset useful for some quicker exploratory analysis.

```elm{l}
mobileSensorReadingsRandomSample : Data
mobileSensorReadingsRandomSample =
    dataFromUrl "data/mobileSensorReadingsRandomSample.csv" [ parse [ ( "value", foNum ) ] ]
```

For showing the trajectories of mobile sensors, consecutive readings at the same location are [filtered out](../otherCode/simplify/src/SimplifySignal.elm).

```elm {l}
mobileSensorTrajectories : Data
mobileSensorTrajectories =
    dataFromUrl "data/mobileTrajectories.csv" [ parse [ ( "sensorId", foNum ) ] ]
```

### Data derived from MC3 messages

```elm {l}
wordFreqData : Data
wordFreqData =
    dataFromUrl "data/wordFreqs.csv" [ parse [ ( "freq", foNum ) ] ]
```

Extracting the numbers of fatailities claimed in the various messages can be achieved with the command line:

```bash
grep -r "fatal" YInt.csv | cut -d ',' -f 4-99 | grep -Eo '[0-9]+' >fatalNumbers.csv
```

_(search for lines that contain `fatal` within them; cut out the comma-separated column(s) containing the message txt; extract the digits from the filtered messages)_

```elm {l}
fatalityData : Data
fatalityData =
    dataFromUrl "data/fatalNumbers.csv" [ parse [ ( "fatalNum", foNum ) ] ]
```

# 2. Colour Schemes

To ensure consistency of colour encoding across plots, we define them here.

## 2.1 MC1 damage report types

```elm {l}
damageColours : List ScaleProperty
damageColours =
    categoricalDomainMap
        [ ( "buildings", "rgb(120,147,182)" )
        , ( "medical", "rgb(235,161,96)" )
        , ( "power", "rgb(220,128,124)" )
        , ( "roadsBridges", "rgb(155,196,193)" )
        , ( "sewerAndWater", "rgb(134,179,119)" )
        , ( "shake", "rgb(237,213,121)" )
        ]
```

## 2.2 Static MC2 sensors

```elm {l}
staticColours : List ScaleProperty
staticColours =
    categoricalDomainMap
        [ ( "1", "rgb(59,118,175)" )
        , ( "4", "rgb(239,133,54)" )
        , ( "6", "rgb(81,157,62)" )
        , ( "9", "rgb(141,106,184)" )
        , ( "11", "rgb(197,57,50)" )
        , ( "12", "rgb(132,88,78)" )
        , ( "13", "rgb(213,126,190)" )
        , ( "14", "rgb(188,188,69)" )
        , ( "15", "rgb(88,187,204)" )
        ]
```

## 2.3 Mobile MC2 sensors

```elm {l}
mobileColours : List ScaleProperty
mobileColours =
    categoricalDomainMap
        [ ( "1", "rgb(100,186,170)" )
        , ( "2", "rgb(36,90,98)" )
        , ( "3", "rgb(65,165,238)" )
        , ( "4", "rgb(85,94,208)" )
        , ( "5", "rgb(198,103,243)" )
        , ( "6", "rgb(118,7,150)" )
        , ( "7", "rgb(233,120,177)" )
        , ( "8", "rgb(104,55,79)" )
        , ( "9", "rgb(244,38,151)" )
        , ( "10", "rgb(140,2,80)" )
        , ( "11", "rgb(77,194,84)" )
        , ( "12", "rgb(5,110,18)" )
        , ( "13", "rgb(141,168,62)" )
        , ( "14", "rgb(104,60,0)" )
        , ( "15", "rgb(247,147,2)" )
        , ( "16", "rgb(209,31,11)" )
        , ( "17", "rgb(218,157,136)" )
        , ( "18", "rgb(63,76,8)" )
        , ( "19", "rgb(227,19,238)" )
        , ( "20", "rgb(39,15,226)" )
        , ( "21", "rgb(100,186,170)" )
        , ( "22", "rgb(36,90,98)" )
        , ( "23", "rgb(65,165,238)" )
        , ( "24", "rgb(85,94,208)" )
        , ( "25", "rgb(198,103,243)" )
        , ( "26", "rgb(118,7,150)" )
        , ( "27", "rgb(233,120,177)" )
        , ( "28", "rgb(104,55,79)" )
        , ( "29", "rgb(244,38,151)" )
        , ( "30", "rgb(140,2,80)" )
        , ( "31", "rgb(77,194,84)" )
        , ( "32", "rgb(5,110,18)" )
        , ( "33", "rgb(141,168,62)" )
        , ( "34", "rgb(104,60,0)" )
        , ( "35", "rgb(247,147,2)" )
        , ( "36", "rgb(209,31,11)" )
        , ( "37", "rgb(218,157,136)" )
        , ( "38", "rgb(63,76,8)" )
        , ( "39", "rgb(227,19,238)" )
        , ( "40", "rgb(39,15,226)" )
        , ( "41", "rgb(100,186,170)" )
        , ( "42", "rgb(36,90,98)" )
        , ( "43", "rgb(65,165,238)" )
        , ( "44", "rgb(85,94,208)" )
        , ( "45", "rgb(198,103,243)" )
        , ( "46", "rgb(118,7,150)" )
        , ( "47", "rgb(233,120,177)" )
        , ( "48", "rgb(104,55,79)" )
        , ( "49", "rgb(244,38,151)" )
        , ( "50", "rgb(140,2,80)" )
        ]
```

## 2.4 St Himark neighbourhoods

```elm {l}
neighbourhoodColours : List ScaleProperty
neighbourhoodColours =
    categoricalDomainMap
        [ ( "Northwest", "rgb(100,186,170)" )
        , ( "Old Town", "rgb(36,90,98)" )
        , ( "Palace Hills", "rgb(65,165,238)" )
        , ( "Downtown", "rgb(85,94,208)" )
        , ( "Weston", "rgb(198,103,243)" )
        , ( "Easton", "rgb(118,7,150)" )
        , ( "Safe Town", "rgb(209,31,11)" )
        , ( "Southwest", "rgb(104,55,79)" )
        , ( "Southton", "rgb(244,38,151)" )
        , ( "West Parton", "rgb(140,2,80)" )
        , ( "East Parton", "rgb(77,194,84)" )
        , ( "Oak Willow", "rgb(5,110,18)" )
        , ( "Cheddarford", "rgb(141,168,62)" )
        , ( "Pepper Mill", "rgb(104,60,0)" )
        , ( "Wilson Forest", "rgb(247,147,2)" )
        , ( "Broadview", "rgb(233,120,177)" )
        , ( "Chapparal", "rgb(218,157,136)" )
        , ( "Terrapin Springs", "rgb(63,76,8)" )
        , ( "Scenic Vista", "rgb(227,19,238)" )
        , ( "withheld", "#000" )
        , ( "unknown", "#000" )
        ]
```

## 2.5 Bridge/road status

```elm {l}
statusColours : List ScaleProperty
statusColours =
    categoricalDomainMap
        [ ( "open", "rgb(86,120,164)" )
        , ( "closed", "rgb(212,96,91)" )
        , ( "uncertain", "rgb(80,80,80)" )
        ]
```

# 3. Configuration

Style configurations for consistency across charts.

```elm {l}
cfg =
    configure
        << configuration (coView [ vicoStroke Nothing ])
        << configuration (coHeader [ hdLabelAngle 0 ])
        << configuration (coFacet [ facoSpacing 0 ])
        << configuration (coTitle [ ticoAnchor anStart ])
        << configuration (coAxis [ axcoGridWidth 0.3 ])


cfgGridSpaced =
    configure
        << configuration (coHeader [ hdLabelAngle 0 ])
        << configuration (coFacet [ facoSpacing 0 ])
        << configuration (coTitle [ ticoAnchor anStart ])
        << configuration (coAxis [ axcoGridWidth 0.3 ])


cfgTimeline =
    configure
        << configuration (coView [ vicoStroke Nothing ])
        << configuration (coAxisX [ axcoDomain False, axcoTicks False ])


cfgLogTimeline =
    configure
        << configuration (coView [ vicoStroke Nothing ])
        << configuration (coHeader [ hdLabelAngle 0, hdTitleFontSize 0, hdLabelOrient siLeft ])
        << configuration (coFacet [ facoSpacing 0 ])
        << configuration (coAxisY [ axcoGrid True, axcoGridWidth 0.3, axcoDomain False, axcoLabels False, axcoTicks False ])
        << configuration (coAxisX [ axcoDomain False, axcoTicks False ])


cfgFacetTimeline =
    configure
        << configuration (coView [ vicoStroke Nothing ])
        << configuration
            (coHeader
                [ hdLabelAngle 0
                , hdTitleFontSize 0
                , hdLabelOrient siLeft
                , hdLabelAlign haLeft
                , hdLabelPadding -6
                ]
            )
        << configuration (coFacet [ facoSpacing 4 ])
        << configuration (coAxisY [ axcoGrid True, axcoGridWidth 0.3, axcoLabelFontSize 8 ])
        << configuration (coAxisX [ axcoDomain False, axcoTicks False ])


cfgMsgTimeline =
    configure
        << configuration (coBar [ maContinuousBandSize 20, maBinSpacing 10 ])
        << configuration (coView [ vicoStroke Nothing ])
        << configuration (coAxisX [ axcoDomain False, axcoTicks False, axcoLabelPadding -8, axcoLabelAlign haLeft ])
```

# 4. Reusable specifications

## 4.1 Temporal domain

Full temporal domain spanning first and last temporal reading across the challenges.

```elm {l}
dateDomain : ScaleProperty
dateDomain =
    scDomain
        (doDts
            [ [ dtYear 2020, dtMonth Apr, dtDate 6, dtHour 0 ]
            , [ dtYear 2020, dtMonth Apr, dtDate 10, dtHour 23, dtMinute 59, dtSecond 59 ]
            ]
        )
```

Temporal domain spanning on the two main shake events

```elm {l}
shakeDomain : ScaleProperty
shakeDomain =
    scDomain
        (doDts
            [ [ dtYear 2020, dtMonth Apr, dtDate 8, dtHour 8, dtMinute 30 ]
            , [ dtYear 2020, dtMonth Apr, dtDate 9, dtHour 20 ]
            ]
        )
```

## 4.2 Temporal encoding

Consistent spatial encoding of time values for timelines across challenges.

```elm {l}
timeEncoding : List PositionChannel
timeEncoding =
    [ pName "timestamp"
    , pMType Temporal
    , pAxis [ axTitle "", axFormat "%H:%M", axOrient siBottom, axGrid True ]
    , pScale [ dateDomain ]
    ]


timeEncodingAggHours : List PositionChannel
timeEncodingAggHours =
    [ pName "timestamp"
    , pMType Temporal
    , pTimeUnit yearMonthDateHours
    , pAxis [ axTitle "", axFormat "%H:%M", axOrient siBottom, axGrid True ]
    , pScale [ dateDomain ]
    ]


timeEncodingAggMinutes : List PositionChannel
timeEncodingAggMinutes =
    [ pName "timestamp"
    , pMType Temporal
    , pTimeUnit yearMonthDateHoursMinutes
    , pAxis [ axTitle "", axFormat "%H:%M", axOrient siBottom, axGrid True ]
    , pScale [ dateDomain ]
    ]


timeEncodingShakeMinutes : List PositionChannel
timeEncodingShakeMinutes =
    [ pName "timestamp"
    , pMType Temporal
    , pTimeUnit yearMonthDateHoursMinutes
    , pAxis [ axTitle "", axFormat "%H:%M", axOrient siBottom, axGrid True ]
    , pScale [ shakeDomain ]
    ]


timeResolve : List LabelledSpec -> ( VLProperty, Spec )
timeResolve =
    resolve << resolution (reAxis [ ( chX, reIndependent ) ])
```

## 4.3 Nighttime specification

For quick orientation of nighttime periods a layer that can be added to timelines.

```elm {l}
specNights : Spec
specNights =
    let
        enc =
            encoding
                << position X
                    [ pName "nightStart"
                    , pMType Temporal
                    , pAxis
                        [ axTitle ""
                        , axFormat " %a"
                        , axTickCount 5
                        , axOffset 18
                        , axOrient siBottom
                        , axDomain False
                        , axTicks False
                        ]
                    , pScale [ dateDomain ]
                    ]
                << position X2 [ pName "nightEnd" ]
    in
    asSpec
        [ nightData []
        , enc []
        , rect [ maTooltip ttNone, maOpacity 0.1, maFill "#669" ]
        ]
```

## 4.4 Reference line

For timelines with a value on a log or linear scale, can be useful to highlight a reference value (e.g. 0 on a sym-log scale, or some assumed background radiation level)

```elm {l}
specReference : Float -> Spec
specReference refValue =
    let
        refData =
            dataFromColumns []
                << dataColumn "timestamp" (strs [ "2020-04-06 00:00:00", "2020-04-10 23:59:59" ])
                << dataColumn "val" (nums [ refValue, refValue ])

        enc =
            encoding
                << position X timeEncoding
                << position Y [ pName "val", pMType Quantitative, pAxis [] ]
    in
    asSpec [ refData [], enc [], line [ maStrokeWidth 1, maColor "black" ] ]
```

## 4.5 Interactive Legends

### Damage Report Types

For interactive filtering of damage report types (MC1).

```elm {l}
reportInteractiveLegend : String -> Spec
reportInteractiveLegend selName =
    let
        enc =
            encoding
                << position Y [ pName "rType", pMType Ordinal, pAxis [] ]

        encColour =
            enc
                << color
                    [ mSelectionCondition (selectionName selName)
                        [ mName "rType", mMType Nominal, mScale damageColours, mLegend [] ]
                        [ mStr "lightgrey" ]
                    ]

        encRType =
            enc << text [ tName "rType", tMType Nominal ]

        sel =
            selection
                << select selName seMulti [ seEncodings [ chColor ] ]

        specColour =
            asSpec
                [ encColour []
                , sel []
                , square [ maTooltip ttNone, maSize 120, maDx 0, maOpacity 1 ]
                ]

        specRType =
            asSpec
                [ encRType []
                , textMark [ maTooltip ttNone, maFontSize 9, maDx 10, maAlign haLeft ]
                ]
    in
    asSpec
        [ width 40
        , reportTypeData
        , enc []
        , layer [ specColour, specRType ]
        ]
```

### Mobile Sensors

For interactive selection of mobile sensors. Can be juxtaposed next to any chart that uses MC2 mobile sensor data allowing filtering by sensor id.

```elm {l}
sensorInteractiveLegend : String -> Spec
sensorInteractiveLegend selName =
    let
        trans =
            transform
                << calculateAs "round((datum.sensorId-1) % 25)" "row"
                << calculateAs "round((datum.sensorId-1) / 50)" "col"

        enc =
            encoding
                << position X [ pName "col", pMType Ordinal, pAxis [] ]
                << position Y [ pName "row", pMType Ordinal, pAxis [] ]

        encColour =
            enc
                << color
                    [ mSelectionCondition (selectionName selName)
                        [ mName "sensorId", mMType Nominal, mScale mobileColours, mLegend [] ]
                        [ mStr "lightgrey" ]
                    ]

        encUserId =
            enc << text [ tName "userId", tMType Nominal ]

        encSensorId =
            enc << text [ tName "sensorId", tMType Nominal ]

        sel =
            selection
                << select selName seMulti [ seEncodings [ chColor ] ]

        specColour =
            asSpec
                [ encColour []
                , sel []
                , square [ maTooltip ttNone, maSize 120, maOpacity 1 ]
                ]

        specUserId =
            asSpec
                [ encUserId []
                , textMark [ maTooltip ttNone, maFontSize 9, maXOffset -22, maAlign haRight ]
                ]

        specSensorId =
            asSpec
                [ encSensorId []
                , textMark [ maTooltip ttNone, maFontSize 9, maXOffset -9, maAlign haRight ]
                ]
    in
    asSpec
        [ width 300
        , sensorNameData
        , trans []
        , enc []
        , layer [ specColour, specUserId, specSensorId ]
        ]
```

## 4.6 Context Maps

Specification for showing full context map with neighbourhoods, PoIs, bridges and shake map.

```elm {l v}
contextMap : Spec
contextMap =
    let
        trans =
            transform << spatialFilter

        specNeighbourhood =
            asSpec
                [ neighbourhoodBounds
                , geoshape [ maStroke "white", maFill "#eee", maStrokeWidth 2 ]
                ]

        specBridges =
            asSpec
                [ bridges
                , geoshape [ maStroke "#eee", maStrokeWidth 4 ]
                ]

        specContours =
            asSpec
                [ quakeContours
                , geoshape [ maStroke "#ecc", maStrokeWidth 2, maOpacity 0.7 ]
                ]

        encLabels =
            encoding
                << position Longitude [ pName "cx", pMType Quantitative ]
                << position Latitude [ pName "cy", pMType Quantitative ]
                << text [ tName "nbrhood", tMType Nominal ]

        specLabels =
            asSpec
                [ neighbourhoodCentroids
                , trans []
                , encLabels []
                , textMark [ maColor "#666", maFontSize 8 ]
                ]

        encIdLabels =
            encoding
                << position Longitude [ pName "cx", pMType Quantitative ]
                << position Latitude [ pName "cy", pMType Quantitative ]
                << text [ tName "id", tMType Ordinal ]

        specIdLabels =
            asSpec
                [ neighbourhoodCentroids
                , trans []
                , encIdLabels []
                , textMark [ maColor "#555", maDy 10, maFontSize 8 ]
                ]

        encPois =
            encoding
                << position Longitude [ pName "long", pMType Quantitative ]
                << position Latitude [ pName "lat", pMType Quantitative ]
                << text [ tName "label", tMType Nominal ]

        specPois =
            asSpec [ pois, encPois [], textMark [] ]
    in
    toVegaLite
        [ width 850
        , height 700
        , cfg []
        , layer
            [ specNeighbourhood
            , specBridges
            , specContours
            , specLabels
            , specIdLabels
            , specPois
            ]
        ]
```

```elm {l v}
mc2StaticSensorMap : Spec
mc2StaticSensorMap =
    let
        specBackground =
            asSpec [ neighbourhoodBounds, geoshape [ maStroke "white", maFill "#eee", maStrokeWidth 2 ] ]

        specBridges =
            asSpec
                [ bridges
                , geoshape [ maStroke "#eee", maStrokeWidth 4 ]
                ]

        encPois =
            encoding
                << position Longitude [ pName "long", pMType Quantitative ]
                << position Latitude [ pName "lat", pMType Quantitative ]
                << text [ tName "label", tMType Nominal ]

        encSensorId =
            encoding
                << position Longitude [ pName "long", pMType Quantitative ]
                << position Latitude [ pName "lat", pMType Quantitative ]
                << text [ tName "id", tMType Ordinal ]

        specSensors =
            asSpec [ staticSensorLocations, encPois [], textMark [ maColor "red", maFontSize 16 ] ]

        specPois =
            asSpec [ pois, encPois [], textMark [] ]

        specSensorId =
            asSpec [ staticSensorLocations, encSensorId [], textMark [ maDx 12, maColor "red" ] ]
    in
    toVegaLite
        [ width 740
        , height 600
        , cfg []
        , layer
            [ specBackground
            , specBridges
            , specPois
            , specSensors
            , specSensorId
            ]
        ]
```

## 4.7 Grid mapping layout

```elm {v l}
gridLayout : Spec
gridLayout =
    let
        gridEnc =
            encoding
                << position X
                    [ pName "col"
                    , pMType Ordinal
                    , pScale [ List.range -1 7 |> List.map toFloat |> doNums |> scDomain ]
                    , pAxis []
                    ]
                << position Y
                    [ pName "row"
                    , pMType Ordinal
                    , pScale [ List.range 0 4 |> List.map toFloat |> doNums |> scDomain ]
                    , pAxis []
                    ]

        squares =
            asSpec [ gridEnc [], rect [ maFill "#eee", maStroke "white" ] ]

        idEnc =
            gridEnc << text [ tName "id", tMType Ordinal ]

        nCodeEnc =
            gridEnc << text [ tName "nCode", tMType Ordinal ]

        nameEnc =
            gridEnc << text [ tName "nbrhood", tMType Ordinal ]

        idLabels =
            asSpec [ idEnc [], textMark [ maDy -15, maColor "white" ] ]

        nCodeLabels =
            asSpec [ nCodeEnc [], textMark [ maFontWeight Bold ] ]

        nameLabels =
            asSpec [ nameEnc [], textMark [ maDy 15, maFontStyle "italic" ] ]

        bridgeEnc =
            encoding
                << position X
                    [ pName "sCol"
                    , pMType Ordinal
                    , pScale [ List.range -1 7 |> List.map toFloat |> doNums |> scDomain ]
                    , pAxis []
                    ]
                << position Y
                    [ pName "sRow"
                    , pMType Ordinal
                    , pScale [ List.range 0 4 |> List.map toFloat |> doNums |> scDomain ]
                    , pAxis []
                    ]
                << position X2
                    [ pName "eCol"
                    , pScale [ List.range -1 7 |> List.map toFloat |> doNums |> scDomain ]
                    , pAxis []
                    ]
                << position Y2
                    [ pName "eRow"
                    , pScale [ List.range 0 4 |> List.map toFloat |> doNums |> scDomain ]
                    , pAxis []
                    ]
                << text [ tName "name", tMType Nominal ]

        bridgeSpec =
            asSpec [ exitData, bridgeEnc [], rule [ maStrokeWidth 8, maColor "#eee" ] ]

        bridgeLabels =
            asSpec [ exitData, bridgeEnc [], textMark [ maFontSize 8 ] ]
    in
    toVegaLite
        [ cfg []
        , width 900
        , height 500
        , neighbourhoodCentroids
        , layer [ bridgeSpec, squares, idLabels, nCodeLabels, nameLabels, bridgeLabels ]
        ]
```

# 5. Filters

## 5.1 Removal of non-spatial locations

In MC3, some messages have a location of 'unknown' or 'location withheld'. These have been given ids of 99 and 999 respectively, so can be removed for cases where we do not need to map them.

```elm {l}
spatialFilter : List LabelledSpec -> List LabelledSpec
spatialFilter =
    filter (fiExpr "datum.id != 99 && datum.id != 999")
```

## 5.2 Removal of spam messages

Regex for identifying phrases associated with spam messages can be used to remove them from analysis.

```elm {l}
noSpamFilter : List LabelledSpec -> List LabelledSpec
noSpamFilter =
    filter (fiExpr "test(/^((?!deal[!s]|sale|anything.*anyone).)*$/,datum.message)")
```

port module Cli exposing (main, processed)

--import MessageFilter

import Cusum
import Platform exposing (worker)


port processed : String -> Cmd msg



{- Simple template for command line communication from javascript.
   An incoming string is passed from javscript to Elm via a flag.
   This can be processed in myProcessingFunction after which the
   results are sent back to javascript via a port (processed).
   In javascript, subscribe to the port to retrieve the results.
-}


main : Program String String Never
main =
    Platform.worker
        { --init = \flag -> ( "", processed (MessageFilter.messageFilter flag) )
          --  init = \flag -> ( "", processed (Cusum.addCusum flag) )
          --init = \flag -> ( "", processed (Cusum.addStaticCusum flag) )
          init = \flag -> ( "", processed (Cusum.addMobileCusum flag) )
        , update = \msg model -> ( model, Cmd.none )
        , subscriptions = \model -> Sub.none
        }

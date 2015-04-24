{-# LANGUAGE OverloadedStrings #-}

module Main where

import HEyefi.Constant
import HEyefi.StartSession (startSessionResponse)

import Data.ByteString.Lazy (fromStrict)
import Data.ByteString.UTF8 (toString, fromString)
import Data.List (find)
import Data.Maybe (isJust, fromJust)
import Data.Time.Clock
import Data.Time.Format (formatTime)
import Data.Time.ISO8601
import System.Locale (rfc822DateFormat, defaultTimeLocale)
import Network.Wai ( responseLBS
                   , Application
                   , Request
                   , pathInfo
                   , requestBody
                   , requestMethod
                   , requestHeaders )
import Network.Wai.Handler.Warp (run)
import Network.HTTP.Types (status200)
import Network.HTTP.Types.Header (hContentType,
                                  hServer,
                                  hContentLength,
                                  hDate,
                                  Header)
--import Network.HTTP.Types.Method (Method (..))
import Text.XML.HXT.Core ( runX
                         , readString
                         , getText
                         , (/>))
import Text.HandsomeSoup (css)
import Control.Arrow ((>>>))
import qualified Data.CaseInsensitive as CI


logInfo :: String -> IO ()
logInfo s = do
  t <- getCurrentTime
  putStrLn (unwords ["[" ++ formatISO8601Millis t ++ "]", "[INFO]", s])

main :: IO ()
main = do
    logInfo ("Listening on port " ++ show port)
    run port app

data SoapAction = StartSession
                | GetPhotoStatus
                deriving (Show, Eq)

headerIsSoapAction :: Header -> Bool
headerIsSoapAction ("SOAPAction",_) = True
headerIsSoapAction _ = False

soapAction :: Request -> Maybe SoapAction
soapAction req =
  case find headerIsSoapAction (requestHeaders req) of
   Just (_,"\"urn:StartSession\"") -> Just StartSession
   Just (_,"\"urn:GetPhotoStatus\"") -> Just GetPhotoStatus
   Just (_,sa) -> error ((show sa) ++ " is not a defined SoapAction yet")
   _ -> Nothing


handleSoapAction :: SoapAction -> String -> Application
handleSoapAction StartSession body _ f = do
      logInfo "Got StartSession request"
      -- ["fileid","filename","filesize","filesignature"]
      let xmlDocument = readString [] body
      let getTagText = \ s -> runX (xmlDocument >>> css s /> getText)
      macaddress <- getTagText "macaddress"
      cnonce <- getTagText "cnonce"
      transfermode <- getTagText "transfermode"
      transfermodetimestamp <- getTagText "transfermodetimestamp"
      logInfo (show macaddress)
      logInfo (show transfermodetimestamp)
      responseBody <- (startSessionResponse
                       (head macaddress)
                       (head cnonce)
                       (head transfermode)
                       (head transfermodetimestamp))
      logInfo (show responseBody)
      t <- getCurrentTime
      f (responseLBS
         status200
         [ (hContentType, "text/xml; charset=\"utf-8\"")
         , (hDate, fromString (formatTime defaultTimeLocale rfc822DateFormat t))
         , (CI.mk "Pragma", "no-cache")
         , (hServer, "Eye-Fi Agent/2.0.4.0 (Windows XP SP2)")
         , (hContentLength, fromString (show (length responseBody)))] (fromStrict (fromString responseBody)))
handleSoapAction sa _ _ _ =
  error ("SoapAction " ++ show sa ++ " does not have a handler.")

dispatchRequest :: String -> Application
dispatchRequest body req f
  | requestMethod req == "POST" &&
    isJust (soapAction req) =
      handleSoapAction (fromJust (soapAction req)) body req f

dispatchRequest  _ _ _ = error "did not match dispatch"

app :: Application
app req f = do
  body <- requestBody req
  logInfo (show (pathInfo req))
  logInfo (show (requestHeaders req))
  logInfo (show (toString body))
  dispatchRequest (toString body) req f

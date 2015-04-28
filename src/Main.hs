{-# LANGUAGE OverloadedStrings #-}

module Main where

import HEyefi.Constant
import HEyefi.StartSession (startSessionResponse)
import HEyefi.GetPhotoStatus (getPhotoStatusResponse)

import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import Data.ByteString.Lazy (fromStrict)
import Data.ByteString.Lazy.UTF8 (toString)
import Data.ByteString.UTF8 (fromString)
import Data.List (find)
import Data.Maybe (isJust, fromJust, isNothing)
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
import Network.Multipart ( parseMultipartBody, MultiPart (..), BodyPart (..) )
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


handleSoapAction :: SoapAction -> BL.ByteString -> Application
handleSoapAction StartSession body _ f = do
  logInfo "Got StartSession request"
  let xmlDocument = readString [] (toString body)
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
handleSoapAction GetPhotoStatus _ _ f = do
  logInfo "Got GetPhotoStatus request"
  responseBody <- getPhotoStatusResponse
  t <- getCurrentTime
  f (responseLBS
     status200
     [ (hContentType, "text/xml; charset=\"utf-8\"")
     , (hDate, fromString (formatTime defaultTimeLocale rfc822DateFormat t))
     , (CI.mk "Pragma", "no-cache")
     , (hServer, "Eye-Fi Agent/2.0.4.0 (Windows XP SP2)")
     , (hContentLength, fromString (show (length responseBody)))] (fromStrict (fromString responseBody)))



handleUpload :: BL.ByteString -> Application
handleUpload body _ _ = do
  let MultiPart bodyParts = parseMultipartBody multipartBodyBoundary body
  logInfo (show (length bodyParts))
  lBP bodyParts
  let (BodyPart _ soapEnvelope) = bodyParts !! 0
  let (BodyPart _ file) = bodyParts !! 1
  let (BodyPart _ digest) = bodyParts !! 2
  BL.writeFile "/home/ryantm/p/heyefi/tmp.tar" file
  logInfo (show soapEnvelope)
  logInfo (show digest)
  undefined
  where
    lBP [] = return ()
    lBP ((BodyPart headers _):xs) = do
      logInfo (show headers)
      lBP xs
      return ()


dispatchRequest :: BL.ByteString -> Application
dispatchRequest body req f
  | requestMethod req == "POST" &&
    pathInfo req == ["api","soap","eyefilm","v1","upload"] &&
    isNothing (soapAction req) =
      handleUpload body req f
dispatchRequest body req f
  | requestMethod req == "POST" &&
    isJust (soapAction req) =
      handleSoapAction (fromJust (soapAction req)) body req f
dispatchRequest  _ _ _ = error "did not match dispatch"

getWholeRequestBody :: Request -> IO B.ByteString
getWholeRequestBody request = do
  r <- requestBody request
  if r == B.empty
    then return B.empty
    else do
     rest <- getWholeRequestBody request
     return (B.append r rest)

app :: Application
app req f = do
  body <- getWholeRequestBody req
  logInfo (show (pathInfo req))
  logInfo (show (requestHeaders req))
  -- logInfo (show (toString body))
  dispatchRequest (fromStrict body) req f

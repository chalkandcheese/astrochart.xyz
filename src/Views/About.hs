{-# LANGUAGE NoImplicitPrelude, OverloadedStrings, QuasiQuotes #-}

module Views.About (render) where

import Import
import Views.Common
import Lucid
import CMark
import Data.String.Interpolate.IsString

render :: HasStaticRoot ctx => ctx -> Html ()
render renderCtx = do
    head_ $ do
        title_ "About astrochart.xyz"
        metaCeremony renderCtx

    body_ $ do
        div_ [id_ "main", class_ "container grid-sm"] $ do
            header_ [class_ "navbar bg-dark"] $ do
                section_ [class_ "navbar-section navbar-brand"] $ do
                    a_ [href_ "/", class_ "brand-text"] "astrochart.xyz"
            toHtmlRaw $
                commonmarkToHtml [] pablum

            footerNav


pablum :: Text
pablum = [i|
# About

This website exists thanks to genius and insanity of [Luis Borjas Reyes](https://github.com/lfborjas) and a very minor effort of a [yet another Capricorn](https://github.com/chalkandcheese).

Say hi: hello@astrochart.xyz
|]
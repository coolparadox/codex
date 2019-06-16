module Main where

import System.IO 
import System.Posix.IO
import System.Posix.Types

import Codexplain

main :: IO()
main = do
    input <- getContents
    h_explain <- fdToHandle (Fd 1)
    h_extrude <- fdToHandle (Fd 3)
    let (explanation, extrusion) = explain input in do
        hPutStr h_explain explanation
        hPutStr h_extrude extrusion
    hClose h_explain
    hClose h_extrude


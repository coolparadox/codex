module Codexplain (explain) where

import qualified Data.Map as Map

explain :: String -> (String, String)
explain input = (explanation, extrusion) where
    explanation = explainDocument document
    extrusion = extrudeDocument document
    document = parse input

data Document = MakeDocument Statistics [Block] deriving Show

data Statistics = MakeStatistics (Map.Map String Int) deriving Show

data Block =
    RawBlock [String] |
    CommentBlock [String] |
    CodeFileBlock String Int [String] deriving Show

parse :: String -> Document
parse str = MakeDocument statistics promoted_blocks where
    (promoted_blocks, statistics) = promoteCommentBlocks blocks (MakeStatistics Map.empty)
    blocks = parseLowLevel $ lines str

promoteCommentBlocks :: [Block] -> Statistics -> ([Block], Statistics)
promoteCommentBlocks [] stat = ([], stat)
promoteCommentBlocks (block:blocks) stat = (promoted_block:promoted_blocks, updated_stat) where
    (promoted_block, promoted_stat) = promoteCommentBlock block stat
    (promoted_blocks, updated_stat) = promoteCommentBlocks blocks promoted_stat

promoteCommentBlock :: Block -> Statistics -> (Block, Statistics)
promoteCommentBlock block@(CommentBlock (x:xs)) stat
    | take 4 x == "////" = (block, stat)
    | take 3 x == "///" = (block, stat)
    | take 2 x == "//" = promoteToCodeFileBlock (drop 2 x) xs stat
    | otherwise = (block, stat)
promoteCommentBlock block stat = (block, stat)

promoteToCodeFileBlock :: String -> [String] -> Statistics -> (Block, Statistics)
promoteToCodeFileBlock path content (MakeStatistics codefile_map) = (block, MakeStatistics new_map) where
    block = CodeFileBlock path count content
    (m_count, new_map) = Map.insertLookupWithKey incrementStatistic path 1 codefile_map
    count = countFromMaybe m_count

countFromMaybe :: Maybe Int -> Int
countFromMaybe (Just n) = n + 1
countFromMaybe _ = 1

incrementStatistic :: String -> Int -> Int -> Int
incrementStatistic _ _ value = value + 1

explainDocument :: Document -> String
explainDocument (MakeDocument _ []) = ""
explainDocument (MakeDocument stat (block:blocks)) = (explainBlock block stat) ++ (explainDocument (MakeDocument stat blocks))

explainBlock :: Block -> Statistics -> String
explainBlock (RawBlock strs) _ = unlines strs
explainBlock (CommentBlock strs) _ = "////\n" ++ unlines strs ++ "////\n"
explainBlock block@(CodeFileBlock path _ _) (MakeStatistics codefile_map) = explainCodeFileBlock block (codefile_map Map.! path)

explainCodeFileBlock :: Block -> Int -> String
explainCodeFileBlock (CodeFileBlock path count content) max_count = ""
    ++ "." ++ path ++ sortingNote count max_count ++ "\n"
    ++ "[#" ++ targetLabel path count ++ "]\n"
    ++ "++++\n"
    ++ "<div id=\"" ++ targetLabel path count ++ "\" class=\"exampleblock\" style=\"margin-bottom:1.25em;\">\n"
    ++ "<div class=\"title\">" ++ path ++ "</div>\n"
    ++ "<div class=\"content\" style=\"margin-bottom:.5em;\">\n"
    ++ (unlines $ map explainChunkContentLine content)
    ++ "</div>\n"
    ++ "</div>\n"
    ++ "++++\n"

explainChunkContentLine :: String -> String
explainChunkContentLine str =
    "<code class=\"codex\">" ++ htmlEscape str ++ "</code><span class=\"codex\">&crarr;</span><br>"

htmlEscape :: String -> String
htmlEscape "" = ""
htmlEscape ('"':cs) = "&quot;" ++ htmlEscape cs
htmlEscape ('\'':cs) = "&apos;" ++ htmlEscape cs
htmlEscape ('<':cs) = "&lt;" ++ htmlEscape cs
htmlEscape ('>':cs) = "&gt;" ++ cs
htmlEscape ('&':cs) = "&amp;" ++ cs
htmlEscape (' ':cs) = "&nbsp;" ++ cs
htmlEscape (c:cs) = c:(htmlEscape cs)

targetLabel :: String -> Int -> String
targetLabel "" index = "_" ++ show index
targetLabel ('.':cs) index = '_':(targetLabel cs index)
targetLabel (c:cs) index = c:(targetLabel cs index)

sortingNote :: Int -> Int -> String
sortingNote _ 1 = ""
sortingNote count max_count = " (" ++ show count ++ " of " ++ show max_count ++ ")"

parseLowLevel :: [String] -> [Block]
parseLowLevel [] = []
parseLowLevel ("////":xs) = (CommentBlock ls):blocks where
    (ls, lss) = seekCommentEnd [] xs
    blocks = parseLowLevel lss
parseLowLevel (x:xs) = (RawBlock (x:ls)):blocks where
    (ls, lss) = seekCommentBegin [] xs
    blocks = parseLowLevel lss

seekCommentBegin :: [String] -> [String] -> ([String], [String])
seekCommentBegin acc [] = (acc, [])
seekCommentBegin acc xs@("////":_) = (acc, xs)
seekCommentBegin acc (x:xs) = seekCommentBegin (acc ++ [x]) xs

seekCommentEnd :: [String] -> [String] -> ([String], [String])
seekCommentEnd acc [] = (acc, [])
seekCommentEnd acc ("////":xs) = (acc, xs)
seekCommentEnd acc (x:xs) = seekCommentEnd (acc ++ [x]) xs

extrudeDocument :: Document -> String
extrudeDocument _ = "extrusion\n"

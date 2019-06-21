module Codexplain (explain) where

import Data.List
import qualified Data.Map as Map

explain :: String -> (String, String)
explain input = (explanation, extrusion) where
    explanation = explainDocument document
    extrusion = extrudeDocument document
    document = parse input

data Document = MakeDocument Statistics [Block] deriving Show

data Statistics = MakeStatistics (Map.Map String Int) (Map.Map String Int) (Map.Map (String, Int) Int) deriving Show

data ChunkLine =
    CodeLine String |
    ChunkReference String Int String deriving Show

data Block =
    RawBlock [String] |
    CommentBlock [String] |
    CodeFileBlock String Int [ChunkLine] |
    ChunkBlock String Int Int [ChunkLine] deriving Show

parse :: String -> Document
parse str = MakeDocument statistics promoted_blocks where
    (promoted_blocks, statistics) = promoteCommentBlocks blocks (MakeStatistics Map.empty Map.empty Map.empty)
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
    | take 1 x == "/" = promoteToChunkBlock (drop 1 x) xs stat
    | otherwise = (block, stat)
promoteCommentBlock block stat = (block, stat)

promoteToChunkBlock :: String -> [String] -> Statistics -> (Block, Statistics)
promoteToChunkBlock name content stat@(MakeStatistics codefile_part_map chunk_form_map chunk_part_map) = (block, MakeStatistics codefile_part_map new_chunk_form_map new_chunk_part_map) where
    block = ChunkBlock name form part chunk_lines
    form = formFromMaybe m_form
    (m_form, new_chunk_form_map) = Map.insertLookupWithKey keepChunkForm name 1 chunk_form_map
    part = partFromMaybe m_part
    (m_part, new_chunk_part_map) = Map.insertLookupWithKey incrementChunkPart (name, form) 1 chunk_part_map
    chunk_lines = map (promoteToChunkLine stat) content 

formFromMaybe :: Maybe Int -> Int
formFromMaybe (Just form) = form
formFromMaybe _ = 1

keepChunkForm :: String -> Int -> Int -> Int
keepChunkForm _ _ old = old

incrementChunkPart :: (String, Int) -> Int -> Int -> Int
incrementChunkPart _ _ part = part + 1

promoteToCodeFileBlock :: String -> [String] -> Statistics -> (Block, Statistics)
promoteToCodeFileBlock path content stat@(MakeStatistics codefile_part_map chunk_form_map chunk_part_map) = (block, MakeStatistics new_codefile_map chunk_form_map chunk_part_map) where
    block = CodeFileBlock path part chunk_lines
    (m_part, new_codefile_map) = Map.insertLookupWithKey incrementCodeFilePart path 1 codefile_part_map
    part = partFromMaybe m_part
    chunk_lines = map (promoteToChunkLine stat) content

promoteToChunkLine (MakeStatistics _ chunk_form_map _) content_line
    | text /= "" && head text == '/' = ChunkReference target form prefix
    | otherwise = CodeLine content_line
    where
        target = tail text
        (prefix, text) = unPrefix content_line
        form = Map.findWithDefault 1 target chunk_form_map

unPrefix :: String -> (String, String)
unPrefix "" = ("", "")
unPrefix str@(c:cs)
    | isBlank c = (c:prefix, content)
    | otherwise = ("", str)
    where
        (prefix, content) = unPrefix cs

isBlank :: Char -> Bool
isBlank c = c `elem` " \n"

partFromMaybe :: Maybe Int -> Int
partFromMaybe (Just part) = part + 1
partFromMaybe _ = 1

incrementCodeFilePart :: String -> Int -> Int -> Int
incrementCodeFilePart _ _ part = part + 1

explainDocument :: Document -> String
explainDocument (MakeDocument _ []) = ""
explainDocument (MakeDocument stat (block:blocks)) = (explainBlock block stat) ++ (explainDocument (MakeDocument stat blocks))

explainBlock :: Block -> Statistics -> String
explainBlock (RawBlock strs) _ = unlines strs
explainBlock (CommentBlock strs) _ = "////\n" ++ unlines strs ++ "////\n"
explainBlock block@(CodeFileBlock path _ _) (MakeStatistics codefile_part_map _ _) = explainCodeFileBlock block part where
    part = (codefile_part_map Map.! path)
explainBlock block@(ChunkBlock name form _ _) (MakeStatistics _ chunk_form_map chunk_part_map) = explainChunkBlock block max_form max_part where
    max_form = chunk_form_map Map.! name
    max_part = chunk_part_map Map.! (name, form)

explainChunkBlock :: Block -> Int -> Int -> String
explainChunkBlock (ChunkBlock name form part content) max_form max_part = ""
    ++ "." ++ render_name ++ sortingNote part max_part ++ "\n"
    ++ "[#" ++ label_name ++ "]\n"
    ++ "++++\n"
    ++ "<div id=\"" ++ label_name ++ "\" class=\"exampleblock\" style=\"margin-bottom:1.25em;\">\n"
    ++ "<div class=\"title\">" ++ render_name ++ sortingNote part max_part ++ "</div>\n"
    ++ "<div class=\"content\" style=\"margin-bottom:.5em;\">\n"
    ++ (unlines $ map explainChunkContentLine content)
    ++ "</div>\n"
    ++ "<div class=\"title\"><sup>"
    ++ chunkNavigation (escapeChunkName name ++ "_" ++ show form) render_name part max_part
    ++ "</sup></div>"
    ++ "</div>\n"
    ++ "++++\n"
    where
        render_name = name ++ " (form " ++ show form ++ ")"
        label_name = chunkLabel name form part

escapeChunkName :: String -> String
escapeChunkName "" = ""
escapeChunkName ('.':cs) = '_':(escapeChunkName cs)
escapeChunkName (' ':cs) = '_':(escapeChunkName cs)
escapeChunkName (c:cs) = c:(escapeChunkName cs)

chunkLabel :: String -> Int -> Int -> String
chunkLabel name form part = escapeChunkName name ++ "_" ++ show form ++ "_" ++ show part

explainCodeFileBlock :: Block -> Int -> String
explainCodeFileBlock (CodeFileBlock path part content) max_part = ""
    ++ "." ++ path ++ sortingNote part max_part ++ "\n"
    ++ "[#" ++ label_name ++ "]\n"
    ++ "++++\n"
    ++ "<div id=\"" ++ label_name ++ "\" class=\"exampleblock\" style=\"margin-bottom:1.25em;\">\n"
    ++ "<div class=\"title\">" ++ path ++ sortingNote part max_part ++ "</div>\n"
    ++ "<div class=\"content\" style=\"margin-bottom:.5em;\">\n"
    ++ (unlines $ map explainChunkContentLine content)
    ++ "</div>\n"
    ++ "<div class=\"title\"><sup>"
    ++ codeFileNavigation path path part max_part
    ++ "</sup></div>"
    ++ "</div>\n"
    ++ "++++\n"
    where
        label_name = codeFileLabel path part

codeFileNavigation :: String -> String -> Int -> Int -> String
codeFileNavigation _ _ _ 1 = ""
codeFileNavigation label_name render_name part max_part = navigation ++ end_of_line where
    navigation = intercalate ", " navigators
    end_of_line = if navigation /= "" then ".<br>" else ""
    navigators = first ++ previous ++ next ++ last
    first = if part > 2 then ["First: " ++ anchorize 1] else []
    previous = if part /= 1 then ["Previous: " ++ anchorize (part - 1)] else []
    next = if part /= max_part then ["Next: " ++ anchorize (part + 1)] else []
    last = if part < max_part - 1 then ["Last: " ++ anchorize max_part] else []
    anchorize = codeFileHRef label_name render_name max_part

chunkNavigation :: String -> String -> Int -> Int -> String
chunkNavigation _ _ _ 1 = ""
chunkNavigation label_name render_name part max_part = navigation ++ end_of_line where
    navigation = intercalate ", " navigators
    end_of_line = if navigation /= "" then ".<br>" else ""
    navigators = first ++ previous ++ next ++ last
    first = if part > 2 then ["First: " ++ anchorize 1] else []
    previous = if part /= 1 then ["Previous: " ++ anchorize (part - 1)] else []
    next = if part /= max_part then ["Next: " ++ anchorize (part + 1)] else []
    last = if part < max_part - 1 then ["Last: " ++ anchorize max_part] else []
    anchorize = codeFileHRef label_name render_name max_part

codeFileHRef :: String -> String -> Int -> Int -> String
codeFileHRef label_name render_name max_part part = ""
    ++ "<a href=\"#"
    ++ codeFileLabel label_name part
    ++ "\">"
    ++ render_name
    ++ sortingNote part max_part
    ++ "</a>"

explainChunkContentLine :: ChunkLine -> String
explainChunkContentLine (ChunkReference target form prefix) = ""
    ++ "<code class=\"codex\">" ++ htmlEscape prefix ++ "</code>"
    ++ "<em><a href=\"#" ++ codeFileLabel target form ++ "_1\">" ++ target ++ "</a></em>"
    ++ "<span class=\"codex\">&crarr;</span><br>"
explainChunkContentLine (CodeLine str) =
    "<code class=\"codex\">" ++ htmlEscape str ++ "</code><span class=\"codex\">&crarr;</span><br>"

htmlEscape :: String -> String
htmlEscape "" = ""
htmlEscape ('"':cs) = "&quot;" ++ htmlEscape cs
htmlEscape ('\'':cs) = "&apos;" ++ htmlEscape cs
htmlEscape ('<':cs) = "&lt;" ++ htmlEscape cs
htmlEscape ('>':cs) = "&gt;" ++ htmlEscape cs
htmlEscape ('&':cs) = "&amp;" ++ htmlEscape cs
htmlEscape (' ':cs) = "&nbsp;" ++ htmlEscape cs
htmlEscape (c:cs) = c:(htmlEscape cs)

codeFileLabel :: String -> Int -> String
codeFileLabel "" part = "_" ++ show part
codeFileLabel (' ':cs) part = '_':(codeFileLabel cs part)
codeFileLabel ('.':cs) part = '_':(codeFileLabel cs part)
codeFileLabel (c:cs) part = c:(codeFileLabel cs part)

sortingNote :: Int -> Int -> String
sortingNote _ 1 = ""
sortingNote part max_part = " (" ++ show part ++ " of " ++ show max_part ++ ")"

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

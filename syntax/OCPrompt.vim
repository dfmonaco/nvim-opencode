" Syntax file for OCPrompt filetype

if exists('b:current_syntax')
  finish
endif

" Match file references: @path/to/file
" Pattern: @ followed by alphanumeric, underscore, slash, dot, or hyphen
syntax match OCFileReference /@[a-zA-Z0-9_/.\-]\+/

" Link to highlight group (defined in ftplugin)
highlight default link OCFileReference Special

let b:current_syntax = 'OCPrompt'

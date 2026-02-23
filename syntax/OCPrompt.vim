" Syntax file for OCPrompt filetype

if exists('b:current_syntax')
  finish
endif

" Match file references: ./path/to/file (optionally followed by a #L10-L20 or #L5:C3 range)
" Pattern: literal ./ followed by path characters, with an optional #anchor suffix
syntax match OCFileReference /\.\{1,}\/[a-zA-Z0-9_\/.\-]\+\(#[a-zA-Z0-9.:_\-]\+\)\?/

" Link to highlight group (defined in ftplugin)
highlight default link OCFileReference Special

let b:current_syntax = 'OCPrompt'

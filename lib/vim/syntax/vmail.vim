" Vim syntax file
" Language:	Vmail message list
" Maintainer:	Greg Sexton <gregsexton@gmail.com>
" Last Change:	2011-08-26
"

if exists("b:current_syntax")
    finish
endif

syn match vmailSizeCol /|\s\+\(< 1k\|\d*\(b\|k\|M\|G\)\)\s\+|/ contains=vmailSeperator contained

syn match vmailFirstCol /^.\{-}|/ nextgroup=vmailDateCol
syn match vmailFirstColAnswered /An/ contained containedin=vmailFirstCol
syn match vmailFirstColForward /\$F/ contained containedin=vmailFirstCol
syn match vmailFirstColNotJunk /No/ contained containedin=vmailFirstCol

syn match vmailDateCol /\s\+... \d\d \(\(\d\d:\d\d..\)\|\(\d\{4}\)\)\s\+|/ nextgroup=vmailFromCol contains=vmailSeperator

syn match vmailFromCol /\s.\{-}|\@=/ contained nextgroup=vmailFromSeperator
syn match vmailFromColEmail /<[^ ]*/ contained containedin=vmailFromCol
syn match vmailFromSeperator /|/ contained nextgroup=vmailSubject

syn match vmailSubject /.*\s\+/ contained contains=vmailSizeCol
syn match vmailSubjectRe /\cre:\|fwd:/ contained containedin=vmailSubject

syn match vmailSeperator /|/ contained

syn match vmailNewMessage /^\s*+.*/
syn match vmailStarredMessage /^\s*\*.*/

hi def link vmailFirstCol         Comment
hi def link vmailDateCol          Statement
hi def link vmailFromCol          Identifier
hi def link vmailSizeCol          Constant
hi def link vmailSeperator        Comment
hi def link vmailFromSeperator    vmailSeperator
hi def link vmailFromColEmail     Comment
hi def link vmailSubjectRe        Type
hi def link vmailFirstColSpec     Number
hi def link vmailFirstColAnswered vmailFirstColSpec
hi def link vmailFirstColForward  vmailFirstColSpec
hi def link vmailFirstColNotJunk  vmailFirstColSpec
hi def link vmailSpecialMsg       Special
hi def link vmailNewMessage       vmailSpecialMsg
hi def link vmailStarredMessage   vmailSpecialMsg
"uncomment next line for subject highlighting
"hi def link vmailSubject Statement

let b:current_syntax = "vmail"

" netrw.vim: Handles file transfer and remote directory listing across a network
"            PLUGIN PORTION
" Last Change:	Aug 31, 2005
" Maintainer:	Charles E Campbell, Jr <drchipNOSPAM at campbellfamily dot biz>
" Version:	68
" License:	Vim License  (see vim's :help license)
" GetLatestVimScripts: 1075 1 :AutoInstall: netrw.vim
" Copyright:    Copyright (C) 1999-2005 Charles E. Campbell, Jr. {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               netrw.vim is provided *as is* and comes with no warranty
"               of any kind, either expressed or implied. By using this
"               plugin, you agree that in no event will the copyright
"               holder be liable for any damages resulting from the use
"               of this software.
"
"  But be doers of the Word, and not only hearers, deluding your own selves {{{1
"  (James 1:22 RSV)
" =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

" ---------------------------------------------------------------------
" Load Once: {{{1
if exists("g:loaded_netrw") || &cp
  finish
endif
if v:version < 600
 echoerr "***netrw*** doesn't support Vim version ".v:version
 finish
endif
let g:loaded_netrw  = "v68"
if v:version < 700
 let loaded_explorer = 1
endif
let s:keepcpo= &cpo
set cpo&vim

" ---------------------------------------------------------------------
" Public Interface: {{{1

" Local Browsing: {{{2
augroup FileExplorer
 au!
 au BufEnter * call s:LocalBrowse(expand("<amatch>"))
augroup END

" Network Browsing Reading Writing: {{{2
augroup Network
 au!
 if has("win32") || has("win95") || has("win64") || has("win16")
  au BufReadCmd  file://*		exe "silent doau BufReadPre ".expand("<amatch>")|exe 'e '.substitute(expand("<amatch>"),"file:/*","","")|exe "silent doau BufReadPost ".expand("<amatch>")
 else
  au BufReadCmd  file:///*		exe "silent doau BufReadPre ".expand("<amatch>")|exe 'e /'.substitute(expand("<amatch>"),"file:/*","","")|exe "silent doau BufReadPost ".expand("<amatch>")
  au BufReadCmd  file://localhost/*	exe "silent doau BufReadPre ".expand("<amatch>")|exe 'e /'.substitute(expand("<amatch>"),"file:/*","","")|exe "silent doau BufReadPost ".expand("<amatch>")
 endif
 au BufReadCmd   ftp://*,rcp://*,scp://*,http://*,dav://*,rsync://*,sftp://*	exe "silent doau BufReadPre ".expand("<amatch>")|exe "Nread 0r ".expand("<amatch>")|exe "silent doau BufReadPost ".expand("<amatch>")
 au FileReadCmd  ftp://*,rcp://*,scp://*,http://*,dav://*,rsync://*,sftp://*	exe "silent doau BufReadPre ".expand("<amatch>")|exe "Nread "   .expand("<amatch>")|exe "silent doau FileReadPost ".expand("<amatch>")
 au BufWriteCmd  ftp://*,rcp://*,scp://*,dav://*,rsync://*,sftp://*    	exe "silent doau BufWritePre ".expand("<amatch>")|exe "Nwrite " .expand("<amatch>")|exe "silent doau BufWritePost ".expand("<amatch>")
 au FileWriteCmd ftp://*,rcp://*,scp://*,dav://*,rsync://*,sftp://*    	exe "silent doau BufWritePre ".expand("<amatch>")|exe "'[,']Nwrite " .expand("<amatch>")|exe "silent doau FileWritePost ".expand("<amatch>")
augroup END

" Commands: :Nread, :Nwrite, :NetUserPass {{{2
com! -nargs=*		Nread		call netrw#NetSavePosn()<bar>call netrw#NetRead(<f-args>)<bar>call netrw#NetRestorePosn()
com! -range=% -nargs=*	Nwrite		call netrw#NetSavePosn()<bar><line1>,<line2>call netrw#NetWrite(<f-args>)<bar>call netrw#NetRestorePosn()
com! -nargs=*		NetUserPass	call NetUserPass(<f-args>)

" Commands: :Explore, :Sexplore, Hexplore, Vexplore {{{2
com! -nargs=? -bar -bang -count=0  	Explore		call netrw#Explore(<count>,0,0+<bang>0,<q-args>)
com! -nargs=? -bar -bang -count=0  	Sexplore	call netrw#Explore(<count>,1,0+<bang>0,<q-args>)
com! -nargs=? -bar -bang -count=0  	Hexplore	call netrw#Explore(<count>,1,2+<bang>0,<q-args>)
com! -nargs=? -bar -bang -count=0  	Vexplore	call netrw#Explore(<count>,1,4+<bang>0,<q-args>)
com! -nargs=? -bar -bang   		Nexplore	call netrw#Explore(-1,0,0,<q-args>)
com! -nargs=? -bar -bang   		Pexplore	call netrw#Explore(-2,0,0,<q-args>)

" Commands: NetrwSettings {{{2
com! -nargs=0 NetrwSettings :call NetrwSettings#NetrwSettings()

" ---------------------------------------------------------------------
" LocalBrowse: {{{2
fun! s:LocalBrowse(dirname)
  " unfortunate interaction -- debugging calls can't be used here;
  " the BufEnter event causes triggering when attempts to write to
  " the DBG buffer are made.
  if isdirectory(a:dirname)
   call netrw#DirBrowse(a:dirname)
  endif
  " not a directory, ignore it
endfun

" ---------------------------------------------------------------------
" NetrwStatusLine: {{{1
fun! NetrwStatusLine()
"  let g:stlmsg= "Xbufnr=".w:netrw_explore_bufnr." bufnr=".bufnr(".")." Xline#".w:netrw_explore_line." line#".line(".")
  if !exists("w:netrw_explore_bufnr") || w:netrw_explore_bufnr != bufnr(".") || !exists("w:netrw_explore_line") || w:netrw_explore_line != line(".") || !exists("w:netrw_explore_list")
   let &stl= s:netrw_explore_stl
   if exists("w:netrw_explore_bufnr")|unlet w:netrw_explore_bufnr|endif
   if exists("w:netrw_explore_line")|unlet w:netrw_explore_line|endif
   return ""
  else
   return "Match ".w:netrw_explore_mtchcnt." of ".w:netrw_explore_listlen
  endif
endfun

" ------------------------------------------------------------------------
" NetUserPass: set username and password for subsequent ftp transfer {{{1
"   Usage:  :call NetUserPass()			-- will prompt for userid and password
"	    :call NetUserPass("uid")		-- will prompt for password
"	    :call NetUserPass("uid","password") -- sets global userid and password
fun! NetUserPass(...)

 " get/set userid
 if a:0 == 0
"  call Dfunc("NetUserPass(a:0<".a:0.">)")
  if !exists("g:netrw_uid") || g:netrw_uid == ""
   " via prompt
   let g:netrw_uid= input('Enter username: ')
  endif
 else	" from command line
"  call Dfunc("NetUserPass(a:1<".a:1.">) {")
  let g:netrw_uid= a:1
 endif

 " get password
 if a:0 <= 1 " via prompt
"  call Decho("a:0=".a:0." case <=1:")
  let g:netrw_passwd= inputsecret("Enter Password: ")
 else " from command line
"  call Decho("a:0=".a:0." case >1: a:2<".a:2.">")
  let g:netrw_passwd=a:2
 endif
"  call Dret("NetUserPass")
endfun

" ------------------------------------------------------------------------
" NetReadFixup: this sort of function is typically written by the user {{{1
"               to handle extra junk that their system's ftp dumps
"               into the transfer.  This function is provided as an
"               example and as a fix for a Windows 95 problem: in my
"               experience, win95's ftp always dumped four blank lines
"               at the end of the transfer.
if has("win95") && g:netrw_win95ftp
 fun! NetReadFixup(method, line1, line2)
"   call Dfunc("NetReadFixup(method<".a:method."> line1=".a:line1." line2=".a:line2.")")
   if method == 3   " ftp (no <.netrc>)
    let fourblanklines= line2 - 3
    silent fourblanklines.",".line2."g/^\s*/d"
   endif
"   call Dret("NetReadFixup")
 endfun
endif

let &cpo= s:keepcpo
unlet s:keepcpo
" ------------------------------------------------------------------------
" Modelines: {{{1
" vim:ts=8 fdm=marker

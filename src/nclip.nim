## | This module is a wrapper around the Windows API
## | Make it easy to interact with the clipboard

import std/strutils
import winim/lean

proc GlobalAlloc*(str: cstring): HGLOBAL =
    ## | Alloc memory and copy `str` to it
    ## | return the handle to that memory  
    let hdst = GlobalAlloc(GPTR or GMEM_MOVEABLE, len(str)+1)
    if hdst == FALSE: return 0
    let dst = GlobalLock(hdst)
    if dst == NULL: return 0
    copyMem(cast[pointer](dst), unsafeAddr str[0], len(str)+1)
    GlobalUnlock(hdst)
    return hdst

proc DragQueryFile*(hDrop: HANDLE, iFile: UINT, lpszFile: LPSTR, cch: UINT): UINT {.stdcall, dynlib: "shell32", importc.}
    ## | return the path of the `iFile` file in the clipboard
    ## | return the number of files in the clipboard if `iFile` is `0xFFFFFFFF`
    ## .. note:: this is an `importc` proc from `shell32`

proc GetFilesFromClipboard*(files: HANDLE): string =
    ## | Get the filenames copied in the buffer
    ## | format them like this:
    ## | `<path1>:::::<path2>:::::<path3>` etc.
    result = ""
    if files == FALSE: return result
    let hdrop = cast[HANDLE](GlobalLock(files))
    let nfiles = DragQueryFile(hdrop, cast[UINT](0xFFFFFFFF), cast[LPSTR](0), 0)
    var filename = newString(260)
    for i in 0..<nfiles:
        let len = DragQueryFile(hdrop, i, cast[LPSTR](unsafeAddr filename[0]), filename.len.UINT)
        result &= filename[0..len-1] & ":::::"
    result.removeSuffix(":::::")
    GlobalUnlock(files)

proc GetTextFromClipboard*(hcp: HANDLE): string =
    ## | Retrieve the text in the clipboard and return it as a string
    result = $(cast[cstring](GlobalLock(hcp)))
    GlobalUnlock(hcp)

type ClipType* = enum ## enum for `GetClipboardData` precising the kind of data arriving
    CP_EMPTY, CP_TEXT, CP_FILE

proc GetClipboardData*(): (ClipType, string) =
    ## | Wrapper to `GetClipboardData`
    ## | Check for TEXT (CF_TEXT) and File (CF_HDROP)
    ## | return the content and an `enum`  
    while OpenClipboard(0) == FALSE: discard
    let txt = GetTextFromClipboard(GetClipboardData(CF_TEXT))
    let fs  = GetFilesFromClipboard(GetClipboardData(CF_HDROP))
    if txt != "": result = (CP_TEXT, txt)
    elif fs != "": result = (CP_FILE, fs)
    else: result = (CP_EMPTY, "")
    CloseClipboard()

proc SetClipboardData*(str: cstring): bool =
    ## | Wrapper to `SetClipboardData`
    ## | set `str` as new clipboard content
    ## 
    ## `WM_CLIPBOARDUPDATE` will be set  
    while OpenClipboard(0) == FALSE: discard
    if EmptyClipboard() == FALSE: return false
    if SetClipboardData(CF_TEXT, GlobalAlloc(str)) == FALSE: return false
    CloseClipboard() == TRUE

proc ClearClipboard*() =
    ## | Wrapper to `EmptyClipboard`
    ## | The clipboard will be empty afterward
    ## 
    ## `WM_CLIPBOARDUPDATE` will be set  
    while OpenClipboard(0) == FALSE: discard
    EmptyClipboard()
    CloseClipboard()

proc AddClipboardFormatListener*(): bool =
    ## | Wrapper to `AddClipboardFormatListener`
    ## | Create a Window and subscribe it to the clipboard events  
    var hwnd = CreateWindowEx(0, "Message", "", 0, 0, 0, 0, 0, HWND_MESSAGE, 0, 0, NULL)
    if hwnd == FALSE: return false
    AddClipboardFormatListener(hwnd) != 0

proc GetMessage*(msg: var MSG): WINBOOL =
    ## | Wrapper to `GetMessage`
    ## | put the message into `msg`
    GetMessage(msg, 0,0,0)

var
    uiDataObjectFormat = 0
    uiOlePrivateDataFormat = 0
proc IsOleAllowedType*(uFormat: UINT): bool =
    ## | check if `uFormat` is allowed
    ## .. note:: CF_LOCALE isn't OLE, but should still be allowed through..
    if 0 == uiDataObjectFormat:
        uiDataObjectFormat = RegisterClipboardFormatW("DataObject")
    if 0 == uiOlePrivateDataFormat:
        uiOlePrivateDataFormat = RegisterClipboardFormatW("Ole Private Data")
    return ((uiDataObjectFormat == uFormat) or (uiOlePrivateDataFormat == uFormat) or (CF_LOCALE == uFormat))

proc IsClipboardFormatTextual*(uFormat: UINT): bool =
    ## | check if `uFormat` is Textual
    ## .. note:: What about CF_DSPTEXT ?
    case uFormat
    of CF_TEXT,CF_OEMTEXT,CF_UNICODETEXT: return true
    else: return false

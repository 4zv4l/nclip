import std/[threadpool, unittest]
import winim/lean
import nclip

test "get clipboard update":
  proc put_data() =
    ## push data into the clipboard as exfiltration test
    Sleep(2_000) # wait for the main thread to subscribe to clipboard event
    let data = ["hello", "world", "end"]
    for str in data:
      check SetClipboardData(str.cstring) == true
      Sleep(2_000)

  # spawn a thread that will push data into the clipboard
  spawn put_data()
  # subscribe to the clipboard event
  if not AddClipboardFormatListener():
    quit "could not listen for clipboard event: " & $GetLastError()
  
  # listen for clipboard event
  echo "waiting for clipboard event"
  var msg: MSG
  while GetMessage(msg):
    if msg.message == WM_CLIPBOARDUPDATE:
      let (dtype, data) = GetClipboardData()
      if dtype == CP_TEXT:
        case data:
          of "hello": echo "got first message !"
          of "world": echo "got second message !"
          of "end": quit "got last message !", 0
          else: echo "waiting.."

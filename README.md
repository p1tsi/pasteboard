Nothing particularly interesting here: it is well known that every macOS process is able to access data inside Pasteboards.

Just spent some time developing [wormhole](https://github.com/p1tsi/wormhole) with its XPC interceptor module 
and applied it to reverse macOS Pasteboard.

```
% gcc -framework Foundation -o paste paste.m
% ./paste (or launchctl load paste.plist)
```

The only interesting thing, I guess, is that this binary is able to access TCC protected 
files and directories without prompts (such those under Downloads, Desktop or Documents) 
when the user copy them from Finder.

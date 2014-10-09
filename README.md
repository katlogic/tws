Tiny Web Sockets
================
A small (130 line-ish) websocket server implementation.

Intro docs
----------

```CoffeeScript
http = require 'http'
tws = require './tws'
fs = require 'fs'

# Expected URL prefix which is assumed to be websocket.
# Can be regex pattern too, but must match from start of url.
wsurl = '/echo/'

# tws(url,server,events)
# events can be also function, to install events run time
s = tws wsurl, http.createServer(),
  ws_open: (req) ->
    console.log 'client connected'
  error: (e) ->
    console.log e
  close: () ->
    console.log 'closed'
  ws_text: (s) ->
    console.log "got #{s}"
    # Buffer (=> UInt8Array) or String (=> utf8 String) supported
    @write s
  # Can also handle ws_data (typed arrays), ws_close.
  # See tws.coffee for details.

# This event is emitted if the client is not actually websocket.
# Equal to ordinary 'request'
s.on 'http_request', (req, resp)->
  data = fs.readFileSync("test.html")
  resp.writeHead 200, 'Content-Length': data.length, 'Content-Type': 'text/html'
  resp.end data

s.listen(80)
```


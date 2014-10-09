http = require 'http'
tws = require './tws'
fs = require 'fs'

wsurl = '/echo/'

s = tws wsurl, http.createServer(),
  ws_open: (req) ->
    console.log 'client connected'
  error: (e) ->
    console.log e
  close: () ->
    console.log 'closed'
  ws_text: (s) ->
    console.log "got #{s}"
    @write s

s.on 'http_request', (req, resp)->
  data = fs.readFileSync("test.html")
  resp.writeHead 200, 'Content-Length': data.length, 'Content-Type': 'text/html'
  resp.end data

s.listen(80)

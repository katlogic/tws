crypto = require 'crypto'

# Wrap httpserver object
module.exports = (url, server, handler) ->
  # Check that url matches supplied regex
  is_ws = (req) ->
    return null if req.url.search(url) != 0
    key = req.headers['sec-websocket-key']
    return key

  # Process request
  do_req = (sk, req) ->
    if not key = is_ws req
      req.close
      return
    sk.on 'data', do_data
    # If it's a function, we expect it to install event handlers
    if typeof handler == 'function'
      sk = handler(sk, req) || sk
    else
      # Otherwise it's a handler list
      for f of handler
        sk.on f, handler[f]
    sk.ws_buffer = null
    h = crypto.createHash 'sha1'
    h.update key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
    d = h.digest 'base64'
    sk.write 'HTTP/1.1 101 Switching Protocols\r\n' +
      "Upgrade: WebSocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{d}\r\n\r\n"

    sk.ws_send = (typ, chunk, cb) ->
      len = 2
      if len > 65535
        len += 8
      else if len > 126
        len += 2
      len += chunk.length
      buf = new Buffer len
      len = 0
      buf.writeUInt8 typ, len++
      if chunk.length > 65535
        buf.writeUInt8 127,len++
        buf.writeUInt32BE 0,len
        buf.writeUInt32BE chunk.length,len+4
        len += 8
      else if chunk.length > 126
        buf.writeUInt8 126,len++
        buf.writeUInt16BE chunk.length,len
        len += 2
      else
        buf.writeUInt8 chunk.length,len++
      chunk.copy buf, len
      this.__proto__._write.call this,buf,null,cb
      return

    # Monkey patch write handler, I'll rot in hell for this
    sk._write = (chunk, encoding, cb) ->
      typ = 0x82
      if typeof chunk == 'string'
        typ = 0x81
        chunk = new Buffer chunk
      @ws_send typ, chunk, cb
    sk.emit 'ws_open', req
    return

  # Process data
  do_data = (data) ->
    if sbuf = @ws_buffer
      nb = new Buffer sbuf.length + data.length
      sbuf.copy nb
      data.copy nb, sbuf.length
      sbuf = @ws_buffer = nb
    else sbuf = @ws_buffer = data
    while sbuf.length >= 2
      key = 0
      ofs = 0
      op = sbuf.readUInt8 ofs++
      tmp = sbuf.readUInt8 ofs++
      mask = tmp >> 7
      len = tmp & 127
      if len == 126
        break if sbuf.length-ofs < 2
        len = sbuf.readUInt16BE ofs
        ofs += 2
      else if len == 127
        break if sbuf.length-ofs < 8
        ofs += 4
        len = sbuf.readUInt32BE ofs
        ofs += 4
      if mask
        break if sbuf.length-ofs < 4
        key = sbuf.readUInt32BE ofs 
        ofs += 4
      break if sbuf.length-ofs < len
      buf = sbuf.slice(ofs, ofs+len)
      if key|0
        mofs = 0
        while mofs + 4 < buf.length
          buf.writeUInt32BE(buf.readUInt32BE(mofs) ^ key, mofs)
          mofs += 4
        for bpad in [0...(buf.length - mofs)] by 1
          buf.writeUInt8(buf.readUInt8(mofs + bpad) ^ ((key>>(8*(3-bpad))&255)), mofs + bpad)
      switch op
        when 0x81
          @emit 'ws_text', buf.toString('utf8')
        when 0x82
          @emit 'ws_data', buf
        when 0x89
          @emit 'ws_ping', buf
          @ws_send 0x8a, new Buffer 0
        else
          @emit 'ws_close', buf, op
          @end()
          return
      sbuf = sbuf.slice(ofs+len)
    @ws_buffer = sbuf
    return
  server.on 'upgrade', (req, sk, data)->
    do_req sk, req
    do_data.call sk, data if data?.length
    return

  # Simulated upgrade. Stupid firewalls strip the header and
  # Connection: type. None the less, they keep the stream intact.
  # If you pray, you can run websocket in places which would fail otherwise.
  server.on 'request', (req, resp)->
    sk = req.connection
    if is_ws req
      # simulate upgrade
      sk.parser.incoming.upgrade = true
      sk.emit 'data', new Buffer(0)
    else
      # otherwise ordinary http request
      server.emit 'http_request', req, resp
    return
  server

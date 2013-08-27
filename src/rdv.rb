#!/usr/local/bin/ruby19
# -*- coding; utf-8 -*-
require 'webrick'
require 'webrick/cgi'
require 'erb'
require 'pp'
require 'rinda/tuplespace'

class RdVSpace
 def initialize
   @ts = Rinda::TupleSpace.new(1)
   @expires = 60
 end

 def write(name, type, body)
   _,_,key = @ts.take([:get, name, nil], @expires)
   @ts.write([:post, key, type, body], @expires)
 end

 def take(name)
   key = Object.new
   @ts.write([:get, name, key], @expires)
   _,_, type, body = @ts.take([:post, key, nil, nil], @expires)
   [type, body]
 end
end

class RdVUp < WEBrick::CGI
 include ERB::Util

 def initialize(*args)
   super(*args)
   @rdv = RdVSpace.new
 end

 RHTML = <<EOS
<html><title>RdVUp!</title><meta name="viewport" content="width=320" /><body><% uri = req.request_uri.dup; uri.query = nil %>
<form method='post' action='<%= uri %>' enctype='multipart/form-data'>
<input type='file' name='file'/><br />
key: <input type='textfield' name='name' value='<%=h key %>'/><br />
<input type='submit' value='RdV' />
</form>
</body></html>
EOS

 ERB.new(RHTML).def_method(self, 'to_html(req,key="")')

 def do_GET(req, res)
   name = req.path_info
   if name == ''
     res['content-type'] = 'text/html'
     res.body = to_html(req)
     res.status = 200
   else
     type, body = @rdv.take(name)
     res['content-type'] = type
     res.body = body
     res.status = 200
   end
 end

 def do_POST(req, res)
   if req.query['file']
     ext = File.extname(req.query['file'].filename)
     type = req.query['file']['content-type'].to_s
     body = req.query['file'].to_s
     name = req.query['name'].to_s
     @rdv.write('/' + name, type, body)
     res['content-type'] = 'text/html'
     res.body = to_html(req, name)
     res.status = 200
   else
     do_GET(req, res)
   end
 end
end

unless $DEBUG
 exit!(0) if fork
 Process.setsid
 exit!(0) if fork
end

app = RdVUp.new
DRb.start_service('druby://localhost:54331', app)

unless $DEBUG
 STDIN.reopen('/dev/null')
 STDOUT.reopen('/dev/null', 'w')
 STDERR.reopen('/dev/null', 'w')
end

DRb.thread.join


http     = require 'http'
readline = require 'readline'
colors   = require 'colors'
inspect  = require('eyes').inspector()

Request   = require './Request'
CookieJar = require './CookieJar'

class RestConsole
	
	constructor: (config) ->
		@protocol = config.protocol ? 'http'
		@host     = config.host     ? 'localhost'
		@port     = config.port     ? 80
		
		@cookieJar = new CookieJar config.cookieFile ? 'cookies.json'
		@path = []
		@stickyHeaders = {}
		
		@readline  = readline.createInterface(process.stdin, process.stdout)
	
	start: ->
		@readline.on 'line', (line) =>
			@onInput line.trim()
			
		@readline.on 'close', =>
			console.log()
			@exit()
		
		process.stdin.on 'keypress', (s, key) =>
			if key? and key.ctrl and key.name is 'l'
				@clearScreen()
				
		@reset()
		@showPrompt()
	
	onInput: (line) ->
		if @state is 'command'
			@processCommand line
		else
			if line.length is 0
				@executeRequest()
			else
				if @request.data? then @request.data += line else @request.data = line
				@showPrompt()
	
	exit: ->
		console.log 'Bye.'
		process.exit(0)
	
	reset: ->
		@state = 'command'
		@request = new Request(@protocol, @host, @port, @cookieJar, @stickyHeaders)
	
	processCommand: (line) ->
		[command, args...] = line.split /\s+/
		command = command.toLowerCase()
		
		if command is 'cd'
			path = @_processPath args[0]
			if path is null
				console.log 'Invalid path'.red
			else
				@path = path
				
		else if command is 'set'
			what = args?[0]
			if not what?
				console.log 'Set what?'.red
			else if what is 'header'
				[name, value] = args[1].split /\s*=\s*/
				@request.setHeader(name, value)
				if args?[2] is 'sticky' then @stickyHeaders[name] = value
			else
				console.log "I don't know how to set #{what.bold}".red
				
		else if command is 'show'
			what = args?[0]
			if not what?
				console.log 'Show what?'.yellow
			else if what is 'cookies'
				inspect(@cookieJar.cookies)
			else if what is 'headers'
				inspect(@request.headers)
			else
				console.log "I don't know how to show #{what.bold}".red
				
		else if command in ['get', 'put', 'post', 'delete', 'head']
			@request.method = command
			@request.path   = @path
			if args.length > 0 then @request.setFormat args[0]
			if command is 'put' or command is 'post'
				@state = 'data'
				@showPrompt()
			else
				@executeRequest()
			return
			
		else if command in ['quit', 'exit']
			@exit()
			return
			
		else if command isnt ''
			console.log "Unknown command #{command.bold}".red
		
		@showPrompt()
	
	clearScreen: ->
		process.stdout.write '\u001B[2J\u001B[0;0f'
		@showPrompt()
	
	showPrompt: ->
		if @state is 'command'
			site = "#{@protocol}://#{@host}:#{@port} "
			path = '/' + @path.join '/'
			end  = ' > '
			@readline.setPrompt site.grey + path.white + end.grey, (site + path + end).length
		else
			format = @request.format
			end    = ' | '
			@readline.setPrompt format.white + end.grey, (format + end).length
		@readline.prompt()
	
	executeRequest: ->
		@request.execute (response, body) =>
			@cookieJar.update(response)
			@showResponse response, body, =>
				@reset()
				@showPrompt()
	
	showResponse: (response, body, callback) ->
		status = "HTTP/#{response.httpVersion} #{response.statusCode} #{http.STATUS_CODES[response.statusCode]}"
		
		if      response.statusCode >= 500 then status = status.red
		else if response.statusCode >= 400 then status = status.yellow
		else if response.statusCode >= 300 then status = status.cyan
		else status = status.green
		
		console.log status
		inspect(response.headers)
		
		try
			result = JSON.parse(body)
		catch ex
			result = body.trim()
		
		if _.isString(result)
			if result.length isnt 0
				console.log result.white
		else
			inspect(result)
		
		if process.stdout.write ''
			callback()
		else
			process.stdout.on 'drain', callback
	
	_processPath: (str) ->
		segments = _.filter str.split('/'), (segment) -> segment.length
		if str[0] is '/'
			path = segments
		else
			path = @path.slice(0)
			for segment in segments
				if segment is '..'
					if path.length is 0 then return null
					path.pop()
				else
					path.push segment
		return path
	
module.exports = RestConsole
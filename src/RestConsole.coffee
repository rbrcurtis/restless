fs = require 'fs'
http     = require 'http'
readline = require 'readline'
Request   = require './Request'
CookieJar = require './CookieJar'
coffee    = require 'coffee-script'

class RestConsole

	constructor: (@config) ->
		@protocol = @config.protocol ? 'http'
		@host     = @config.host     ? 'localhost'
		@port     = @config.port
		unless @port?
			@port = switch @protocol
				when 'http' then 80
				when 'https' then 443

		@cookieJar = new CookieJar "#{__dirname}/../cookies.json"
		@path = []

		@readline = readline.createInterface(process.stdin, process.stdout)

		process.on 'uncaughtException', (err) =>
			console.error err.message, err.stack
			@showPrompt()

	start: ->
		if @config.path?.length
			@processCommand "cd #{@config.path}"
		@readline.on 'line', (line) =>
			@processCommand line.trim()

		@readline.on 'close', =>
			console.log()
			@exit()

		process.stdin.on 'keypress', (s, key) =>
			if key? and key.ctrl and key.name is 'l'
				@clearScreen()

		@reset()
		@showPrompt()

	exit: ->
		console.log 'Bye.'
		process.exit(0)

	reset: ->
		try
			headers = require("#{__dirname}/../headers.json")
		catch error
			headers = {}
		@request = new Request(@protocol, @host, @port, @cookieJar, headers)

	saveHeaders: ->
		fs.writeFileSync("#{__dirname}/../headers.json", JSON.stringify(@request.headers) + "\n")

	processCommand: (line) ->
		unless line then return @showPrompt()
		args = line.match /("[^"]+"="[^"]+")|("[^"]+"=[^\s]+)|([^\s]+="[^"]+")|("[^"]+")|([^\s]+)/g
		command = args.shift().toLowerCase()

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
				[name, value] = args.slice(1).join(' ').split /:/
				name = @_trimQuotes name.trim()
				value = @_trimQuotes value.trim()

				@request.setHeader(name, value)
				@saveHeaders()
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

		else if command is 'clear'
			what = args?[0]
			if not what?
				console.log 'Clear what?'.yellow
			else if what is 'cookies'
				@cookieJar.cookies = {}
			else if what is 'headers'
				@request.headers = {}
				@saveHeaders()
			else
				console.log "I don't know how to show #{what.bold}".red

		else if command in ['get', 'put', 'post', 'delete', 'head', 'patch', 'options']
			@request.method = command
			@request.path   = @path
			if args.length > 0 then @request.setFormat args[0]
			if command in ['put', 'post', 'patch']
				@getData (data) =>
					if @request.format is 'json'
						try
							data = coffee.eval data
						catch e
					@request.data = data
					@executeRequest()
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
		site = "#{@protocol}://#{@host}:#{@port} "
		path = '/' + @path.join '/'
		end  = ' > '
		@readline.setPrompt site.white + path.white + end.white, (site + path + end).length
		@readline.prompt()

	getData: (callback) ->
		@readline.question "#{@request.format} | ", callback

	executeRequest: ->
		@request.execute (response, body) =>
			if response then @cookieJar.update(response)
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
			result = body?.trim?() or body

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

	_trimQuotes: (str) ->
		if str[0] is '"' then str.substr(1, str.length - 2) else str

module.exports = RestConsole

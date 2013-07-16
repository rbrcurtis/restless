request = require 'request'

class Request
	
	constructor: (@protocol, @host, @port, @cookieJar, @headers = {}) ->
		@setFormat 'json'
		
		@data = ""
	
	setFormat: (format) ->
		@format = format
	
	setHeader: (name, value) ->
		@headers[name] = value
	
	addData: (line) ->
		@data += line

	execute: (callback) ->
		console.log {@data}
		path = encodeURI '/' + @path.join('/')
		options =
			url: "#{@protocol}://#{@host}:#{@port}#{path}"
			method:  @method.toUpperCase()
			headers: @headers
			rejectUnauthorized: false

		if @format is 'json' then options.json = @data
		else options.body = @data
		
		unless @cookieJar.isEmpty
			options.headers['Cookie'] = @cookieJar.toHeader()

		request options, (e, r, body) ->
			callback r, body
		

module.exports = Request

moment = require 'moment'
pr = require 'bluebird'
fs = pr.promisifyAll require 'fs'
mkdirp = require 'mkdirp'
pug = require 'pug'
coffeescript = require 'coffee-script'
uglify = require 'uglify-js'
argv = require('yargs').argv

gapi = null
{ log } = log: -> 0
fr = (filename) -> fs.readFileSync "#{__dirname}/#{filename}", 'utf8'

argv.config = "#{__dirname}/config/example.json" unless argv.config
routes = JSON.parse fs.readFileSync argv.config, 'utf8'

travelTime = ([start, end]) ->
  return if argv.offline
  now = moment().unix()
  pr.promisify(gapi.directions)
    origin: start
    destination: end
    mode: 'driving'
    departure_time: now
  .then (response) ->
    # returns a {value:15432, text:"4 hours 17 mins"}
    t = response.json
    dir = "#{__dirname}/data/#{start}--#{end}"
    mkdirp.sync dir
    fs.writeFileAsync "#{dir}/#{now}.json", JSON.stringify t

fs.readFileAsync("#{__dirname}/api-key", 'utf8').then (contents) ->
  [ _, apiKey ] = contents.match /GOOGLE_MAPS_API_KEY=(\S+)/
  gapi = require('@google/maps').createClient key: apiKey
.then ->
  pr.each routes, travelTime
.then ->
  routeData = []

  routes.forEach ([start, end]) ->
    dir = "#{start}--#{end}"
    id = dir.replace /\W/g, ''
    log 'route:', id, start, end
    route = { start, end, id, times:[], labels:[], data:[] }
    cutoff = moment().unix() - 24 * 3600

    files = fs.readdirSync "#{__dirname}/data/#{dir}"
    files.sort()
    files.forEach (file) ->
      [ _, unixTime ] = file.match /(\d+)/
      if unixTime >= cutoff
        json = JSON.parse fr "data/#{dir}/#{file}"
        if json.routes
          t = json.routes[0].legs[0].duration_in_traffic
        else
          t = json
        log 'point:', unixTime, t
        route.times.push
          time: moment(1000*parseInt(unixTime)).format('ddd h:mma')
          duration: t.text
        route.labels.push 1000*unixTime
        route.data.push t.value

    routeData.push route

  html = pug.render fr('index.pug'),
    bootstrap: fr 'bootstrap.min.css'
    chartJs: fr 'Chart.bundle.min.js'
    momentJs: fr 'node_modules/moment/min/moment.min.js'
    routes: routeData
    myJs: uglify.minify(coffeescript.compile fr('client.coffee'), bare:true).code
  mkdirp.sync "#{__dirname}/dist"
  fs.writeFileSync "#{__dirname}/dist/index.html", html

moment = require 'moment'
pr = require 'bluebird'
fs = pr.promisifyAll require 'fs'
mkdirp = require 'mkdirp'
argv = require('yargs').argv
yaml = require 'js-yaml'
staticPage = require 'static-page'

gapi = null
{ log } = log: -> 0
fr = (filename) -> fs.readFileSync "#{__dirname}/../#{filename}", 'utf8'

argv.config = argv.config or process.env.TRIP_TRACK or 'index'
routes = yaml.safeLoad fr("config/#{argv.config}.yml")

travelTime = ([start, end]) ->
  return if argv.offline
  log "travelTime(#{start}, #{end})"
  now = moment().unix()
  pr.promisify(gapi.directions)
    origin: start
    destination: end
    mode: 'driving'
    departure_time: now
  .then (response) ->
    # returns a {value:15432, text:"4 hours 17 mins"}
    t = response.json
    dir = "#{__dirname}/../data/#{start}--#{end}"
    log 'writing google response to file'
    mkdirp.sync dir
    fs.writeFileAsync "#{dir}/#{now}.json", JSON.stringify t

fs.readFileAsync("#{__dirname}/../config/api-key", 'utf8').then (contents) ->
  log 'api key loaded'
  [ _, apiKey ] = contents.match /GOOGLE_MAPS_API_KEY=(\S+)/
  gapi = require('@google/maps').createClient key: apiKey
.then ->
  log 'querying all routes'
  pr.each routes, travelTime
.then ->
  log 'querying finished, building routes'
  routeData = []

  routes.forEach ([start, end]) ->
    dir = "#{start}--#{end}"
    id = dir.replace /\W/g, ''
    log 'route:', id, start, end
    route = { start, end, id, times:[], labels:[], data:[] }
    cutoff = moment().unix() - 24 * 3600

    files = fs.readdirSync "#{__dirname}/../data/#{dir}"
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

  fs.writeFileAsync "#{__dirname}/../src/routes.json", JSON.stringify(routeData)
.then ->
  staticPage.crawl "#{__dirname}/../node_modules/static-page/src", false
.then ->
  staticPage.dist = "/tmp"
  staticPage.crawl "#{__dirname}/../src", true
.then ->
  fs.renameSync "/tmp/index.html", "#{__dirname}/../dist/#{argv.config}.html",

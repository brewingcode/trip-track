# trip-track

Periodically query the Google Directions API for certain routes, and then
show the estimated duration over the past 24 hours as a list and a graph.

Use `cron` to do the "periodically" part.

```
# for local dev: no API fetching, but still builds .html under nodemon
npm start

# fetch from API, and build .html
npm run build
```

Use the [example config file](config/example.yml) as a starting point.

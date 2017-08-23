secondsToString = (v) ->
  m = moment.duration(v, 'seconds')
  s = ''
  if m.days() > 0
    s += m.days() + 'd '
  if m.hours() > 0
    s += m.hours() + 'h '
  if m.days() is 0
    s += m.minutes() + 'm'
  s

chartInit = (id, index) ->
  ctx = document.getElementById(id).getContext('2d')
  r = routes[index]
  myChart = new Chart ctx,
    type: 'line'
    data:
      labels: r.labels
      datasets: [ { data: r.data } ]
    options:
      responsive: true
      legend: false
      tooltips: callbacks: label: (tip) -> secondsToString tip.yLabel
      scales:
        yAxes: [ { ticks: callback: (v) -> secondsToString v } ]
        xAxes: [ {
          gridLines: offsetGridLines: false
          offset: true
          type: 'time'
          time:
            parser: 'x'
            tooltipFormat: 'ddd h:mma'
        } ]

##
# ga
# https://github.com/mickey/videojs-ga
#
# Copyright (c) 2013 Michael Bensoussan
# Licensed under the MIT license.
##

videojs.plugin 'ga', (options = {}) ->

  console.log 7

  player = @

  # this loads options from the data-setup attribute of the video tag
  dataSetupOptions = {}
  if @options()["data-setup"]
    parsedOptions = JSON.parse(@options()["data-setup"])
    dataSetupOptions = parsedOptions.ga if parsedOptions.ga

  defaultsEventsToTrack = [
    'playerLoad', 'loaded', 'percentsPlayed', 'start',
    'end', 'seek', 'play', 'pause', 'resize',
    'volumeChange', 'error', 'fullscreen'
  ]
  eventsToTrack = options.eventsToTrack || dataSetupOptions.eventsToTrack || defaultsEventsToTrack
  percentsPlayedInterval = options.percentsPlayedInterval || dataSetupOptions.percentsPlayedInterval || 10

  eventCategory = options.eventCategory || dataSetupOptions.eventCategory || 'Brightcove Player'
  # if you didn't specify a name, it will be 'guessed' from the video src after metadatas are loaded
  defaultLabel = options.eventLabel || dataSetupOptions.eventLabel

  # init a few variables
  percentsAlreadyTracked = []
  startTracked = false
  endTracked = false
  seekStart = seekEnd = 0
  seeking = false
  eventLabel = ''

  eventNames = {
    "loadedmetadata": "Video Load",
    "percent played": "Percent played",
    "start": "Media Begin",
    "seek start": "Seek start",
    "seek end": "Seek end",
    "play": "Media Play",
    "pause": "Media Pause",
    "error": "Error",
    "exit fullscreen": "Fullscreen entered",
    "enter fullscreen": "Fullscreen exited",
    "resize": "Resize",
    "volume change": "Volume Change",
    "player load": "Player Load",
    "end": "Media Complete"
  }

  getEventName = ( name ) ->
    if options.eventNames && options.eventNames[name]
      return options.eventNames[name]
    if dataSetupOptions.eventNames && dataSetupOptions.eventNames[name]
      return dataSetupOptions.eventNames[name]
    if eventNames[name]
      return eventNames[name]
    return name

  # load ga script if in iframe and tracker option is set
  if window.location.host == 'players.brightcove.net' || window.location.host == 'preview-players.brightcove.net'
    tracker = options.tracker || dataSetupOptions.tracker
    if tracker
      ((i, s, o, g, r, a, m) ->
        i["GoogleAnalyticsObject"] = r
        i[r] = i[r] or ->
          (i[r].q = i[r].q or []).push arguments

        i[r].l = 1 * new Date()

        a = s.createElement(o)
        m = s.getElementsByTagName(o)[0]

        a.async = 1
        a.src = g
        m.parentNode.insertBefore a, m
      ) window, document, "script", "//www.google-analytics.com/analytics.js", "ga"
      ga('create', tracker, 'auto')
      ga('require', 'displayfeatures');

  loaded = ->
    if defaultLabel
      eventLabel = defaultLabel
    else
      if player.mediainfo
        eventLabel = player.mediainfo.id + ' | ' + player.mediainfo.name
      else
        eventLabel = @currentSrc().split("/").slice(-1)[0].replace(/\.(\w{3,4})(\?.*)?$/i,'')

    if "loadedmetadata" in eventsToTrack
      sendbeacon( getEventName('loadedmetadata'), true )

    return

  timeupdate = ->
    currentTime = Math.round(@currentTime())
    duration = Math.round(@duration())
    percentPlayed = Math.round(currentTime/duration*100)

    for percent in [0..99] by percentsPlayedInterval
      if percentPlayed >= percent && percent not in percentsAlreadyTracked

        if "percentsPlayed" in eventsToTrack && percentPlayed != 0
          sendbeacon( getEventName('percent played'), true, percent )

        if percentPlayed > 0
          percentsAlreadyTracked.push(percent)

    if "seek" in eventsToTrack
      seekStart = seekEnd
      seekEnd = currentTime
      # if the difference between the start and the end are greater than 1 it's a seek.
      if Math.abs(seekStart - seekEnd) > 1
        seeking = true
        sendbeacon( getEventName('seek start'), false, seekStart )
        sendbeacon( getEventName('seek end'), false, seekEnd )

    return

  end = ->
    if !endTracked
      sendbeacon( 'end', true )
      endTracked = true
    return

  play = ->
    currentTime = Math.round(@currentTime())
    sendbeacon( getEventName('play'), true, currentTime )
    seeking = false
    if "start" in eventsToTrack && !startTracked
      sendbeacon( getEventName('start'), true )
      startTracked = true
    return

  pause = ->
    currentTime = Math.round(@currentTime())
    duration = Math.round(@duration())
    if currentTime != duration && !seeking
      sendbeacon( getEventName('pause'), false, currentTime )
    return

  # value between 0 (muted) and 1
  volumeChange = ->
    volume = if @muted() == true then 0 else @volume()
    sendbeacon( getEventName('volume change'), false, volume )
    return

  resize = ->
    sendbeacon( getEventName('resize') + ' - ' + @width() + "*" + @height(), true )
    return

  error = ->
    currentTime = Math.round(@currentTime())
    # XXX: Is there some informations about the error somewhere ?
    sendbeacon( getEventName('error'), true, currentTime )
    return

  fullscreen = ->
    currentTime = Math.round(@currentTime())
    if @isFullscreen?() || @isFullScreen?()
      sendbeacon( getEventName('enter fullscreen'), false, currentTime )
    else
      sendbeacon( getEventName('exit fullscreen'), false, currentTime )
    return

  sendbeacon = ( action, nonInteraction, value ) ->
    # console.log action, " ", nonInteraction, " ", value
    if window.ga
      ga 'send', 'event',
        'eventCategory' 	: eventCategory
        'eventAction'		  : action
        'eventLabel'		  : eventLabel
        'eventValue'      : value
        'nonInteraction'	: nonInteraction
    else if window._gaq
      _gaq.push(['_trackEvent', eventCategory, action, eventLabel, value, nonInteraction])
    else
      console.log("Google Analytics not detected")
    return

  if "playerLoad" in eventsToTrack
    unless self == top
      href = document.referrer + '(iframe)'
      iframe = 1
    else
      href = window.location.href
      iframe = 0
    if window.ga
      ga 'send', 'event',
        'eventCategory' 	: eventCategory
        'eventAction'		  : getEventName('player load')
        'eventLabel'		  : href
        'eventValue'      : iframe
        'nonInteraction'	: false
    else if window._gaq
      _gaq.push(['_trackEvent', eventCategory, getEventName('player load'), href, iframe, false])
    else
      console.log("Google Analytics not detected")

  @ready ->
    @on("loadedmetadata", loaded) # use loadstart?
    @on("timeupdate", timeupdate)
    @on("ended", end) if "end" in eventsToTrack
    @on("play", play) if "play" in eventsToTrack
    @on("pause", pause) if "pause" in eventsToTrack
    @on("volumechange", volumeChange) if "volumeChange" in eventsToTrack
    @on("resize", resize) if "resize" in eventsToTrack
    @on("error", error) if "error" in eventsToTrack
    @on("fullscreenchange", fullscreen) if "fullscreen" in eventsToTrack
  return

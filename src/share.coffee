class Share extends ShareUtils
  constructor: (@element, options) ->
    @el =
      head: document.getElementsByTagName('head')[0]
      body: document.getElementsByTagName('body')[0]

    @config =
      protocol: if ['http', 'https'].indexOf(window.location.href.split(':')[0]) is -1 then 'https://' else '//'
      url: window.location.href
      caption: null
      title: if content = (document.querySelector('meta[property="og:title"]') || document.querySelector('meta[name="twitter:title"]'))
        content.getAttribute('content')
      image: if content = (document.querySelector('meta[property="og:image"]') || document.querySelector('meta[name="twitter:image"]'))
        content.getAttribute('content')
      text: if content = (document.querySelector('meta[property="og:description"]') || document.querySelector('meta[name="twitter:description"]') ||  document.querySelector('meta[name="description"]'))
        content.getAttribute('content')
      else
        ''

      ui:
        flyout: 'top center'
        button_font: true
        button_color: '#333333'
        button_background: '#a29baa'
        button_icon: 'export'
        button_text: 'Share'

      networks:
        google_plus:
          enabled: true
          url: null
        twitter:
          enabled: true
          url: null
          text: null
        facebook:
          enabled: true
          url: null
          app_id: null
          title: null
          caption: null
          text: null
          image: null

    @setup(element, options)

    return @

  setup: (element, opts) ->
    ## Record all instances
    instances = document.querySelectorAll(element) # TODO: Use more efficient method.

    ## Extend config object
    @extend(@config, opts, true)

    ## Apply missing network-specific configurations
    @set_global_configuration()
    @normalize_network_configuration()

    ## Inject Icon Fontset
    @inject_icons()

    ## Inject Google's Lato Fontset (if enabled)
    @inject_fonts() if @config.ui.button_font

    ## Inject Facebook JS SDK (if Facebook is enabled)
    @inject_facebook_sdk() if @config.networks.facebook.enabled

    ## Loop through and initialize each instance
    @setup_instance(element, index) for instance, index in instances

    return


  setup_instance: (element, index) ->
    ## Get instance - (Note: Reload Element. gS/qSA doesn't support live NodeLists)
    instance = document.querySelectorAll(element)[index] # TODO: Use more efficient method.

    ## Hide instance
    @hide(instance)

    ## Add necessary classes to instance (Note: FF doesn't support adding multiple classes in a single call)
    @add_class(instance, "sharer-#{index}")

    ## Get instance - (Note: Reload Element. gS/qSA doesn't support live NodeLists)
    instance = document.querySelectorAll(element)[index] # TODO: Use more efficient method.

    ## Inject HTML and CSS
    @inject_css(instance)
    @inject_html(instance)

    ## Show instance
    @show(instance)

    label    = instance.getElementsByTagName("label")[0]
    button   = instance.getElementsByClassName("social")[0]
    networks = instance.getElementsByTagName('li')
    
    ## Add listener to activate buttons
    label.addEventListener "click", => @event_toggle(button)

    ## Add listener to activate networks and close button
    _this = @
    for network, index in networks
      network.addEventListener "click", ->
        _this.event_network(instance, @)
        _this.event_close(button)


  ##########
  # EVENTS #
  ##########


  event_toggle: (button) ->
    if @has_class(button, "active")
      @event_close(button)
    else
      @event_open(button)

  event_open: (button)  -> @add_class(button, "active")
  event_close: (button) -> @remove_class(button, "active")

  event_network: (instance, network) ->
    name = network.getAttribute("data-network")
    @hook("before", name)
    @["network_#{name}"]()
    @hook("after", name)


  ##############
  # PUBLIC API #
  ##############


  open:   -> @public("open")
  close:  -> @public("close")
  toggle: -> @public("toggle")

  public: (action) ->
    for instance, index in document.querySelectorAll(@element)
      button = instance.getElementsByClassName("social")[0]
      @["event_#{action}"](button)



  ############################
  # NETWORK-SPECIFIC METHODS #
  ############################


  network_facebook: ->
    if not window.FB then return console.error "The Facebook JS SDK hasn't loaded yet."

    FB.ui
      method:       'feed',
      name:         @config.networks.facebook.title
      link:         @config.networks.facebook.url
      picture:      @config.networks.facebook.image
      caption:      @config.networks.facebook.caption
      description:  @config.networks.facebook.description

  network_twitter: ->
    @popup("https://twitter.com/intent/tweet?text=#{@config.networks.twitter.text}&url=#{@config.networks.twitter.url}")

  network_google_plus: ->
    @popup("https://plus.google.com/share?url=#{@config.networks.google_plus.url}")


  #############
  # INJECTORS #
  #############

  # Notes
  # - Must be https:// due to CDN CORS caching issues
  # - To include the full entypo set, change URL to: https://www.sharebutton.co/fonts/entypo.css
  inject_icons: -> @inject_stylesheet("https://www.sharebutton.co/fonts/v2/entypo.min.css")
  inject_fonts:  -> @inject_stylesheet("http://fonts.googleapis.com/css?family=Lato:900&text=#{@config.ui.button_text}")

  inject_stylesheet: (url) ->
    unless @el.head.querySelector("link[href=\"#{url}\"]")
      link = document.createElement("link")
      link.setAttribute("rel", "stylesheet")
      link.setAttribute("href", url)
      @el.head.appendChild(link)
  
  inject_css: (instance) ->
    selector = ".#{instance.getAttribute('class').split(" ").join(".")}"

    unless @el.head.querySelector("meta[name='sharer#{selector}']")
      @config.selector = selector # TODO: Temporary

      css   = getStyles(@config)
      style = document.createElement("style")
      style.type = "text/css"

      # IE9 Fix
      if style.styleSheet
        style.styleSheet.cssText = css
      else
        style.appendChild document.createTextNode(css)
      
      @el.head.appendChild style

      delete @config.selector # TODO: Temporary

      meta = document.createElement("meta")
      meta.setAttribute("name", "sharer#{selector}")
      @el.head.appendChild(meta)

  inject_html: (instance) ->
    instance.innerHTML = "<label class='entypo-#{@config.ui.button_icon}'><span>#{@config.ui.button_text}</span></label><div class='social #{@config.ui.flyout}'><ul><li class='entypo-twitter' data-network='twitter'></li><li class='entypo-facebook' data-network='facebook'></li><li class='entypo-gplus' data-network='google_plus'></li></ul></div>"

  inject_facebook_sdk: ->
    if !window.FB && @config.networks.facebook.app_id && !@el.body.querySelector('#fb-root')
      script      = document.createElement("script")
      script.text = "window.fbAsyncInit=function(){FB.init({appId:'#{@config.networks.facebook.app_id}',status:true,xfbml:true})};(function(e,t,n){var r,i=e.getElementsByTagName(t)[0];if(e.getElementById(n)){return}r=e.createElement(t);r.id=n;r.src='#{@config.protocol}connect.facebook.net/en_US/all.js';i.parentNode.insertBefore(r,i)})(document,'script','facebook-jssdk')"

      @el.body.innerHTML += "<div id='fb-root'></div>"
      @el.body.appendChild(script)


  ###########
  # HELPERS #
  ###########

  hook: (type, network) ->
    fn = @config.networks[network][type]

    if typeof(fn) is "function"
      opts = fn.call(@config.networks[network])
      unless opts is undefined
        opts = @normalize_filter_config_updates(opts)

        @extend(@config.networks[network], opts, true)
        @normalize_network_configuration()

    return

  set_global_configuration: ->
    ## Update network-specific configuration with global configurations
    for network, options of @config.networks
      for option of options
        #if @config.networks[network][option] is null
        unless @config.networks[network][option]?
          @config.networks[network][option] = @config[option]

  normalize_network_configuration: ->
    ## Encode Twitter text for URL
    unless @is_encoded(@config.networks.twitter.text)
      @config.networks.twitter.text = encodeURIComponent(@config.networks.twitter.text)

    ## Typecast Facebook app_id to a String
    if typeof(@config.networks.facebook.app_id) is 'integer'
      @config.networks.facebook.app_id = @config.networks.facebook.app_id.toString()

  normalize_filter_config_updates: (opts) ->
    if @config.networks.facebook.app_id isnt opts.app_id
      console.warn "You are unable to change the Facebook app_id after the button has been initialized. Please update your Facebook filters accordingly."
      delete opts.app_id

    return opts

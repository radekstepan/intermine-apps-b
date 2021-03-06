{ _, $ } = require '../deps'

InterMineWidget = require './InterMineWidget'
ChartView       = require './views/ChartView'
type            = require '../utils/type'

class ChartWidget extends InterMineWidget

    # Default widget options that will be merged with user's values.
    widgetOptions:
        'title':       yes
        'description': yes
        'matchCb':     no
        'resultsCb':   no
        'listCb':      no

    formOptions: {}

    # Spec for a successful and correct JSON response.
    spec:
        response:
            "chartType":           type.isString
            "description":         type.isString
            "error":               type.isNull
            "list":                type.isString
            "notAnalysed":         type.isInteger
            "pathQuery":           type.isString
            "requestedAt":         type.isString
            "results":             type.isArray
            "seriesLabels":        type.isString
            "seriesValues":        type.isString
            "statusCode":          type.isHTTPSuccess
            "title":               type.isString
            "type":                type.isString
            "wasSuccessful":       type.isBoolean
            "filters":             type.isString
            "filterLabel":         type.isString
            "filterSelectedValue": type.isString
            "simplePathQuery":     type.isString
            "domainLabel":         type.isString
            "rangeLabel":          type.isString

    # Set the params on us and set Google load callback.
    #
    # 0. `imjs`:          intermine.Service
    # 1. `service`:       [http://aragorn:8080/flymine/service/](http://aragorn:8080/flymine/service/)
    # 2. `token`:         token for accessing user's lists
    # 3. `id`:            widgetId
    # 4. `bagName`:       myBag
    # 5. `el`:            #target
    # 6. `widgetOptions`: { "title": true/false, "description": true/false, "matchCb": function(id, type) {}, "resultsCb": function(pq) {}, "listCb": function(pq) {} }
    constructor: (@imjs, @service, @token, @id, @bagName, @el, widgetOptions = {}) ->
        # Merge `widgetOptions`.
        @widgetOptions = _.extend {}, @widgetOptions, widgetOptions

        @log = []

        super
        
        do @render

    # Visualize the widget.
    render: =>
        # *Loading* overlay.
        timeout = window.setTimeout((=> $(@el).append @loading = $ do require('../templates/loading')), 400)

        # Removes all of the **View**'s delegated events if there is one already.
        @view?.undelegateEvents()

        # Payload.
        data =
            'widget': @id
            'list':   @bagName
            'token':  @token

        # An extra form filter?
        for key, value of @formOptions
            # This should be handled better...
            if key not in [ 'errorCorrection', 'pValue' ] then data['filter'] = value

        @log.push 'Sending data payload ' + JSON.stringify data

        # Get JSON response by calling the service.
        $.ajax
            url:      "#{@service}list/chart"
            dataType: "jsonp"
            data:     data
            
            success: (response) =>
                @log.push 'Received a response ' + JSON.stringify response

                # No need for a loading overlay.
                window.clearTimeout timeout
                @loading?.remove()

                # We have response, validate.
                @validateType response, @spec.response
                # We have results.
                if response.wasSuccessful
                    # Actual name of the widget.
                    @name = response.title

                    @log.push 'Creating new ChartView'

                    # New **View**.
                    @view = new ChartView(
                        "widget":   @
                        "el":       @el
                        "response": response
                        "form":
                            "options": @formOptions
                        "options":  @widgetOptions
                    )
            
            error: (request, status, error) =>
                clearTimeout timeout ; @error { 'text': "#{@service}list/chart" }, 'AJAXTransport'

module.exports = ChartWidget
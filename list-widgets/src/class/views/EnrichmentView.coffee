{ $, _, Backbone } = require '../../deps'

Models                         = require '../models/CoreModel'
EnrichmentRowView              = require './EnrichmentRowView'
EnrichmentPopoverView          = require './EnrichmentPopoverView'
EnrichmentPopulationView       = require './EnrichmentPopulationView'
EnrichmentLengthCorrectionView = require './EnrichmentLengthCorrectionView'
exporter                       = require '../../utils/exporter'

class EnrichmentView extends Backbone.View

    events:
        # View button.
        "click div.actions a.view":      "viewAction"
        # Download button.
        "click div.actions a.export":    "exportAction"
        # Change the form dropdown.
        "change div.form select":        "formAction"
        # Select all rows.
        "click div.content input.check": "selectAllAction"

    initialize: (o) ->
        @[k] = v for k, v of o

        # New **Collection**.
        @collection = new Models.EnrichmentResults()
        @collection.bind('change', @renderToolbar) # Re-render toolbar on change.

        do @render

    render: ->
        # Render the widget template.
        $(@el).html require('../../templates/enrichment/enrichment')
            "title":       if @options.title then @response.title else ""
            "description": if @options.description then @response.description else ""
            "notAnalysed": @response.notAnalysed
            "type": @response.type

        # Form options.
        $(@el).find("div.form").html require('../../templates/enrichment/enrichment.form')
            "options":          @form.options
            "pValues":          @form.pValues
            "errorCorrections": @form.errorCorrections

        # Extra attributes (DataSets etc.)?
        if @response.filterLabel?
            $(@el).find('div.form form').append require('../../templates/extra')
                "label":    @response.filterLabel
                "possible": @response.filters.split(',') # Is a String unfortunately.
                "selected": @response.filterSelectedValue

        # Background population lists.
        new EnrichmentPopulationView
            'el': $(@el).find('div.form form')
            'lists': @lists
            'current': @response.current_population
            'loggedIn': @response.is_logged
            'widget': @

        # Do we have extra attributes?
        if @response.extraAttribute
            extraAttribute = JSON.parse @response.extraAttribute

            # Enrichment gene length correction.
            if extraAttribute.gene_length
                opts = _.extend {}, extraAttribute.gene_length,
                    'el': $(@el).find('div.form form')
                    'widget': @
                    'cb': @options.resultsCb                    

                new EnrichmentLengthCorrectionView opts

        # Custom bg population CSS.
        if @response.current_list?
            $(@el).addClass 'customBackgroundPopulation'
        else
            $(@el).removeClass 'customBackgroundPopulation'

        # Results?
        if @response.results.length > 0 and !@response.message?
            # Render the actions toolbar, we have results.
            @renderToolbar()

            @renderTable()
        else
            # Render no results
            $(@el).find("div.content").html $ require('../../templates/noresults')
                'text': @response.message or 'No enrichment found.'

        @widget.fireEvent { 'class': 'EnrichmentView', 'event': 'rendered' }
        
        # initialise the shadow effect if there is overflow
        @initWrapperScrollEffect()

        @

    # Render the actions toolbar based on how many collection model rows are selected.
    renderToolbar: =>
        $(@el).find("div.actions").html(
            do require('../../templates/actions')
        )

    # Render the table of results using Document Fragment to prevent browser reflows.
    renderTable: =>
        # Render the table.
        $(@el).find("div.content").html(
            require('../../templates/enrichment/enrichment.table') "label": @response.label
        )

        # Table rows **Models** and a subsequent **Collection**.
        table = $(@el).find("div.content table")
        for i in [0...@response.results.length] then do (i) =>
            # Form the data.
            data = @response.results[i]
            # External link through simple append.
            if @response.externalLink then data.externalLink = @response.externalLink + data.identifier
            
            # New **Model**.
            row = new Models.EnrichmentRow data, @widget
            @collection.add row

        # Render row **Views**.
        @renderTableBody table

        # How tall should the table be? Whole height - header.
        height = $(@el).height() - $(@el).find('div.header').height() - $(@el).find('div.content table thead').height()
        $(@el).find("div.content table tbody").css 'height', "#{height}px"

        # Width of the table
        width = @el.find('div.content table tbody').prop('scrollWidth')
        $(@el).find("div.content table tbody").css 'width', "#{width}px"
        $(@el).find("div.content table thead").css 'width', "#{width}px"

        # Fix the `div.head` elements width.
        table.find('thead th').each (i, th) =>
            $(@el).find("div.content div.head div:eq(#{i})").width $(th).width()

    # Render `<tbody>` from a @collection (use to achieve single re-flow of row Views).
    renderTableBody: (table) =>
        # Create a Document Fragment for the content that follows.
        fragment = document.createDocumentFragment()

        # Table rows.
        for row in @collection.models
            # Render.
            fragment.appendChild new EnrichmentRowView(
                "model":     row
                "type":      @response.type
                "callbacks": { "matchCb": @options.matchCb, "resultsCb": @options.resultsCb, "listCb": @options.listCb }
                "response":  @response
                "widget":    @widget
            ).el

        # Append the fragment to trigger the browser reflow.
        table.find('tbody').html fragment
    # On form select option change, set the new options and re-render.
    formAction: (e) =>
        @widget.formOptions[$(e.target).attr("name")] = $(e.target[e.target.selectedIndex]).attr("value")
        @widget.render()

    # (De-)select all.
    selectAllAction: =>
        @collection.toggleSelected()
        @renderToolbar()
        @renderTableBody $(@el).find("div.content table")

    # Export selected rows into a file.
    exportAction: (e) =>
        # Select all if none selected (@kkara #164).
        selected = @collection.selected()
        if !selected.length then selected = @collection.models

        # Get column identifiers to constrain on.
        rowIdentifiers = []
        for model in selected
            rowIdentifiers.push model.get 'identifier'

        # PathQuery for matches values.
        pq = JSON.parse @response['pathQueryForMatches']
        pq.where.push
            "path":   @response.pathConstraint
            "op":     "ONE OF"
            "values": rowIdentifiers

        # Get the actual data.
        @widget.queryRows pq, (response) =>

            # Assume the first column is the table column, while second is the matches object identifier (Gene).
            # Form 'publication -> genes' object.
            dict = {}
            for object in response
                if not dict[object[0]]? then dict[object[0]] = []
                dict[object[0]].push object[1]

            # Create a tab delimited string.
            result = []
            for model in selected
                result.push [ model.get('description'), model.get('p-value') ].join("\t") + "\t" + dict[model.get('identifier')].join(',') + "\t" + model.get('identifier')

            if result.length
                try
                    new exporter.Exporter result.join("\n"), "#{@widget.bagName} #{@widget.id}.tsv"
                catch TypeError
                    new exporter.PlainExporter $(e.target), result.join("\n")

    # Selecting table rows and clicking on **View** should create an EnrichmentMatches collection of all matches ids.
    viewAction: =>
        # Select all if none selected (@kkara #164).
        selected = @collection.selected()
        if !selected.length then selected = @collection.models

        # Get all the matches in selected rows.
        descriptions = [] ; rowIdentifiers = []
        for model in selected
            descriptions.push model.get 'description' ; rowIdentifiers.push model.get 'identifier'

        if rowIdentifiers.length # Can be empty.
            # Remove any previous matches modal window.
            @popoverView?.remove()

            # Append a new modal window with matches.
            $(@el).find('div.actions').after (@popoverView = new EnrichmentPopoverView(
                "identifiers": rowIdentifiers
                "description": descriptions.join(', ')
                "style":       "width:300px"
                "matchCb":     @options.matchCb
                "resultsCb":   @options.resultsCb
                "listCb":      @options.listCb
                "response":    @response
                "widget":      @widget
            )).el

    #Scroll event 
    wrapperScrollEvent: (target) =>
        # get the target element
        el = target && target.currentTarget || target

        # capture left div used for shadow effect
        el_left = $(el).find('div.left')[0]

        # capture right div used for shadow effect
        el_right = $(el).find('div.right')[0]

        # get the scroll width of the wrapper
        el_scroll_width = el.scrollWidth

        # get the width of wrapper (visible width)
        el_width = el.getBoundingClientRect().width

        # get the wrapper scroll amount
        el_scroll_left = el.scrollLeft

        if el_scroll_left + el_width < el_scroll_width then el_right.style.opacity = '1'
        else el_right.style.opacity = '0'

        if el_scroll_left > 0 then el_left.style.opacity = '1'
        else el_left.style.opacity = '0'

    initWrapperScrollEffect: =>
        # get the current wrapper div
        target = $(@el).get(0)
        target = $(target).find('.content .wrapper').get(0)

        # add scroll event listner to the wrapper
        $(target).scroll(@wrapperScrollEvent) if target?

        # set the scroll effect
        @wrapperScrollEvent(target) if target?
        

    # Select background population list.
    selectBackgroundList: (list, save=false) =>
        # Pass in `null` to go default. Could be better than string match as we could have a list called Default.
        if list is 'Default' then list = ''

        # Change the list.
        @widget.formOptions['current_population'] = list

        # Remember this list as a background population.
        @widget.formOptions['remember_population'] = save
        
        # Re-render.
        @widget.render()

module.exports = EnrichmentView
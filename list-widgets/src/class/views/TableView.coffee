{ $, Backbone } = require '../../deps'

Models           = require '../models/CoreModel'
TableRowView     = require './TableRowView'
TablePopoverView = require './TablePopoverView'
exporter         = require '../../utils/exporter'

class TableView extends Backbone.View

    events:
        "click div.actions a.view":      "viewAction"
        "click div.actions a.export":    "exportAction"
        "click div.content input.check": "selectAllAction"

    initialize: (o) ->
        @[k] = v for k, v of o
        # New **Collection**.
        @collection = new Models.TableResults()
        @collection.bind('change', @renderToolbar) # Re-render toolbar on change.

        do @render

    render: ->
        # Render the widget template.
        $(@el).html require('../../templates/table/table')
            "title":       if @options.title then @response.title else ""
            "description": if @options.description then @response.description else ""
            "notAnalysed": @response.notAnalysed
            "type": @response.type

        # Results?
        if @response.results.length > 0
            # Render the toolbar & table, we have results.
            @renderToolbar()
            @renderTable()
        else
            # Render no results
            $(@el).find("div.content").html require('../../templates/noresults')
                'text': "No \"#{@response.title}\" with your list."

        @widget.fireEvent { 'class': 'TableView', 'event': 'rendered' }

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
            require('../../templates/table/table.table') "columns": @response.columns.split(',')
        )

        # Table rows **Models** and a subsequent **Collection**.
        table = $(@el).find("div.content table")
        for i in [0...@response.results.length] then do (i) =>            
            # New **Model**.
            row = new Models.TableRow @response.results[i], @widget
            @collection.add row

        # Render row **Views**.
        @renderTableBody table

        # How tall should the table be? Whole height - header - faux header.
        height = $(@el).height() - $(@el).find('div.header').height() - $(@el).find('div.content div.head').height() - $(@el).find('div.content table thead').height()
        $(@el).find("div.content table tbody").css 'height', "#{height}px"

        # Width of the table
        width = @el.find('div.content table tbody').prop('scrollWidth')
        $(@el).find("div.content table tbody").css 'width', "#{width}px"
        

        # Determine the width of the faux head element.
        $(@el).find("div.content div.head").css "width", $(@el).find("div.content table").width() + "px"

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
            fragment.appendChild new TableRowView(
                "model":     row
                "response":  @response
                "matchCb":   @options.matchCb
                "resultsCb": @options.resultsCb
                "listCb":    @options.listCb
                "widget":    @widget
            ).el

        # Append the fragment to trigger the browser reflow.
        table.find('tbody').html fragment

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
        
        # Create a tab delimited string of the table as it is.
        result = [ @response.columns.replace(/,/g, "\t") ]
        for model in selected
            result.push model.get('descriptions').join("\t") + "\t" + model.get('matches')

        if result.length
            try
                new exporter.Exporter result.join("\n"), "#{@widget.bagName} #{@widget.id}.tsv"
            catch TypeError
                new exporter.PlainExporter $(e.target), result.join("\n")

    # Selecting table rows and clicking on **View** should create an TableMatches collection of all matches ids.
    viewAction: =>
        # Select all if none selected (@kkara #164).
        selected = @collection.selected()
        if !selected.length then selected = @collection.models

        # Get all the identifiers for selected rows.
        descriptions = [] ; rowIdentifiers = []
        for model in selected
            # Grab the first (only?) description.
            descriptions.push model.get('descriptions')[0] ; rowIdentifiers.push model.get 'identifier'

        if rowIdentifiers.length # Can be empty.
            # Remove any previous matches modal window.
            @popoverView?.remove()

            # Append a new modal window with matches.
            $(@el).find('div.actions').after (@popoverView = new TablePopoverView(
                "identifiers":    rowIdentifiers
                "description":    descriptions.join(', ')
                "matchCb":        @options.matchCb
                "resultsCb":      @options.resultsCb
                "listCb":         @options.listCb
                "pathQuery":      @response.pathQuery
                "pathConstraint": @response.pathConstraint
                "widget":         @widget
                "type":           @response.type
                "style":          'width:300px'
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

        if el_scroll_left + el_width < el_scroll_width  then el_right.style.opacity = '1' 
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

module.exports = TableView
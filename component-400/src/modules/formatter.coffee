_ = require 'object' # keys, values, length, isEmpty, merge

# How do we display "an object"?
module.exports =
    
    # Show a "primary" symbol recognizable by humans.
    'primary': (model) ->
        # Go for a symbol first.
        for key in [ 'symbol', 'primaryIdentifier', 'secondIdentifier' ]
            if val = model.object.summary[key]
                return val

        # Try to return the longest string.
        val = [ 0, 'NA' ]
        for k, v of model.object.summary
            if (len = v.replace(/\W/, '').length) > val[0]
                val = [ len, v ]

        # Hopefully we have something here by now.
        val[1]
    
    # A row for CSV output.
    'csv': ({ provided, object }, columns=yes) ->
        cols = [].concat([ 'provided', 'type' ], _.keys(object.summary))
        rows = [].concat([ provided, object.type ], _.values(object.summary))
        if columns then [ cols, rows ] else rows
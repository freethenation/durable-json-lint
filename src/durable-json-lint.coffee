esprima = if typeof module == 'undefined' then window.esprima else require('esprima')
falafel = if typeof module == 'undefined' then window.falafel else require('free-falafel')
jsonLint=(src)->
    wrappedSrc = "(function(){return "+src+";})();"
    try
        ast = esprima.parse(wrappedSrc, {range:true, tolerant:true, loc:true, raw:true})
    catch err
        err.status = "crash"
        return {errors:[err],json:null}
    #^(?:-?(?=[1-9]|0(?!\d))\d+(\.\d+)?([eE][+-]?\d+)?|true|false|null|"([^"\\]|(?:\\["\\/bfnrt])|(?:\\u[][0-9a-f]{4}))*")$
    literalRegex = /^(?:-?(?=[1-9]|0(?!\d))\d+(\.\d+)?([eE][+-]?\d+)?|true|false|null|"([^"\\]|(?:\\["\\\/bfnrt])|(?:\\u[\][0-9a-f]{4}))*")$/
    commaFixRegex = /,(?=\s*\}\s*$)/
    errors = []
    createError=(node, status, desc)->
        errors.push({            
            lineNumber: node.loc.start.line,
            column: node.loc.start.column,
            description:desc
            status:status
        })
        if node.loc.start.line == 1 
            errors[errors.length-1].column -= 19

    rootExpr = null
    breadthFirstFunc=(node)->
        if rootExpr == null
            node.valid = true
        if rootExpr == null && node.type == 'ReturnStatement'
            rootExpr = node.argument
        if node.valid? then return #if a parent set the nodes validity... skip
        if !node.parent.valid #if out parent is not valid we are not valid
            node.valid = false
            return
        switch node.type
            when "Literal"
                if literalRegex.test(node.raw)
                    node.valid=true
                else
                    node.valid=false
                    switch node.raw[0]
                        when "'" then createError(node, "correctable", "Json strings must use double quotes")
                        when "\"" then createError(node, "correctable", "Invalid Json string")
                        else createError(node, "correctable", "Invalid Json number")
                    node.correct = JSON.stringify(node.value)
            when "ObjectExpression"
                node.valid=true
                node.props={}
            when "ArrayExpression"
                node.valid=true
            when "Property"
                node.valid=true
                key = node.key
                if key.type=="Identifier"
                    createError(key, "correctable", "Keys must be double quoted in Json. Did you mean \"#{key.name}\"?")
                    key.valid=false
                    key.correct = JSON.stringify(key.name)
                else if key.type=="Literal" and typeof(key.value) == "number"
                    createError(key, "correctable", "Keys must be double quoted in Json. Did you mean \"#{key.raw}\"?")
                    key.valid=false
                    key.correct = JSON.stringify(key.raw)
            when "Identifier"
                node.valid = false
                createError(node, "guessable", "An identifier is not a valid Json element. Did you mean \"#{node.name}\"?")
                node.correct = JSON.stringify(node.name)
            when "CallExpression"
                node.valid=false
                createError(node, "fail", "You can not make function calls in Json. Do you think I am a fool?")
            else
                node.valid=false
                createError(node, "fail", "A \"#{node.type}\" is an invalid Json element.")

    depthFirstFunc=(node)->
        #test for duplicate keys
        if node.type == "Property"
            key = node.key
            if node.parent.props[key.correct||key.raw]?
                node.valid=false    
                node.correct = ""
                createError(node, "guessable", "Duplicate key in Json object. The key #{key.correct||key.raw} is already present.")
            else node.parent.props[key.correct||key.raw] = node
        #fix trailing comma issue in objects
        if node.type == "ObjectExpression"
            node.update(node.source().replace(commaFixRegex,""))
        # basic results
        if node.valid then return #its good do nothing
        else if node.correct? #correct it if we can
            node.update(node.correct)
        else
            node.update("null")
        return

    # do the processing         
    res = falafel(wrappedSrc, {ast:ast}, depthFirstFunc, breadthFirstFunc).toString()
    res = res.substring(19,res.length-6)
    return {json:res, errors:errors}
#export
if typeof module == 'undefined' then window.durableJsonLint = jsonLint else module.exports = jsonLint
exports = this || {}

fs = require 'fs'

DEBUGGING = false

debug = (args...) ->
    if DEBUGGING
        console.log.apply(console, args)

class Macro
    constructor: (@transform) ->
    runMacro: (expr, env) -> env.do @transform expr, env
    toString: () -> "[Macro #{ @transform }]"

class BuiltIn extends Macro
    runMacro: (expr, env) -> @transform expr, env

bootstrappings = "(begin #{ fs.readFileSync('js/interpreting/builtins.scheem', 'utf-8') })"

envCounter = 0
class Env
    constructor: (globals, @outer) ->
        @id = envCounter++
        @bindings = {}
        @set(k, v) for k, v of globals
        @stack = []
        @level = if (@outer) then @outer.level + 1 else 0
    availableBindings: () ->
        availables = if (@outer?) then @outer.availableBindings() else {}
        availables[name] = val for name, val of @bindings
        availables
    do: (expr) ->
        @stack.push expr
        try
            ret = scheem(expr, this)
        catch e
            trace = []
            i = 0
            last = null
            while exp = @stack.pop()
                current = show(exp)
                line = "#{i++} >> #{ current }"
                if last
                    line = line.replace(last, "$#{i - 2}")
                last = current
                trace.push line
            throw e + (if (i > 0) then "\n" else "") + trace.join("\n")
        @stack.pop()
        ret
    getFullStack: () ->
        history = if @outer? then @outer.getFullStack() else []
        history.concat(@stack)
    set: (k, v) -> @bindings[k] = v
    get: (k) ->
        if @bindings.hasOwnProperty(k)
            @bindings[k]
        else if @outer?
            @outer.get(k)
        else
            throw "Unbound identifier: #{ k }"
    update: (k, v) ->
        if @bindings[k]?
            @bindings[k] = v
        else
            @outer?.update(k, v)

class Lambda
    constructor: (@names, @body, @scope) ->
        if @names?
            @length = @names.length
        else
            throw "No parameter list for lambda"
        unless @body?
            throw "No body for lambda"
    curry: (env, givens) -> new CurriedLambda(@names, @body, env, givens)
    getArgs: (expr, env) -> (expr[1..])
    toString: () -> "[Lambda (#{ @names.join(", ") }) #{ show(@body) }]"
    runLambda: (expr, env) ->
        args = @getArgs(expr, @scope)
        values = (env.do(a) for a in args)
        inner = new Env {}, @scope
        if @argsAreSufficient(args)
            return @apply(inner, values)
        else
            return @curry(inner, values)
    argsAreSufficient: (args) -> args.length >= @length
    call: (args...) -> @apply(@scope, args)
    apply: (env, args) ->
        for val, i in args
            env.set(@names[i], val) if @names[i]?
        return env.do @body

class CurriedLambda extends Lambda
    constructor: (@names, @body, @scope, @givens) ->
        @length = @names.length - @givens.length
    curry: (env, more) -> new CurriedLambda(@names, @body, env, @givens.concat(more))
    toString: () -> "[CurriedLambda with: #{ @givens.join(", ") } #{ show(@body) }]"
    apply: (env, args) ->
        vals = @givens.concat(args)
        return super(env, vals)

class NativeLambda extends Lambda
    constructor: (@scope, @f) ->
        @length = @f.length
    curry: (env, givens) ->
        outer = @f
        curried = (args...) ->
            args = givens.concat(args)
            return outer.apply(env, args)
        ret = new NativeLambda(new Env({}, @scope), curried)
        ret.length = @length - givens.length
        return ret
    apply: (env, args) ->
        @f.apply(env, args)
    toString: () -> "[NativeLambda #{ @f }]"

## Default interpretation environment

class BuiltIns extends Env
    id: "Built-Ins"
    level: 0
    constructor: ->
        @stack = []
        @loadNativeBindings()
        @do getParser().parse(bootstrappings)
    loadNativeBindings: () ->
        fn = (f) => new NativeLambda @, f
        @bindings =
            # CONSTANTS
            '#t': true
            '#f': false
            'nil': null
            'stdout': process.stdout
            'stdin':  process.stdin
            # MACROS
            'quote': new BuiltIn (expr)      -> expr[1]
            'define':new BuiltIn (expr, env) ->
                unless expr[2]?
                    throw "No body for define"
                unless expr[1] and expr[1].length
                    throw "Invalid initial parameter to define #{ show(expr[1]) }"
                if (typeof expr[1] is 'string')
                    env.set expr[1], env.do expr[2]
                else
                    newexp = ['define', expr[1][0], ['lambda', expr[1][1..], expr[2]]]
                    env.do newexp
            'define-syntax': new BuiltIn (expr, outer) ->
                name = expr[1][0]
                transform = expr[2]
                vars = expr[1][1..]
                m = new Macro (unprocessed, env) ->
                    inner = new Env {}, outer
                    for v, i in vars
                        if v is '...'
                            inner.set(vars[i - 1], unprocessed[i ..])
                        else
                            inner.set(v, unprocessed[i + 1])
                    inner.do transform
                outer.set name, m
            'match': new Macro (expr, env) ->
                val = expr[1]
                patterns = expr[2]
                trans = ["if"]
                currentif = trans
                for pair in patterns
                    if (currentif.length is 3) and (pair[0][0] isnt 'else')
                        newif = ['if']
                        currentif.push newif
                        currentif = newif

                    if (typeof pair[0] is 'number')
                        currentif.push ['=', pair[0], val]
                        currentif.push pair[1]
                    else if pair[0][0] is 'list'
                        bindings = pair[0][1..]
                        cond = ['list?', val]
                        minLen = (b for b in bindings when (b isnt "...")).length
                        hasSplat = (b for b in bindings when (b is "...")).length
                        cond = ['and', cond, [(if hasSplat then '<=' else '='), minLen, ['len', val]]]
                        currentif.push cond
                        body = ['let']
                        letbindings = []
                        for b, i in bindings
                            if b is "..."
                                letbindings[(i - 1)][1] = ['get-from', (i - 1), val]
                            else
                                letbindings.push( [b, ['get-item', i, val]] )
                        body.push letbindings
                        body.push pair[1]
                        currentif.push body
                    else if pair[0][0] is 'cons'
                        bindings = pair[0][1..]
                        cond = ['and', ['list?', val], ['<', 0, ['len', val]]]
                        currentif.push cond
                        body = ['let']
                        body.push [[bindings[0], ['car', val]], [bindings[1], ['cdr', val]]]
                        body.push pair[1]
                        currentif.push body
                    else if pair[0][0] is 'quote'
                        currentif.push ['=', pair[0], val]
                        currentif.push pair[1]
                    else if pair[0] is 'else'
                        cond = '#t'
                        body = pair[1]
                        if currentif.length < 3
                            currentif.push cond
                        currentif.push body
                    else
                        throw "Unsupported pattern: #{ pair[0] }"
                if currentif.length isnt 4
                    currentif.push "FailedPatternMatchError"
                return trans

            'set!':  new BuiltIn (expr, env) -> env.update expr[1], env.do expr[2]
            'begin': new BuiltIn (expr, env) ->
                result = env.do(e) for e in expr[1..]
                return result
            'lambda': new BuiltIn (expr, env) ->
                argNames = expr[1]
                body = expr[2]
                return new Lambda(argNames, body, new Env({}, env))
            'let': new Macro (expr, outer)   ->
                [["lambda", (b[0] for b in expr[1]), expr[2]]].concat(b[1] for b in expr[1])
            'if':  new Macro (expr, env)     -> expr[if (env.do(expr[1])) then 2 else 3]

            # NORMAL FUNCS
            # Ones I can't work out how do do in scheem yet...
            'eval':     fn (exp)   -> @do exp
            'inspect':  fn (x)     -> show(x)
            'call':     fn (o, name, args) -> o[name].apply(o, args)
            'die':      fn (err)  -> throw err
            'get-item': fn (i, xs)   -> xs[i]
            'get-from': fn (i, xs)   -> xs[i..]
            'list':     fn (args...) -> args.slice()
            'list?':    fn (xs)      -> xs instanceof Array
            '+':        fn (a, b) -> a + b
            '%':        fn (a, b) -> a % b
            '-':        fn (a, b) -> a - b
            '/':        fn (a, b) -> a / b
            '*':        fn (a, b) -> a * b
            '=':        fn (a, b) -> a is b
            '<':        fn (a, b) -> a < b
            '>':        fn (a, b) -> a > b
            '<=':       fn (a, b) -> a <= b
            '>=':       fn (a, b) -> a >= b
            'regex':    fn (patt, flags) -> new RegExp(patt, flags)
            '.':     fn (f, g) ->
                composed = fn (args...) -> f.apply(this, [g.apply(this, args)])
                composed.length = g.length
                composed
            # Ones that could be in scheem, but are fundamental.
            'cons':     fn (x, xs) -> [x].concat(xs)
            'conc':     fn (xs, ys)-> xs.concat(ys)
            # Ones where a native function is better for performance
            'len':      fn (xs)    -> xs?.length
            'empty?':   fn (xs)    -> xs instanceof Array && xs.length is 0
            'print':    fn (a)   -> @get("stdout").write(show(a))
            'println':  fn (a) -> @get("stdout").write(a + "\n")
            #'range': fn (m, n) -> [m .. n]

## Interpreting infrastructure:
#

show = (expr) ->
    if (typeof expr is 'number')
        return "" + expr
    if (typeof expr is 'string')
        if expr.match(/\s/)
            return "\"#{expr}\""
        else
            return expr
    if (expr instanceof Lambda)
        return "" + expr
    if (expr instanceof Macro)
        return "" + expr
    if (expr instanceof Function)
        return "" + expr
    else
        "(#{ (show(e) for e in expr).join(' ') })"

scheem = (expr, env) ->
    unless expr?
        throw "No expression to evaluate"
    debug "Evaluating", expr
    if (typeof expr is 'number')
        return expr
    if (typeof expr is 'string')
        return env.get(expr)
    head = expr[0]
    unless head?
        return null
    op = env.do head
    if (op instanceof Macro)
        return op.runMacro(expr, env)
    if (op instanceof Lambda)
        return op.runLambda(expr, env)
    else
        console.log "Error running: ", expr
        if op
            throw "Expected a procedure for #{ head } - got #{ op }"
        else
            throw "No procedure named: #{ head }"

Parser = null

exports.runScheem = (text, vars) ->
    vars ?= {}
    Parser ?= require("../parsing/parser.js")
    try
        ast = Parser.parse text
    catch error
        throw "Error parsing #{ text }: #{ error}"
    try
        res = exports.evalScheem(ast, vars)
    catch e
        throw "Error running: #{ e }"
    return res

getParser = () ->
    Parser ?= require("../parsing/parser.js")
    return Parser

exports.getInterpreter = () ->
    globals = new Env({}, new BuiltIns())
    return {
        suggest: (word) ->
            return (name for name, _ of globals.availableBindings() when (name.match("^" + word)))
        run: (text) ->
            debug "INTERPRETING:", text
            if (text)
                try
                    ast = getParser().parse text
                catch error
                    console.log "Error parsing #{ text }: #{ error}"
                    return
                try
                    res = globals.do ast
                catch e
                    console.log "Error running: #{ e }"
                    return
                return res
    }

exports.evalScheem = (expr, env) ->
    globals = new Env(env, new BuiltIns())
    scheem(expr, globals)


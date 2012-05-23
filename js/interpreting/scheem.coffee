exports = this || {}

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

class Env
    constructor: (globals, @outer) ->
        @bindings = {}
        @set(k, v) for k, v of globals
        @stack = []
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
        if (@bindings[k]?)
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
        @length = @names.length
    curry: (env, givens) -> new CurriedLambda(@names, @body, env, givens)
    getArgs: (expr, env) -> (expr[1..])
    toString: () -> "[Lambda (#{ @names.join(", ") }) #{ show(@body) }]"
    runLambda: (expr, env) ->
        args = @getArgs(expr, env)
        inner = new Env {}, env
        values = (inner.do(a) for a in args)
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
    toString: () -> "[CurriedLambda #{ show(@body) }]"
    apply: (env, args) ->
        vals = @givens.concat(args)
        return super(env, vals)

class SLambda extends Lambda
    constructor: (@f) ->
        @length = @f.length
    curry: (env, givens) ->
        outer = @f
        curried = (args...) ->
            args = givens.concat(args)
            return outer.apply(env, args)
        ret = new SLambda(curried)
        ret.length = @length - givens.length
        return ret
    apply: (env, args) ->
        @f.apply(env, args)
    toString: () -> "[SLambda #{ @f }]"

## Default interpretation environment

class BuiltIns extends Env
    constructor: ->
    getFullStack: -> []
    bindings:
        # MACROS
        '#t': true,
        '#f': false,
        'quote': new BuiltIn (expr)      -> expr[1]
        'define':new BuiltIn (expr, env) ->
            if (typeof expr[1] is 'string')
                env.set expr[1], env.do expr[2]
            else
                newexp = ['define', expr[1][0], ['lambda', expr[1][1..], expr[2]]]
                env.do newexp
        'define-syntax': new  BuiltIn (expr, env) ->
            name = expr[1][0]
            transform = expr[2]
            vars = expr[1][1..]
            m = new Macro (unprocessed, env) ->
                inner = new Env {}, env
                for v, i in vars
                    if v is '...'
                        inner.update(vars[i - 1], unprocessed[i ..])
                    else
                        inner.set(v, unprocessed[i + 1])

                tr = inner.do transform
                debug "POST_TR", tr
                tr
            env.set name, m
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
                    hasSpat = (b for b in bindings when (b is "...")).length
                    cond = ['and', cond, [(if hasSpat then '<=' else '='), minLen, ['len', val]]]
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
                    letbindings = []
                    letbindings.push [bindings[0], ['car', val]]
                    letbindings.push [bindings[1], ['cdr', val]]
                    body.push letbindings
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
            tr = [["lambda", (b[0] for b in expr[1]), expr[2]]].concat(b[1] for b in expr[1])
            #console.log tr
            tr
        'if':  new Macro (expr, env)   -> expr[if (env.do(expr[1])) then 2 else 3]
        'macro': new BuiltIn (expr, env) -> # superceded by define-syntax, which is much nicer...
            body = expr[2]
            f = (totransform, ctx) ->
                inner = new Env {}, ctx
                inner.set expr[1][0], totransform[1..]
                inner.do body
            new Macro f

        # NORMAL FUNCS
        'stdout': process.stdout
        'stdin':  process.stdin
        'eval':  new SLambda (exp)   -> @do exp
        'cons':  new SLambda (x, xs) -> [x].concat(xs)
        'car':   new SLambda (xs)    -> xs[0]
        'cdr':   new SLambda (xs)    -> xs.slice(1)
        'conc':  new SLambda (xs, ys) -> xs.concat(ys)
        'push':  new SLambda (xs, x) -> xs.concat([x])
        'len':   new SLambda (xs)    -> xs.length
        'empty?': new SLambda (xs)   -> xs instanceof Array && xs.length is 0
        'get-item': new SLambda (i, xs) -> xs[i]
        'get-from': new SLambda (i, xs) -> xs[i..]
        'list':  new SLambda (args...) -> args.slice()
        'list?': new SLambda (xs)   -> xs instanceof Array
        '+':     new SLambda (a, b) -> a + b
        '%':     new SLambda (a, b) -> a % b
        '-':     new SLambda (a, b) -> a - b
        '/':     new SLambda (a, b) -> a / b
        '*':     new SLambda (a, b) -> a * b
        '=':     new SLambda (a, b) -> a is b
        '<':     new SLambda (a, b) -> a < b
        '>':     new SLambda (a, b) -> a > b
        '<=':    new SLambda (a, b) -> a <= b
        '>=':    new SLambda (a, b) -> a >= b
        'even?': new SLambda (a) -> a % 2 is 0
        'not':   new SLambda (a) -> a is false
        'and':   new SLambda (a, b) -> (a is true) and (b is true)
        'print': new SLambda (a)   -> @get("stdout").write(show(a))
        'println': new SLambda (a) -> @get("stdout").write(a + "\n")
        'range': new SLambda (m, n) -> [m .. n]
        'map':   new SLambda (f, xs) ->
            (f.apply(this, [x]) for x in xs)
        'filter': new SLambda (f, xs) -> (x for x in xs when (f.apply(this, [x]) is true))
        'fold':  new SLambda (f, xs) ->
            memo = xs[0]
            memo = f.apply(this, [memo, x]) for x in xs[1..]
            memo
        '.':     new SLambda (f, g) ->
            composed = new SLambda (args...) -> f.call(g.apply(this, args))
            composed.length = g.length
            composed

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
    debug "Evaluating", expr
    if (typeof expr is 'number')
        return expr
    if (typeof expr is 'string')
        return env.get(expr)
    head = expr[0]
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

exports.getInterpreter = () ->
    Parser ?= require("../parsing/parser.js")
    globals = new Env({}, new BuiltIns())
    (text) ->
        console.log "INTERPRETING", "" + text + ""
        if (text)
            try
                ast = Parser.parse text
            catch error
                console.log "Error parsing #{ text }: #{ error}"
                return
            try
                res = globals.do ast
            catch e
                console.log "Error running: #{ e }"
                return
            return res

exports.evalScheem = (expr, env) ->
    globals = new Env(env, new BuiltIns())
    scheem(expr, globals)


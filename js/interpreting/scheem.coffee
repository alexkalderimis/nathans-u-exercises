exports = this || {}

BASE_PREDICATE2 = (f) -> (expr, env) ->
    if (f(scheem(expr[1], env), scheem(expr[2], env))) then '#t' else '#f'

BASE_PREDICATE1 = (f) -> (expr, env) ->
    if (f(scheem(expr[1], env))) then '#t' else '#f'

class Env
    constructor: (settings) -> @[k] = v for k, v of settings

    # Built-Ins
    'quote': (expr)      -> expr[1]
    'cons':  (expr, env) -> [scheem(expr[1], env)].concat(scheem(expr[2], env))
    'car':   (expr, env) -> scheem(expr[1], env)[0]
    'cdr':   (expr, env) -> scheem(expr[1], env).slice(1)
    '+':     (expr, env) -> scheem(expr[1], env) + scheem(expr[2], env)
    '%':     (expr, env) -> scheem(expr[1], env) % scheem(expr[2], env)
    '-':     (expr, env) -> scheem(expr[1], env) - scheem(expr[2], env)
    '/':     (expr, env) -> scheem(expr[1], env) / scheem(expr[2], env)
    '*':     (expr, env) -> scheem(expr[1], env) * scheem(expr[2], env)
    'define': (expr, env) -> env[expr[1]] = scheem(expr[2], env)
    'set!':  (expr, env) ->  env[expr[1]] = scheem(expr[2], env)
    '=':     BASE_PREDICATE2 (a, b) -> a is b
    '<':     BASE_PREDICATE2 (a, b) -> a < b
    '>':     BASE_PREDICATE2 (a, b) -> a > b
    '<=':    BASE_PREDICATE2 (a, b) -> a <= b
    '>=':    BASE_PREDICATE2 (a, b) -> a >= b
    'even?': BASE_PREDICATE1 (a) -> a % 2 is 0
    'if':    (expr, env) ->
        scheem(expr[if (scheem(expr[1], env) is '#t') then 2 else 3], env)
    'begin': (expr, env) -> result = scheem(e, env) for e in expr[1..]; result

scheem = (expr, env) ->

    if (typeof expr is 'number')
        return expr
    if (typeof expr is 'string')
        return env[expr]

    head = expr[0]
    op = env[head]
    if (op && typeof op is 'function')
        ret = op(expr, env)
    else
        if op
            throw "Expected a procedure - got #{ op }"
        else
            throw "No procedure named: #{ head }"
    return ret

Parser = null

exports.runScheem = (text) ->
    Parser ?= require("../parsing/parser.js")
    ast = Parser.parse text
    exports.evalScheem(ast, {})

exports.evalScheem = (expr, env) ->
    globals = new Env(env)
    scheem(expr, globals)


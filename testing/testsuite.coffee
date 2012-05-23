exports = this

colors = require "colorize"

class Suite
    constructor: (@name, @setup, @tests) ->
    runSuite: () ->
        console.log "Running suite #{ @name }"
        console.time "TEST-SUITE #{ @name }"
        @passed = 0
        @failed = 0
        @runTest n, t for n, t of @tests
        console.log "Complete. Passed #{ @passed } of #{ @passed + @failed }"
        colors.console.log "#red[SOME TESTS FAILED]" if (@failed > 0)
        console.timeEnd "TEST-SUITE #{ @name }"
        console.log ""
    runTest: (name, t) ->
        context = {}
        if @setup? and @setup.before?
            @setup.before.apply(context)
        try
            process.stdout.write "Running test: #{ name }"
            t.apply(context)
            process.stdout.write colors.ansify " #green[passed]\n"
            @passed++
        catch e
            colors.console.log " #red[FAILED! (#{ e })]"
            @failed++
        if @setup? and @setup.after?
            @setup.after.apply(context)

exports.runSuite = (n, o, ts) ->
    s = new Suite(n, o, ts)
    s.runSuite()

exports["Suite"] = Suite




S = require("./scheem")
rl = require 'readline'
util = require "util"
cli = rl.createInterface process.stdin, process.stdout, null

cli.setPrompt "scheem >"

interpreter = S.getInterpreter()

cli.on 'close', ->
    util.puts('goodbye!')
    process.exit(0)

cli.on "line", (line) ->
    if line.trim()
        console.log interpreter( line )
    cli.prompt()

cli.prompt()

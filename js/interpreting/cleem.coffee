S = require("./scheem")
rl = require 'readline'
util = require "util"
cli = rl.createInterface process.stdin, process.stdout, null

cli.setPrompt "scheem > "

interpreter = S.getInterpreter()

cli.on 'close', ->
    util.puts('goodbye!')
    process.exit(0)

currentText = ""

cli.on "line", (line) ->
    currentText += " " + line
    lefts = (c for c in currentText when (c is "(")).length
    rights = (c for c in currentText when (c is ")")).length
    if (rights isnt lefts)
        cli.setPrompt "scheem .."
    else if currentText.trim()
        console.log interpreter( currentText )
        currentText = ""
        cli.setPrompt "scheem > "
    cli.prompt()

cli.prompt()

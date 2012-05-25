S = require("./scheem")
rl = require 'readline'
util = require "util"
LAST_WORD = /[^\s()'"]+$/

interpreter = S.getInterpreter()
currentText = ""

completer = (line) ->
    text = currentText + line
    lefts = (c for c in text when (c is "(")).length
    rights = (c for c in text when (c is ")")).length
    if (lefts > rights)
        process.stdout.write "\n#{ lefts - rights } open brackets"
    if m = LAST_WORD.exec line
        word = m[0]
        trimmed = line.replace(word, "")
        return [
            interpreter.suggest( word ).map((s) -> trimmed + s),
            line
        ]
    cli.prompt()
    return [[], line]

cli = rl.createInterface process.stdin, process.stdout, completer

cli.setPrompt "scheem > "

cli.on 'close', ->
    util.puts('goodbye!')
    process.exit(0)

cli.on "line", (line) ->
    currentText += " " + line
    lefts = (c for c in currentText when (c is "(")).length
    rights = (c for c in currentText when (c is ")")).length
    if (rights isnt lefts)
        cli.setPrompt "scheem .."
    else if currentText.trim()
        process.stdout.write interpreter.run( currentText ) + "\n"
        currentText = ""
        cli.setPrompt "scheem > "
    cli.prompt()

cli.prompt()

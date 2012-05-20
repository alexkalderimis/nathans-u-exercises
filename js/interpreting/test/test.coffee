Scheem = require('../scheem')

exports = this

exports.setVar = (test) ->
    test.deepEqual Scheem.runScheem("""(begin (define x 20) (* x 5))"""), 100

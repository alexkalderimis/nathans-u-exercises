var PEG = require('pegjs');
var assert = require('assert');
var fs = require('fs');

// Read file contents
var data = fs.readFileSync('js/parsing/scheem.grammar', 'utf-8');
// Create my parser
var parse = PEG.buildParser(data, {trackLineAndColumn: true}).parse;

// Do a test
assert.equal(
    parse('x'),
    'x',
    'Single atom'
);

assert.deepEqual( 
    parse('(a b c)'), 
    ['a', 'b', 'c'],
    'Flat list'
);

assert.deepEqual( 
    parse('(a b c 1 2 3)'), 
    ['a', 'b', 'c', 1, 2, 3],
    'Flat list with numbers'
);


assert.deepEqual(
    parse('(+ x (f a b))'),
    ['+', 'x', ['f', 'a', 'b']],
    'Single level nesting'
);

assert.deepEqual(
    parse('(+ (- x (g y)) (f a b))'),
    ['+', ['-', 'x', ['g', 'y']], ['f', 'a', 'b']],
    'Multi level nesting'
);

assert.deepEqual(
    parse('(+ x (   f a b))'),
    ['+', 'x', ['f', 'a', 'b']],
    'Multiple whitespaces 1'
);

assert.deepEqual(
    parse('(+ x   (  f a b))'),
    ['+', 'x', ['f', 'a', 'b']],
    'Multiple whitespaces 2'
);

assert.deepEqual(
    parse("(+ x  \n\t\t(  f a b)\n)\t"),
    ['+', 'x', ['f', 'a', 'b']],
    'Multiple whitespaces 3 - special spaces'
);

var fib = fs.readFileSync('js/parsing/fib.scheem', 'utf-8');

assert.deepEqual(
    parse(fib),
    ['define', ['fib', 'n'], 
        ['define', ['ff', 'm', 'c', 'n-1', 'n-2'],
          ['define', 'next', ['+', 'n-1', 'n-2']],
          ['if', ['=', 'm', 'c'], 'next', ['ff', 'm', ['+', 1, 'c'], 'next', 'n-1']]],
        ['if', ['<', 'n', 2], 'n', ['ff', 'n', 2, 1, 0]]],

    'Linear recursive fib' 
);

assert.deepEqual(
    parse("'x"),
    ["quote", "x"],
    "Quoting atom"
);

assert.deepEqual(
    parse("'(a b c)"),
    ["quote", ["a", "b", "c"]],
    "Quote list"
);

assert.deepEqual(
    parse("(a 'b '(c d))"),
    ["a", ["quote", "b"], ["quote", ["c", "d"]]],
    "Quote combo"
);




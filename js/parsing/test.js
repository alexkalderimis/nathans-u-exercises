var PEG = require('pegjs');
var assert = require('assert');
var fs = require('fs');

// Read file contents
var data = fs.readFileSync('js/parsing/scheem.grammar', 'utf-8');
// Create my parser
var parse = PEG.buildParser(data).parse;

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
    parse("(+ x  \n\t\t(  f a b))"),
    ['+', 'x', ['f', 'a', 'b']],
    'Multiple whitespaces 3 - special spaces'
);

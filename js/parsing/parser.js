var PEG = require('pegjs');
var assert = require('assert');
var fs = require('fs');

// Read file contents
var grammar = fs.readFileSync('js/parsing/scheem.grammar', 'utf-8');
// Create my parser
exports.parse = PEG.buildParser(grammar, {trackLineAndColumn: true}).parse;

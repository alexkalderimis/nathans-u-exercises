// Generated by CoffeeScript 1.3.1
(function() {
  var Scheem, exports;

  Scheem = require('../scheem');

  exports = this;

  exports.setVar = function(test) {
    return test.deepEqual(Scheem.runScheem("(begin (define x 20) (* x 5))"), 100);
  };

}).call(this);

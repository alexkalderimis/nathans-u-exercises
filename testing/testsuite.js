// Generated by CoffeeScript 1.3.1
(function() {
  var Suite, colors, exports;

  exports = this;

  colors = require("colorize");

  Suite = (function() {

    Suite.name = 'Suite';

    function Suite(name, setup, tests) {
      this.name = name;
      this.setup = setup;
      this.tests = tests;
    }

    Suite.prototype.runSuite = function() {
      var n, t, _ref;
      console.log("Running suite " + this.name);
      console.time("TEST-SUITE " + this.name);
      this.passed = 0;
      this.failed = 0;
      _ref = this.tests;
      for (n in _ref) {
        t = _ref[n];
        this.runTest(n, t);
      }
      console.log("Complete. Passed " + this.passed + " of " + (this.passed + this.failed));
      if (this.failed > 0) {
        colors.console.log("#red[SOME TESTS FAILED]");
      }
      console.timeEnd("TEST-SUITE " + this.name);
      return console.log("");
    };

    Suite.prototype.runTest = function(name, t) {
      var context;
      context = {};
      if ((this.setup != null) && (this.setup.before != null)) {
        this.setup.before.apply(context);
      }
      try {
        process.stdout.write("Running test: " + name);
        t.apply(context);
        process.stdout.write(colors.ansify(" #green[passed]\n"));
        this.passed++;
      } catch (e) {
        colors.console.log(" #red[FAILED! (" + e + ")]");
        this.failed++;
      }
      if ((this.setup != null) && (this.setup.after != null)) {
        return this.setup.after.apply(context);
      }
    };

    return Suite;

  })();

  exports.runSuite = function(n, o, ts) {
    var s;
    s = new Suite(n, o, ts);
    return s.runSuite();
  };

  exports["Suite"] = Suite;

}).call(this);

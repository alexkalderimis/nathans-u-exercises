// Generated by CoffeeScript 1.3.1
(function() {
  var BASE_PREDICATE1, BASE_PREDICATE2, Env, Parser, exports, scheem;

  exports = this || {};

  BASE_PREDICATE2 = function(f) {
    return function(expr, env) {
      if (f(scheem(expr[1], env), scheem(expr[2], env))) {
        return '#t';
      } else {
        return '#f';
      }
    };
  };

  BASE_PREDICATE1 = function(f) {
    return function(expr, env) {
      if (f(scheem(expr[1], env))) {
        return '#t';
      } else {
        return '#f';
      }
    };
  };

  Env = (function() {

    Env.name = 'Env';

    function Env(settings) {
      var k, v;
      for (k in settings) {
        v = settings[k];
        this[k] = v;
      }
    }

    Env.prototype['quote'] = function(expr) {
      return expr[1];
    };

    Env.prototype['cons'] = function(expr, env) {
      return [scheem(expr[1], env)].concat(scheem(expr[2], env));
    };

    Env.prototype['car'] = function(expr, env) {
      return scheem(expr[1], env)[0];
    };

    Env.prototype['cdr'] = function(expr, env) {
      return scheem(expr[1], env).slice(1);
    };

    Env.prototype['+'] = function(expr, env) {
      return scheem(expr[1], env) + scheem(expr[2], env);
    };

    Env.prototype['%'] = function(expr, env) {
      return scheem(expr[1], env) % scheem(expr[2], env);
    };

    Env.prototype['-'] = function(expr, env) {
      return scheem(expr[1], env) - scheem(expr[2], env);
    };

    Env.prototype['/'] = function(expr, env) {
      return scheem(expr[1], env) / scheem(expr[2], env);
    };

    Env.prototype['*'] = function(expr, env) {
      return scheem(expr[1], env) * scheem(expr[2], env);
    };

    Env.prototype['define'] = function(expr, env) {
      return env[expr[1]] = scheem(expr[2], env);
    };

    Env.prototype['set!'] = function(expr, env) {
      return env[expr[1]] = scheem(expr[2], env);
    };

    Env.prototype['='] = BASE_PREDICATE2(function(a, b) {
      return a === b;
    });

    Env.prototype['<'] = BASE_PREDICATE2(function(a, b) {
      return a < b;
    });

    Env.prototype['>'] = BASE_PREDICATE2(function(a, b) {
      return a > b;
    });

    Env.prototype['<='] = BASE_PREDICATE2(function(a, b) {
      return a <= b;
    });

    Env.prototype['>='] = BASE_PREDICATE2(function(a, b) {
      return a >= b;
    });

    Env.prototype['even?'] = BASE_PREDICATE1(function(a) {
      return a % 2 === 0;
    });

    Env.prototype['if'] = function(expr, env) {
      return scheem(expr[scheem(expr[1], env) === '#t' ? 2 : 3], env);
    };

    Env.prototype['begin'] = function(expr, env) {
      var e, result, _i, _len, _ref;
      _ref = expr.slice(1);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        e = _ref[_i];
        result = scheem(e, env);
      }
      return result;
    };

    return Env;

  })();

  scheem = function(expr, env) {
    var head, op, ret;
    if (typeof expr === 'number') {
      return expr;
    }
    if (typeof expr === 'string') {
      return env[expr];
    }
    head = expr[0];
    op = env[head];
    if (op && typeof op === 'function') {
      ret = op(expr, env);
    } else {
      if (op) {
        throw "Expected a procedure - got " + op;
      } else {
        throw "No procedure named: " + head;
      }
    }
    return ret;
  };

  Parser = null;

  exports.runScheem = function(text) {
    var ast;
    if (Parser == null) {
      Parser = require("../parsing/parser.js");
    }
    ast = Parser.parse(text);
    return exports.evalScheem(ast, {});
  };

  exports.evalScheem = function(expr, env) {
    var globals;
    globals = new Env(env);
    return scheem(expr, globals);
  };

}).call(this);

(function() {
  var esprima, falafel, jsonLint;

  esprima = typeof module === 'undefined' ? window.esprima : require('esprima');

  falafel = typeof module === 'undefined' ? window.falafel : require('free-falafel');

  jsonLint = function(src) {
    var ast, breadthFirstFunc, createError, depthFirstFunc, errors, literalRegex, res, rootExpr, wrappedSrc;
    wrappedSrc = "(function(){return " + src + ";})();";
    try {
      ast = esprima.parse(wrappedSrc, {
        range: true,
        tolerant: true,
        loc: true,
        raw: true
      });
    } catch (err) {
      return {
        errors: [err]
      };
    }
    literalRegex = /^(?:-?(?=[1-9]|0(?!\d))\d+(\.\d+)?([eE][+-]?\d+)?|true|false|null|"([^"\\]|(?:\\["\\\/bfnrt])|(?:\\u[\][0-9a-f]{4}))*")$/;
    errors = [];
    createError = function(node, desc) {
      return errors.push({
        lineNumber: node.loc.start.line,
        column: node.loc.start.column,
        description: desc
      });
    };
    rootExpr = null;
    breadthFirstFunc = function(node) {
      var key;
      if (rootExpr === null) {
        node.valid = true;
      }
      if (rootExpr === null && node.type === 'ReturnStatement') {
        rootExpr = node.argument;
      }
      if (node.valid != null) {
        return;
      }
      if (!node.parent.valid) {
        node.valid = false;
        return;
      }
      switch (node.type) {
        case "Literal":
          if (literalRegex.test(node.raw)) {
            return node.valid = true;
          } else {
            node.valid = false;
            switch (node.raw[0]) {
              case "'":
                createError(node, "Json strings must use double quotes");
                break;
              case "\"":
                createError(node, "Invalid Json string");
                break;
              default:
                createError(node, "Invalid Json number");
            }
            return node.correct = JSON.stringify(node.value);
          }
          break;
        case "ObjectExpression":
        case "ArrayExpression":
          return node.valid = true;
        case "Property":
          node.valid = true;
          key = node.key;
          if (key.type === "Identifier") {
            createError(key, "Keys must be double quoted in Json. Did you mean \"" + key.name + "\"?");
            key.valid = false;
            return key.correct = JSON.stringify(key.name);
          } else if (key.type === "Literal" && typeof key.value === "number") {
            createError(key, "Keys must be double quoted in Json. Did you mean \"" + key.raw + "\"?");
            key.valid = false;
            return key.correct = JSON.stringify(key.raw);
          }
          break;
        case "Identifier":
          node.valid = false;
          createError(node, "An identifier is not a valid Json element. Did you mean \"" + node.name + "\"?");
          return node.correct = JSON.stringify(node.name);
        case "CallExpression":
          node.valid = false;
          return createError(node, "You can not make function calls in Json. Do you think I am a fool?");
        default:
          node.valid = false;
          return createError(node, "A \"" + node.type + "\" is an invalid Json element.");
      }
    };
    depthFirstFunc = function(node) {
      if (node.valid) {
        return;
      } else if (node.correct != null) {
        node.update(node.correct);
      } else {
        node.update("null");
      }
    };
    res = falafel(wrappedSrc, {
      ast: ast
    }, depthFirstFunc, breadthFirstFunc).toString();
    res = res.substring(19, res.length - 6);
    return {
      json: res,
      errors: errors
    };
  };

  if (typeof module === 'undefined') {
    window.betterJsonLint = jsonLint;
  } else {
    module.exports = jsonLint;
  }

}).call(this);

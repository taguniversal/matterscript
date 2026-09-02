(function() {
  function registerLanguage() {
    if (typeof hljs === 'undefined') return;

    // Register grammar if not already registered
    if (!hljs.getLanguage('matterscript')) {
      hljs.registerLanguage('matterscript', function(hljs) {
        return {
          name: 'MatterScript Invocation Language',
          aliases: ['matterscript', 'matterscript-il', 'ms-ipl', 'ms'],
          contains: [
            hljs.C_LINE_COMMENT_MODE,
            { className: 'number', begin: '\\b[0-9]+\\b' },
            { className: 'variable', begin: '\\$[A-Za-z_][A-Za-z0-9_]*' },
            { className: 'keyword', begin: '\\bgenerate\\b' },
            { className: 'keyword', begin: '\\b(inputs|output|const)\\b(?=\\s*:)' },
            { className: 'title.function.invoke', begin: '\\b(clamp|avg)\\b(?=\\s*\\()' },
            { className: 'title.class', begin: '\\b[A-Za-z_][A-Za-z0-9_]*\\b(?=\\s*\\[)' },
            { className: 'title.function', begin: '\\b[A-Za-z_][A-Za-z0-9_]*\\b(?=\\s*\\()' },
            { className: 'symbol', begin: '\\b[A-Za-z_][A-Za-z0-9_]*\\b(?=\\s*<)' },
            { className: 'operator', begin: '[+\\-*/]' },
            { className: 'punctuation', begin: '[{}\\[\\]():,]' }
          ]
        };
      });
    }

    // Force highlight on target code blocks
    var selector = 'pre code.language-matterscript, pre code.language-matterscript-il, pre code.language-ms-ipl, pre code.language-ms';
    document.querySelectorAll(selector).forEach(function(block) {
      if (typeof hljs.highlightBlock === 'function') {
        hljs.highlightBlock(block);
      } else if (typeof hljs.highlightElement === 'function') {
        hljs.highlightElement(block);
      }
    });
  }

  // Intercept console.warn to suppress the initial mdBook missing language warning
  var originalWarn = console.warn;
  console.warn = function() {
    if (arguments[0] && typeof arguments[0] === 'string' && arguments[0].indexOf("Could not find the language 'matterscript'") !== -1) {
      return;
    }
    originalWarn.apply(console, arguments);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', registerLanguage);
  } else {
    registerLanguage();
  }
})();
'use strict';

module.exports = {
  conditions: [''],
  name: 'Catch_Return',
  rules: ['catch ( CatchParameter ) Block_Return'],
  handlers: ['$$ = new (require(\'./ast/TryStatement\').CatchNode)($3, $5, { loc: this._$, yy })'],
  subRules: [require('./Block_Return'), require('./CatchParameter')]
};
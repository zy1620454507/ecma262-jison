module.exports = {
  conditions: [''],
  name: 'TryStatement_Return',
  rules: [
    'try Block_Return Catch_Return',
    'try Block_Return Finally_Return',
    'try Block_Return Catch_Return Finally_Return',
  ],
  handlers: [
    '$$ = new (require(\'./ast/TryStatement\').TryStatementNode)($2, $3, null)',
    '$$ = new (require(\'./ast/TryStatement\').TryStatementNode)($2, null, $3)',
    '$$ = new (require(\'./ast/TryStatement\').TryStatementNode)($2, $3, $4)',
  ],
  subRules: [
    require('./Block_Return'),
    require('./Catch_Return'),
    require('./Finally_Return'),
  ],
};

const BaseNode = require('./Base');

function IterationStatementNode(type, test, body, ...args) {
  BaseNode.call(this, Object.assign({}, { type }, ...args));
  this.test = test;
  this.body = body;
}

function WhileStatementNode(test, body, ...args) {
  IterationStatementNode.call(this, 'WhileStatement', test, body, ...args);
}

function DoWhileStatementNode(test, body, ...args) {
  IterationStatementNode.call(this, 'DoWhileStatement', test, body, ...args);
}

function ForStatementNode(init, test, update, body, ...args) {
  IterationStatementNode.call(this, 'ForStatement', test, body, ...args);
  this.init = init;
  this.update = update;
}

function ForInStatementNode(left, right, body, ...args) {
  BaseNode.call(this, Object.assign({}, { type: 'ForInStatement' }, ...args));
  this.left = left;
  this.right = right;
  this.body = body;
}

function ForOfStatementNode(left, right, body, ...args) {
  BaseNode.call(this, Object.assign({}, { type: 'ForOfStatement' }, ...args));
  this.left = left;
  this.right = right;
  this.body = body;
}

exports.WhileStatementNode = WhileStatementNode;

exports.DoWhileStatementNode = DoWhileStatementNode;

exports.ForStatementNode = ForStatementNode;

exports.ForInStatementNode = ForInStatementNode;

exports.ForOfStatementNode = ForOfStatementNode;

%{
  const SINGLE_ESCAPE_CHARACTERS = ['\'', '"', '\\', 'b', 'f', 'r', 't', 'v' ];

  const KEYWORD = [
    'break', 'do', 'in', 'typeof', 'case', 'else',
    'instanceof', 'var', 'catch', 'export', 'new', 'void', 'class', 'extends', 'return',
    'while', 'const', 'finally', 'super', 'with', 'continue', 'for', 'switch', 'yield', 'debugger',
    'function','this','default','if','throw','delete','import','try',
  ];

  // TODO: 遇到非Unicode continue的都pop state

  const TAB    = '\u0009';
  const VT     = '\u000B';
  const FF     = '\u000C';
  const SP     = '\u0020';
  const NBSP   = '\u00A0';
  const ZWNJ   = '\u200C';
  const ZWJ    = '\u200D';
  const ZWNBSP = '\uFEFF';

  const LF   = '\u000A';
  const CR   = '\u000D';
  const LS   = '\u2028';
  const PS   = '\u2029';

  function isWhiteSpace(ch) {
    return (
      ch === TAB ||
      ch === VT ||
      ch === FF ||
      ch === SP ||
      ch === NBSP ||
      ch === ZWNJ ||
      ch === ZWJ ||
      ch === ZWNBSP
    );
  }

  function isDecimalDigit(ch) {
    return /[0-9]/.test(ch);
  }

  function parseKeyword(keyword, alias) {
    {
      let res = '';
      switch(this.topState()) {
        case 'single_string_start':
          res = 'SingleStringCharacter';
          break;
        case 'double_string_start':
          res = 'DoubleStringCharacter';
          break;
        case 'identifier_start':
          res = 'UnicodeIDContinue';
          break;
        default:
          res = alias || keyword;
          break;
      };

      // look behind { 和 function
      let i = this.matches.index + this.match.length;
      const input = this.matches.input;

      // 跳过空白字符
      while(i < input.length && isWhiteSpace(input[i])) { i++; }

      // throw 后面的{ 应该是表达式
      // throw 后面的function应该是表达式
      // return 后面的{ 应该是表达式
      // return 后面的function应该是表达式
      if (this.match === 'throw' || this.match === 'return') {
        if (/^{/.test(input.substring(i))) {
          this.begin('block_start');
        }
        if (/^function/.test(input.substring(i))) {
          this.begin('function_start');
        }
      }
      return res;
    }
  }

  function parseOperator(operator, alias) {
    let i = this.matches.index + this.match.length;
    const input = this.matches.input;

    while(i < input.length && isWhiteSpace(input[i])) { i++; }
    let res = '';

    switch(this.topState()) {
      case 'single_string_start':
        res = 'SingleStringCharacter';
        break;
      case 'double_string_start':
        res = 'DoubleStringCharacter';
        break;
      case 'identifier_start':
        this.popState();
        res = alias || operator;
        break;
      case 'decimal_digit_start':
        this.popState();
        res = alias || operator;
        break;
      case 'decimal_digit_dot_start':
        this.popState();
        this.popState();
        res = alias || operator;
        break;
      default:
        res = alias || operator;
        break;
    };

    // TODO: 具体情况具体分析
    // case : 后面的{ 应该是语句块而不是表达式的开头
    // } 后面的{是语句块开头？
    // ) 后面的{是语句块开头?
    if (/^function/.test(input.substring(i))) {
      this.begin('function_start');
    } else if (this.match === ':') {
      if (/^{/.test(input.substring(i))) {
        if (this.topState() === 'case_start') {
          this.popState();
        } else {
          this.begin('block_start');
        }
      }
    } else if (this.match === ')') {
      ;
    } else if (this.match === '}') {
      ;
    } else if (/^{/.test(input.substring(i))) {
      this.begin('block_start');
    }
    if (res) { return res; }
  }
%}

%lex

%s  identifier_start identifier_start_unicode decimal_digit_start single_string_start double_string_start single_escape_string double_escape_string new_target decimal_digit_dot_start function_start block_start case_start

%%

'true' %{
  return parseKeyword.call(this, 'true', 'BooleanLiteral');
%}

'false' %{
  return parseKeyword.call(this, 'false', 'BooleanLiteral');
%}

'null' %{
  return parseKeyword.call(this, 'null', 'NullLiteral');
%}

'let' %{
  return parseKeyword.call(this, 'let', 'LetOrConst');
%}

'for' %{
  return parseKeyword.call(this, 'for');
%}

'of' %{
  return parseKeyword.call(this, 'of');
%}

'const' %{
  return parseKeyword.call(this, 'const', 'LetOrConst');
%}

<function_start>'function' %{
  this.popState();
  return parseKeyword.call(this, 'function');
%}

'function' %{
  return parseKeyword.call(this, 'function', 'FUNCTION');
%}

'super' %{
  return parseKeyword.call(this, 'super');
%}

'switch' %{
  return parseKeyword.call(this, 'switch');
%}

'case' %{
  this.begin('case_start');
  return parseKeyword.call(this, 'case');
%}

'default' %{
  this.begin('case_start');
  return parseKeyword.call(this, 'default');
%}

'new'(?=\s*[.]\s*'target') %{
  this.begin('new_target');
  return 'new';
%}

<new_target>'.' %{
  return '.';
%}

<new_target>target %{
  this.popState();
  return 'target';
%}

'new' %{
  return parseKeyword.call(this, 'new');
%}

'var' %{
  return parseKeyword.call(this, 'var');
%}

'in' %{
  return parseKeyword.call(this, 'in');
%}

'instanceof' %{
  return parseKeyword.call(this, 'instanceof', 'RelationalOperator');
%}

'this' %{
  return parseKeyword.call(this, 'this');
%}

'...' %{
  return parseKeyword.call(this, '...');
%}

'delete' %{
  return parseKeyword.call(this, 'delete', 'UnaryOperator');
%}

'void' %{
  return parseKeyword.call(this, 'void', 'UnaryOperator');
%}

'typeof' %{
  return parseKeyword.call(this, 'typeof', 'UnaryOperator');
%}

'if' %{
  return parseKeyword.call(this, 'if');
%}

'else' %{
  return parseKeyword.call(this, 'else');
%}

'do' %{
  return parseKeyword.call(this, 'do');
%}

'while' %{
  return parseKeyword.call(this, 'while');
%}

'continue'[u0009|\u0020]*[\u000A] %{
  console.log('continue with line terminator');
  return parseKeyword.call(this, 'continue', 'CONTINUE_LF');
%}

'continue' %{
  return parseKeyword.call(this, 'continue');
%}

'break'[u0009|\u0020]*[\u000A] %{
  console.log('break with line terminator');
  return parseKeyword.call(this, 'break', 'BREAK_LF');
%}

'break' %{
  return parseKeyword.call(this, 'break');
%}

'throw'[u0009|\u0020]*[\u000A] %{
  console.log('throw with line terminator');
  return parseKeyword.call(this, 'throw', 'THROW_LF');
%}

'throw' %{
  return parseKeyword.call(this, 'throw');
%}

'with' %{
  return parseKeyword.call(this, 'with');
%}

'return' %{
  return parseKeyword.call(this, 'return');
%}

'debugger' %{
  return parseKeyword.call(this, 'debugger');
%}

'try' %{
  return parseKeyword.call(this, 'try');
%}

'catch' %{
  return parseKeyword.call(this, 'catch');
%}

'finally' %{
  return parseKeyword.call(this, 'finally');
%}

<single_string_start>'$' return 'SingleStringCharacter';
<single_string_start>[_] return 'SingleStringCharacter';
<double_string_start>'$' return 'DoubleStringCharacter';
<double_string_start>[_] return 'DoubleStringCharacter';

'$' %{
  this.begin('identifier_start');
  return '$';
%}

[_] %{
  this.begin('identifier_start');
  return '_';
%}

<single_string_start>(.) %{
  if (this.match === '\u0009' || this.match === '\u000A') {
    throw new Error('Syntax error');
  } else if (this.match === '\\') {
    this.begin('single_escape_string');
    return 'EscapeSequenceStart';
  } else if (this.match === '\'') {
    this.popState();
    return 'SingleQuoteEnd';
  }
  return 'SingleStringCharacter';
%}

<single_escape_string>[u|U] %{
  this.begin('identifier_start_unicode');
  return 'UnicodeEscapeSequenceStart';
%}

<single_escape_string>(.) %{
  if (SINGLE_ESCAPE_CHARACTERS.indexOf(this.match) !== -1) {
    this.popState();
    return 'SingleEscapeCharacter';
  } else {
    this.popState();
    return 'NonEscapeCharacter';
  }
%}

'\''
%{
  this.begin('single_string_start');
  return 'SingleQuoteStart';
%}

<double_escape_string>[u|U] %{
  this.begin('identifier_start_unicode');
  return 'UnicodeEscapeSequenceStart';
%}

<double_escape_string>(.) %{
  if (SINGLE_ESCAPE_CHARACTERS.indexOf(this.match) !== -1) {
    this.popState();
    return 'SingleEscapeCharacter';
  } else {
    this.popState();
    return 'NonEscapeCharacter';
  }
%}

<double_string_start>(.) %{
  if (this.match === '\u0009' || this.match === '\u000A') {
    throw new Error('Syntax error');
  } else if (this.match === '\\') {
    this.begin('double_escape_string');
    return 'EscapeSequenceStart';
  } else if (this.match === '"') {
    this.popState();
    return 'DoubleQuoteEnd';
  }
  return 'DoubleStringCharacter';
%}

'"'
%{
  this.begin('double_string_start');
  return 'DoubleQuoteStart';
%}

'[' %{
  return parseOperator.call(this, this.match);
%}

']' %{
  return parseOperator.call(this, this.match);
%}

<block_start>'{' %{
  this.popState();
  return parseOperator.call(this, this.match, 'BLOCK_START');
%}

'{' %{
  return parseOperator.call(this, this.match);
%}

'}' %{
  return parseOperator.call(this, this.match);
%}

':' %{
  return parseOperator.call(this, this.match);
%}
<identifier_start>([$_0-9A-Z_a-z\xAA\xB5\xB7\xBA\xC0-\xD6\xD8-\xF6\xF8-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0300-\u0374\u0376\u0377\u037A-\u037D\u0386-\u038A\u038C\u038E-\u03A1\u03A3-\u03F5\u03F7-\u0481\u0483-\u0487\u048A-\u0527\u0531-\u0556\u0559\u0561-\u0587\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7\u05D0-\u05EA\u05F0-\u05F2\u0610-\u061A\u0620-\u0669\u066E-\u06D3\u06D5-\u06DC\u06DF-\u06E8\u06EA-\u06FC\u06FF\u0710-\u074A\u074D-\u07B1\u07C0-\u07F5\u07FA\u0800-\u082D\u0840-\u085B\u0900-\u0963\u0966-\u096F\u0971-\u0977\u0979-\u097F\u0981-\u0983\u0985-\u098C\u098F\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BC-\u09C4\u09C7\u09C8\u09CB-\u09CE\u09D7\u09DC\u09DD\u09DF-\u09E3\u09E6-\u09F1\u0A01-\u0A03\u0A05-\u0A0A\u0A0F\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32\u0A33\u0A35\u0A36\u0A38\u0A39\u0A3C\u0A3E-\u0A42\u0A47\u0A48\u0A4B-\u0A4D\u0A51\u0A59-\u0A5C\u0A5E\u0A66-\u0A75\u0A81-\u0A83\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2\u0AB3\u0AB5-\u0AB9\u0ABC-\u0AC5\u0AC7-\u0AC9\u0ACB-\u0ACD\u0AD0\u0AE0-\u0AE3\u0AE6-\u0AEF\u0B01-\u0B03\u0B05-\u0B0C\u0B0F\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32\u0B33\u0B35-\u0B39\u0B3C-\u0B44\u0B47\u0B48\u0B4B-\u0B4D\u0B56\u0B57\u0B5C\u0B5D\u0B5F-\u0B63\u0B66-\u0B6F\u0B71\u0B82\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99\u0B9A\u0B9C\u0B9E\u0B9F\u0BA3\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BBE-\u0BC2\u0BC6-\u0BC8\u0BCA-\u0BCD\u0BD0\u0BD7\u0BE6-\u0BEF\u0C01-\u0C03\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C33\u0C35-\u0C39\u0C3D-\u0C44\u0C46-\u0C48\u0C4A-\u0C4D\u0C55\u0C56\u0C58\u0C59\u0C60-\u0C63\u0C66-\u0C6F\u0C82\u0C83\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBC-\u0CC4\u0CC6-\u0CC8\u0CCA-\u0CCD\u0CD5\u0CD6\u0CDE\u0CE0-\u0CE3\u0CE6-\u0CEF\u0CF1\u0CF2\u0D02\u0D03\u0D05-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D-\u0D44\u0D46-\u0D48\u0D4A-\u0D4E\u0D57\u0D60-\u0D63\u0D66-\u0D6F\u0D7A-\u0D7F\u0D82\u0D83\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0DCA\u0DCF-\u0DD4\u0DD6\u0DD8-\u0DDF\u0DF2\u0DF3\u0E01-\u0E3A\u0E40-\u0E4E\u0E50-\u0E59\u0E81\u0E82\u0E84\u0E87\u0E88\u0E8A\u0E8D\u0E94-\u0E97\u0E99-\u0E9F\u0EA1-\u0EA3\u0EA5\u0EA7\u0EAA\u0EAB\u0EAD-\u0EB9\u0EBB-\u0EBD\u0EC0-\u0EC4\u0EC6\u0EC8-\u0ECD\u0ED0-\u0ED9\u0EDC\u0EDD\u0F00\u0F18\u0F19\u0F20-\u0F29\u0F35\u0F37\u0F39\u0F3E-\u0F47\u0F49-\u0F6C\u0F71-\u0F84\u0F86-\u0F97\u0F99-\u0FBC\u0FC6\u1000-\u1049\u1050-\u109D\u10A0-\u10C5\u10D0-\u10FA\u10FC\u1100-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u135D-\u135F\u1369-\u1371\u1380-\u138F\u13A0-\u13F4\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u16EE-\u16F0\u1700-\u170C\u170E-\u1714\u1720-\u1734\u1740-\u1753\u1760-\u176C\u176E-\u1770\u1772\u1773\u1780-\u17B3\u17B6-\u17D3\u17D7\u17DC\u17DD\u17E0-\u17E9\u180B-\u180D\u1810-\u1819\u1820-\u1877\u1880-\u18AA\u18B0-\u18F5\u1900-\u191C\u1920-\u192B\u1930-\u193B\u1946-\u196D\u1970-\u1974\u1980-\u19AB\u19B0-\u19C9\u19D0-\u19DA\u1A00-\u1A1B\u1A20-\u1A5E\u1A60-\u1A7C\u1A7F-\u1A89\u1A90-\u1A99\u1AA7\u1B00-\u1B4B\u1B50-\u1B59\u1B6B-\u1B73\u1B80-\u1BAA\u1BAE-\u1BB9\u1BC0-\u1BF3\u1C00-\u1C37\u1C40-\u1C49\u1C4D-\u1C7D\u1CD0-\u1CD2\u1CD4-\u1CF2\u1D00-\u1DE6\u1DFC-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u203F\u2040\u2054\u2071\u207F\u2090-\u209C\u20D0-\u20DC\u20E1\u20E5-\u20F0\u2102\u2107\u210A-\u2113\u2115\u2118-\u211D\u2124\u2126\u2128\u212A-\u2139\u213C-\u213F\u2145-\u2149\u214E\u2160-\u2188\u2C00-\u2C2E\u2C30-\u2C5E\u2C60-\u2CE4\u2CEB-\u2CF1\u2D00-\u2D25\u2D30-\u2D65\u2D6F\u2D7F-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u2DE0-\u2DFF\u3005-\u3007\u3021-\u302F\u3031-\u3035\u3038-\u303C\u3041-\u3096\u3099-\u309F\u30A1-\u30FA\u30FC-\u30FF\u3105-\u312D\u3131-\u318E\u31A0-\u31BA\u31F0-\u31FF\u3400-\u4DB5\u4E00-\u9FCB\uA000-\uA48C\uA4D0-\uA4FD\uA500-\uA60C\uA610-\uA62B\uA640-\uA66F\uA67C\uA67D\uA67F-\uA697\uA6A0-\uA6F1\uA717-\uA71F\uA722-\uA788\uA78B-\uA78E\uA790\uA791\uA7A0-\uA7A9\uA7FA-\uA827\uA840-\uA873\uA880-\uA8C4\uA8D0-\uA8D9\uA8E0-\uA8F7\uA8FB\uA900-\uA92D\uA930-\uA953\uA960-\uA97C\uA980-\uA9C0\uA9CF-\uA9D9\uAA00-\uAA36\uAA40-\uAA4D\uAA50-\uAA59\uAA60-\uAA76\uAA7A\uAA7B\uAA80-\uAAC2\uAADB-\uAADD\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uABC0-\uABEA\uABEC\uABED\uABF0-\uABF9\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA2D\uFA30-\uFA6D\uFA70-\uFAD9\uFB00-\uFB06\uFB13-\uFB17\uFB1D-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40\uFB41\uFB43\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE00-\uFE0F\uFE20-\uFE26\uFE33\uFE34\uFE4D-\uFE4F\uFE70-\uFE74\uFE76-\uFEFC\uFF10-\uFF19\uFF21-\uFF3A\uFF3F\uFF41-\uFF5A\uFF66-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD7\uFFDA-\uFFDC]|\uD800[\uDC00-\uDC0B\uDC0D-\uDC26\uDC28-\uDC3A\uDC3C\uDC3D\uDC3F-\uDC4D\uDC50-\uDC5D\uDC80-\uDCFA\uDD40-\uDD74\uDDFD\uDE80-\uDE9C\uDEA0-\uDED0\uDF00-\uDF1E\uDF30-\uDF4A\uDF80-\uDF9D\uDFA0-\uDFC3\uDFC8-\uDFCF\uDFD1-\uDFD5]|\uD801[\uDC00-\uDC9D\uDCA0-\uDCA9]|\uD802[\uDC00-\uDC05\uDC08\uDC0A-\uDC35\uDC37\uDC38\uDC3C\uDC3F-\uDC55\uDD00-\uDD15\uDD20-\uDD39\uDE00-\uDE03\uDE05\uDE06\uDE0C-\uDE13\uDE15-\uDE17\uDE19-\uDE33\uDE38-\uDE3A\uDE3F\uDE60-\uDE7C\uDF00-\uDF35\uDF40-\uDF55\uDF60-\uDF72]|\uD803[\uDC00-\uDC48]|\uD804[\uDC00-\uDC46\uDC66-\uDC6F\uDC80-\uDCBA]|\uD808[\uDC00-\uDF6E]|\uD809[\uDC00-\uDC62]|[\uD80C\uD840-\uD868\uD86A-\uD86C][\uDC00-\uDFFF]|\uD80D[\uDC00-\uDC2E]|\uD81A[\uDC00-\uDE38]|\uD82C[\uDC00\uDC01]|\uD834[\uDD65-\uDD69\uDD6D-\uDD72\uDD7B-\uDD82\uDD85-\uDD8B\uDDAA-\uDDAD\uDE42-\uDE44]|\uD835[\uDC00-\uDC54\uDC56-\uDC9C\uDC9E\uDC9F\uDCA2\uDCA5\uDCA6\uDCA9-\uDCAC\uDCAE-\uDCB9\uDCBB\uDCBD-\uDCC3\uDCC5-\uDD05\uDD07-\uDD0A\uDD0D-\uDD14\uDD16-\uDD1C\uDD1E-\uDD39\uDD3B-\uDD3E\uDD40-\uDD44\uDD46\uDD4A-\uDD50\uDD52-\uDEA5\uDEA8-\uDEC0\uDEC2-\uDEDA\uDEDC-\uDEFA\uDEFC-\uDF14\uDF16-\uDF34\uDF36-\uDF4E\uDF50-\uDF6E\uDF70-\uDF88\uDF8A-\uDFA8\uDFAA-\uDFC2\uDFC4-\uDFCB\uDFCE-\uDFFF]|\uD869[\uDC00-\uDED6\uDF00-\uDFFF]|\uD86D[\uDC00-\uDF34\uDF40-\uDFFF]|\uD86E[\uDC00-\uDC1D]|\uD87E[\uDC00-\uDE1D]|\uDB40[\uDD00-\uDDEF])+
%{
  return 'UnicodeIDContinue';
%}

<identifier_start,identifier_start_unicode,decimal_digit_start>[\u0009|\u0020|\u000A] %{
  this.popState();
%}
<decimal_digit_dot_start>[\u0009|\u0020|\u000A] %{
  this.popState();
  this.popState();
%}

',' %{
  if (this.topState() === 'identifier_start') {
    this.popState();
  }
  if (this.topState() === 'decimal_digit_start') {
    this.popState();
  }
  if (this.topState() === 'decimal_digit_dot_start') {
    this.popState();
    this.popState();
  }
  return ',';
%}

'.' %{
  {
    let hasDigitBehind = false;
    let i = this.matches.index + 1;
    const input = this.matches.input;
    while(i < input.length && isWhiteSpace(input[i])) {
      i++;
    }
    if (i < input.length && isDecimalDigit(input[i])) {
      hasDigitBehind = true;
    }

    //如果look ahead是数字 例如.123 返回DecimalPoint
    switch (this.topState()) {
      case 'decimal_digit_start':
        this.begin('decimal_digit_dot_start');
        return 'DecimalPoint';
      case 'decimal_digit_dot_start':
        this.popState();
        this.popState();
        return '.';
      case 'identifier_start':
        this.popState();
        return '.';
      default:
        if (hasDigitBehind) {
          this.begin('decimal_digit_start');
          this.begin('decimal_digit_dot_start');
          return 'DecimalPoint';
        }
        return '.';
    }
  }
%}

';' %{
  return ';';
%}

'===' %{
  return parseOperator.call(this, this.match, 'EqualityOperator');
%}
'==' %{
  return parseOperator.call(this, this.match, 'EqualityOperator');
%}
'!==' %{
  return parseOperator.call(this, this.match, 'EqualityOperator');
%}
'!=' %{
  return parseOperator.call(this, this.match, 'EqualityOperator');
%}

'++' %{
  return parseOperator.call(this, this.match, 'UpdateOperator');
%}

'--' %{
  return parseOperator.call(this, this.match, 'UpdateOperator');
%}

'&&' return '&&';
'||' return '||';
'?' return '?';

'+=' %{
  return parseOperator.call(this, this.match);
%}

'-=' %{
  return parseOperator.call(this, this.match);
%}

'*=' %{
  return parseOperator.call(this, this.match);
%}

'/=' %{
  return parseOperator.call(this, this.match);
%}

'%=' %{
  return parseOperator.call(this, this.match);
%}

'<<=' %{
  return parseOperator.call(this, this.match);
%}

'>>=' %{
  return parseOperator.call(this, this.match);
%}

'>>>=' %{
  return parseOperator.call(this, this.match);
%}

'&=' %{
  return parseOperator.call(this, this.match);
%}

'|=' %{
  return parseOperator.call(this, this.match);
%}

'^=' %{
  return parseOperator.call(this, this.match);
%}

'=>' %{
  return parseOperator.call(this, this.match);
%}
'**=' %{
  return parseOperator.call(this, this.match);
%}

'(' %{
  return parseOperator.call(this, this.match);
%}

')' %{
  return parseOperator.call(this, this.match);
%}

'=' %{
  return parseOperator.call(this, this.match);
%}

'+' %{
  return parseOperator.call(this, this.match, 'AdditiveOperator');
%}
'-' %{
  return parseOperator.call(this, this.match, 'AdditiveOperator');
%}

'!' %{
  return parseOperator.call(this, this.match, 'UnaryOperator');
%}

'~' %{
  return parseOperator.call(this, this.match, 'UnaryOperator');
%}

'**' %{
  return parseOperator.call(this, this.match);
%}

'*' %{
  return parseOperator.call(this, this.match, 'MultiplicativeOperator');
%}

'%' %{
  return parseOperator.call(this, this.match, 'MultiplicativeOperator');
%}

'/' %{
  return parseOperator.call(this, this.match, 'MultiplicativeOperator');
%}

'&' %{
  return parseOperator.call(this, this.match);
%}

'|' %{
  return parseOperator.call(this, this.match);
%}

'^' %{
  return parseOperator.call(this, this.match);
%}

'>>>' %{
  return parseOperator.call(this, this.match, 'ShiftOperator');
%}

'>>' %{
  return parseOperator.call(this, this.match, 'ShiftOperator');
%}

'>=' %{
  return parseOperator.call(this, this.match, 'RelationalOperator');
%}

'<=' %{
  return parseOperator.call(this, this.match, 'RelationalOperator');
%}

'>' %{
  return parseOperator.call(this, this.match, 'RelationalOperator');
%}

'<' %{
  return parseOperator.call(this, this.match, 'RelationalOperator');
%}

<identifier_start>\\[u|U] %{
  this.begin('identifier_start_unicode');
  return 'UnicodeEscapeSequenceContinueStart';
%}

\\[u|U] %{
  if (this.topState() === 'identifier_start') {
  } else {
    this.begin('identifier_start');
  }
  this.begin('identifier_start_unicode');
  return 'UnicodeEscapeSequenceStart';
%}

<identifier_start_unicode>[0123456789abcdefABCDEF] %{
  if (!this.__unicode_counter) { this.__unicode_counter = 0; }
  this.__unicode_counter++;
  if (this.__unicode_counter === 4) {
    this.__unicode_counter = 0;
    this.popState();
    const topState = this.topState();
    if (topState === 'double_escape_string' || topState === 'single_escape_string') {
      this.popState();
    }
  }
  return 'HexDigit';
%}

<decimal_digit_start,decimal_digit_dot_start>[0-9] %{
  return 'DecimalDigit';
%}

[0] %{
  this.begin('decimal_digit_start');
  return '0';
%}

[1-9] %{
  this.begin('decimal_digit_start');
  return 'NonZeroDigit';
%}


([A-Za-z\xAA\xB5\xBA\xC0-\xD6\xD8-\xF6\xF8-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0370-\u0374\u0376\u0377\u037A-\u037D\u0386\u0388-\u038A\u038C\u038E-\u03A1\u03A3-\u03F5\u03F7-\u0481\u048A-\u0527\u0531-\u0556\u0559\u0561-\u0587\u05D0-\u05EA\u05F0-\u05F2\u0620-\u064A\u066E\u066F\u0671-\u06D3\u06D5\u06E5\u06E6\u06EE\u06EF\u06FA-\u06FC\u06FF\u0710\u0712-\u072F\u074D-\u07A5\u07B1\u07CA-\u07EA\u07F4\u07F5\u07FA\u0800-\u0815\u081A\u0824\u0828\u0840-\u0858\u0904-\u0939\u093D\u0950\u0958-\u0961\u0971-\u0977\u0979-\u097F\u0985-\u098C\u098F\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BD\u09CE\u09DC\u09DD\u09DF-\u09E1\u09F0\u09F1\u0A05-\u0A0A\u0A0F\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32\u0A33\u0A35\u0A36\u0A38\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2\u0AB3\u0AB5-\u0AB9\u0ABD\u0AD0\u0AE0\u0AE1\u0B05-\u0B0C\u0B0F\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32\u0B33\u0B35-\u0B39\u0B3D\u0B5C\u0B5D\u0B5F-\u0B61\u0B71\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99\u0B9A\u0B9C\u0B9E\u0B9F\u0BA3\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BD0\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C33\u0C35-\u0C39\u0C3D\u0C58\u0C59\u0C60\u0C61\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBD\u0CDE\u0CE0\u0CE1\u0CF1\u0CF2\u0D05-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D\u0D4E\u0D60\u0D61\u0D7A-\u0D7F\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0E01-\u0E30\u0E32\u0E33\u0E40-\u0E46\u0E81\u0E82\u0E84\u0E87\u0E88\u0E8A\u0E8D\u0E94-\u0E97\u0E99-\u0E9F\u0EA1-\u0EA3\u0EA5\u0EA7\u0EAA\u0EAB\u0EAD-\u0EB0\u0EB2\u0EB3\u0EBD\u0EC0-\u0EC4\u0EC6\u0EDC\u0EDD\u0F00\u0F40-\u0F47\u0F49-\u0F6C\u0F88-\u0F8C\u1000-\u102A\u103F\u1050-\u1055\u105A-\u105D\u1061\u1065\u1066\u106E-\u1070\u1075-\u1081\u108E\u10A0-\u10C5\u10D0-\u10FA\u10FC\u1100-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u1380-\u138F\u13A0-\u13F4\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u16EE-\u16F0\u1700-\u170C\u170E-\u1711\u1720-\u1731\u1740-\u1751\u1760-\u176C\u176E-\u1770\u1780-\u17B3\u17D7\u17DC\u1820-\u1877\u1880-\u18A8\u18AA\u18B0-\u18F5\u1900-\u191C\u1950-\u196D\u1970-\u1974\u1980-\u19AB\u19C1-\u19C7\u1A00-\u1A16\u1A20-\u1A54\u1AA7\u1B05-\u1B33\u1B45-\u1B4B\u1B83-\u1BA0\u1BAE\u1BAF\u1BC0-\u1BE5\u1C00-\u1C23\u1C4D-\u1C4F\u1C5A-\u1C7D\u1CE9-\u1CEC\u1CEE-\u1CF1\u1D00-\u1DBF\u1E00-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u2071\u207F\u2090-\u209C\u2102\u2107\u210A-\u2113\u2115\u2118-\u211D\u2124\u2126\u2128\u212A-\u2139\u213C-\u213F\u2145-\u2149\u214E\u2160-\u2188\u2C00-\u2C2E\u2C30-\u2C5E\u2C60-\u2CE4\u2CEB-\u2CEE\u2D00-\u2D25\u2D30-\u2D65\u2D6F\u2D80-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u3005-\u3007\u3021-\u3029\u3031-\u3035\u3038-\u303C\u3041-\u3096\u309B-\u309F\u30A1-\u30FA\u30FC-\u30FF\u3105-\u312D\u3131-\u318E\u31A0-\u31BA\u31F0-\u31FF\u3400-\u4DB5\u4E00-\u9FCB\uA000-\uA48C\uA4D0-\uA4FD\uA500-\uA60C\uA610-\uA61F\uA62A\uA62B\uA640-\uA66E\uA67F-\uA697\uA6A0-\uA6EF\uA717-\uA71F\uA722-\uA788\uA78B-\uA78E\uA790\uA791\uA7A0-\uA7A9\uA7FA-\uA801\uA803-\uA805\uA807-\uA80A\uA80C-\uA822\uA840-\uA873\uA882-\uA8B3\uA8F2-\uA8F7\uA8FB\uA90A-\uA925\uA930-\uA946\uA960-\uA97C\uA984-\uA9B2\uA9CF\uAA00-\uAA28\uAA40-\uAA42\uAA44-\uAA4B\uAA60-\uAA76\uAA7A\uAA80-\uAAAF\uAAB1\uAAB5\uAAB6\uAAB9-\uAABD\uAAC0\uAAC2\uAADB-\uAADD\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uABC0-\uABE2\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA2D\uFA30-\uFA6D\uFA70-\uFAD9\uFB00-\uFB06\uFB13-\uFB17\uFB1D\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40\uFB41\uFB43\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE74\uFE76-\uFEFC\uFF21-\uFF3A\uFF41-\uFF5A\uFF66-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD7\uFFDA-\uFFDC]|\uD800[\uDC00-\uDC0B\uDC0D-\uDC26\uDC28-\uDC3A\uDC3C\uDC3D\uDC3F-\uDC4D\uDC50-\uDC5D\uDC80-\uDCFA\uDD40-\uDD74\uDE80-\uDE9C\uDEA0-\uDED0\uDF00-\uDF1E\uDF30-\uDF4A\uDF80-\uDF9D\uDFA0-\uDFC3\uDFC8-\uDFCF\uDFD1-\uDFD5]|\uD801[\uDC00-\uDC9D]|\uD802[\uDC00-\uDC05\uDC08\uDC0A-\uDC35\uDC37\uDC38\uDC3C\uDC3F-\uDC55\uDD00-\uDD15\uDD20-\uDD39\uDE00\uDE10-\uDE13\uDE15-\uDE17\uDE19-\uDE33\uDE60-\uDE7C\uDF00-\uDF35\uDF40-\uDF55\uDF60-\uDF72]|\uD803[\uDC00-\uDC48]|\uD804[\uDC03-\uDC37\uDC83-\uDCAF]|\uD808[\uDC00-\uDF6E]|\uD809[\uDC00-\uDC62]|[\uD80C\uD840-\uD868\uD86A-\uD86C][\uDC00-\uDFFF]|\uD80D[\uDC00-\uDC2E]|\uD81A[\uDC00-\uDE38]|\uD82C[\uDC00\uDC01]|\uD835[\uDC00-\uDC54\uDC56-\uDC9C\uDC9E\uDC9F\uDCA2\uDCA5\uDCA6\uDCA9-\uDCAC\uDCAE-\uDCB9\uDCBB\uDCBD-\uDCC3\uDCC5-\uDD05\uDD07-\uDD0A\uDD0D-\uDD14\uDD16-\uDD1C\uDD1E-\uDD39\uDD3B-\uDD3E\uDD40-\uDD44\uDD46\uDD4A-\uDD50\uDD52-\uDEA5\uDEA8-\uDEC0\uDEC2-\uDEDA\uDEDC-\uDEFA\uDEFC-\uDF14\uDF16-\uDF34\uDF36-\uDF4E\uDF50-\uDF6E\uDF70-\uDF88\uDF8A-\uDFA8\uDFAA-\uDFC2\uDFC4-\uDFCB]|\uD869[\uDC00-\uDED6\uDF00-\uDFFF]|\uD86D[\uDC00-\uDF34\uDF40-\uDFFF]|\uD86E[\uDC00-\uDC1D]|\uD87E[\uDC00-\uDE1D])
%{
  console.log(this.match);
  this.begin('identifier_start');
  return 'UnicodeIDStart';
%}

'.' %{
  console.log(this.match);
  this.popState();
  return '.';
%}


\u0009 return ''
\u000B return 'VT'
\u000C return 'FF';
\u0020 return '';
\u00A0 return 'NBSP';

\u200C return 'ZWNJ';
\u200D return 'ZWJ';
\uFEFF return 'ZWNBSP';

\u000A return '';
\u000D return 'CR';
\u2028 return 'LS';
\u2029 return 'PS';

/lex

%start Script

%nonassoc 'if'
%nonassoc 'else'

%%

Script
  : ScriptBody
  ;

ScriptBody
  : StatementList
  ;

PrimaryExpression
  : IdentifierReference {
    console.log('identifier reference ' + $1);
    $$ = $1;
  }
  | 'this' {
    console.log('this');
  }
  | Literal {
    console.log('literal ' + $1);
  }
  | ArrayLiteral {
    console.log('array literal ' + $1);
  }
  | ObjectLiteral {
    console.log('object literal ' + $1);
  }
  | CoverParenthesizedExpressionAndArrowParameterList {
    console.log('cover parenthesized expression ');
  }
  | FunctionExpression {
    console.log(' function expression ');
  }
  ;

IdentifierReference
  : Identifier
  ;

Identifier
  : IdentifierName {
    console.log('identifier name ' + $1);
    $$ = $1;
  }
  ;

IdentifierName
  : IdentifierStart {
    console.log('unicode id start');
    $$ = $1;
  }
  | IdentifierName IdentifierPart {
    console.log('unicode id part');
    $$ = $1 + $2;
  }
  ;

IdentifierStart
  : UnicodeIDStart {
    $$ = $1;
  }
  | UnicodeEscapeSequence {
    $$ = $1;
  }
  | '$' {
    $$ = $1;
  }
  | '_' {
    $$ = $1;
  }
  ;

UnicodeEscapeSequence
  : UnicodeEscapeSequenceStart Hex4Digits {
    $$ = $1 + $2;
  }
  ;

UnicodeEscapeSequenceContinue
  : UnicodeEscapeSequenceContinueStart Hex4Digits {
    $$ = $1 + $2;
  }
  ;

IdentifierPart
  : UnicodeIDContinue {
    $$ = $1;
  }
  | UnicodeEscapeSequenceContinue {
    $$ = $1;
  }
  | '$' {
    $$ = $1;
  }
  | '_' {
    $$ = $1;
  }
  | ZWNJ
  | ZWJ
  ;

Hex4Digits
  : HexDigit HexDigit HexDigit HexDigit {
    $$ = $1 + $2 + $3 + $4;
  }
  ;

DecimalIntegerLiteral
  : '0' {
    $$ = $1;
  }
  | '0' DecimalDigits {
    $$ = $1 + $2;
  }
  | NonZeroDigit {
    $$ = $1;
  }
  | NonZeroDigit DecimalDigits {
    $$ = $1 + $2;
  }
  ;

DecimalDigits
  : DecimalDigit {
    $$ = $1;
  }
  | DecimalDigits DecimalDigit {
    $$ = $1 + $2;
  }
  ;

DecimalLiteral
  : DecimalIntegerLiteral 'DecimalPoint' {
    $$ = $1;
  }
  | DecimalIntegerLiteral 'DecimalPoint' DecimalDigits {
    $$ = $1  + $2 + $3;
  }
  | 'DecimalPoint' DecimalDigits {
    $$ = '0' + $1  + $2;
  }
  | DecimalIntegerLiteral {
    $$ = $1;
  }
  ;

SingleStringCharacters
  : SingleStringCharacter SingleStringCharacters {
    $$ = $1 + $2;
  }
  | SingleStringCharacter {
    $$ = $1;
  }
  | EscapeSequenceStart EscapeSequence  {
    $$ = $1 + $2;
  }
  | EscapeSequenceStart EscapeSequence SingleStringCharacters {
    $$ = $1 + $2 + $3;
  }
  ;

DoubleStringCharacters
  : DoubleStringCharacter DoubleStringCharacters {
    $$ = $1 + $2;
  }
  | DoubleStringCharacter {
    $$ = $1;
  }
  | EscapeSequenceStart EscapeSequence  {
    $$ = $1 + $2;
  }
  | EscapeSequenceStart EscapeSequence DoubleStringCharacters {
    $$ = $1 + $2 + $3;
  }
  ;

EscapeSequence
  : UnicodeEscapeSequence {
    $$ = $1;
  }
  | CharacterEscapeSequence {
    $$ = $1;
  }
  ;

CharacterEscapeSequence
  : SingleEscapeCharacter {
    $$ = $1;
  }
  | NonEscapeCharacter {
    $$ = $1;
  }
  ;

StringLiteral
  : SingleQuoteStart SingleStringCharacters SingleQuoteEnd {
    $$ = $2;
  }
  | DoubleQuoteStart DoubleStringCharacters DoubleQuoteEnd {
    $$ = $2;
  }
  | SingleQuoteStart SingleQuoteEnd {
    $$ = '';
  }
  | DoubleQuoteStart DoubleQuoteEnd {
    $$ = "";
  }
  ;

Literal
  : NullLiteral {

  }
  | BooleanLiteral {

  }
  | StringLiteral {
    console.log('string literal '  + $1);
    $$ = $1;
  }
  | DecimalLiteral {
  }
  ;

ArrayLiteral
  : '[' ']' {
    $$ = $1 + $2;
  }
  | '[' Elision ']' {
    $$ = $1 + $2;
  }
  | '[' ElementList ']' {
    $$ = $1 + $2 + $3;
  }
  | '[' ElementList ',' Elision ']' {
    $$ = $1 + $2 + $3 + $4 + $5;
  }
  ;

ElementList
  : AssignmentExpression_In {
    $$ = $1;
  }
  | Elision AssignmentExpression_In {
    $$ = $1 + $2;
  }
  | ElementList  ',' AssignmentExpression_In {
    $$ = $1 + $2 + $3;
  }
  | ElementList  ',' Elision AssignmentExpression_In {
    $$ = $1 + $2 + $3 + $4;
  }
  ;

Elision
  : ',' {

  }
  | Elision ',' {

  }
  ;

AssignmentExpression_In
  : ConditionalExpression_In {
    console.log('conditional expression');
  }
  | LeftHandSideExpression '=' AssignmentExpression_In {

  }
  | LeftHandSideExpression AssignmentOperator AssignmentExpression_In {

  }
  ;

AssignmentOperator
  : '*='
  | '/='
  | '%='
  | '+='
  | '-='
  | '<<='
  | '>>='
  | '>>>='
  | '&='
  | '^='
  | '|='
  | '**='
  ;

ConditionalExpression_In
  : LogicalORExpression_In {
    console.log('logical or expression');
  }
  | LogicalORExpression_In '?' AssignmentExpression_In ':' AssignmentExpression_In {
    console.log(' ? : expression');
  }
  ;

LogicalORExpression_In
  : LogicalANDExpression_In {
    console.log('logical and expression');
  }
  | LogicalORExpression_In '||' LogicalANDExpression_In
  ;

LogicalANDExpression_In
  : BitwiseORExpression_In {
    console.log('bitwise or expression');
  }
  | LogicalANDExpression_In '&&' BitwiseORExpression_In
  ;

BitwiseORExpression_In
  : BitwiseXORExpression_In
  | BitwiseORExpression_In '|' BitwiseXORExpression_In
  ;

BitwiseXORExpression_In
  : BitwiseANDExpression_In
  | BitwiseXORExpression_In '^' BitwiseANDExpression_In
  ;

BitwiseANDExpression_In
  : EqualityExpression_In
  | BitwiseANDExpression_In '&' EqualityExpression_In
  ;

EqualityExpression_In
  : RelationalExpression_In
  | EqualityExpression_In EqualityOperator RelationalExpression_In
  /* | EqualityExpression_In '==' RelationalExpression_In */
  /* | EqualityExpression_In '!=' RelationalExpression_In */
  /* | EqualityExpression_In '===' RelationalExpression_In */
  /* | EqualityExpression_In '!==' RelationalExpression_In */
  ;

RelationalExpression_In
  : ShiftExpression
  | RelationalExpression_In RelationalOperator ShiftExpression
  | RelationalExpression_In 'in' ShiftExpression
  /* | RelationalExpression_In '<' ShiftExpression */
  /* | RelationalExpression_In '>' ShiftExpression */
  /* | RelationalExpression_In '<=' ShiftExpression */
  /* | RelationalExpression_In '>=' ShiftExpression */
  /* | RelationalExpression_In 'instanceof' ShiftExpression */
  /* | RelationalExpression_In 'in' ShiftExpression */
  ;

AssignmentExpression
  : ConditionalExpression
  ;

ConditionalExpression
  : LogicalORExpression
  ;

LogicalORExpression
  : LogicalANDExpression
  | LogicalORExpression '||' LogicalANDExpression
  ;

LogicalANDExpression
  : BitwiseORExpression
  | LogicalANDExpression '&&' BitwiseORExpression
  ;

BitwiseORExpression
  : BitwiseXORExpression
  | BitwiseORExpression '|' BitwiseXORExpression
  ;

BitwiseXORExpression
  : BitwiseANDExpression
  | BitwiseXORExpression '^' BitwiseANDExpression
  ;

BitwiseANDExpression
  : EqualityExpression
  | BitwiseANDExpression '&' EqualityExpression
  ;

EqualityExpression
  : RelationalExpression
  ;

RelationalExpression
  : ShiftExpression
  ;

ShiftExpression
  : AdditiveExpression
  | ShiftExpression ShiftOperator AdditiveExpression
  /* | ShiftExpression '<<' AdditiveExpression */
  /* | ShiftExpression '>>' AdditiveExpression */
  /* | ShiftExpression '>>>' AdditiveExpression */
  ;

AdditiveExpression
  : MultiplicativeExpression
  | AdditiveExpression AdditiveOperator MultiplicativeExpression
  /* | AdditiveExpression '+' MultiplicativeExpression */
  /* | AdditiveExpression '-' MultiplicativeExpression */
  ;

MultiplicativeExpression
  : ExponentiationExpression
  | MultiplicativeExpression MultiplicativeOperator ExponentiationExpression
  ;

ExponentiationExpression
  : UnaryExpression
  | UpdateExpression '**' ExponentiationExpression
  ;

UnaryExpression
  : UpdateExpression
  | UnaryOperator UnaryExpression
  | AdditiveOperator  UnaryExpression
  /* | 'delete' UnaryExpression */
  /* | 'void' UnaryExpression */
  /* | 'typeof' UnaryExpression */
  /* | '+' UnaryExpression */
  /* | '-' UnaryExpression */
  /* | '~' UnaryExpression */
  /* | '!' UnaryExpression */
  ;

UpdateExpression
  : LeftHandSideExpression
  | LeftHandSideExpression UpdateOperator
  | UpdateOperator LeftHandSideExpression
  /* | LeftHandSideExpression '++' */
  /* | LeftHandSideExpression '--' */
  /* | '++' UnaryExpression */
  /* | '--' UnaryExpression */
  ;

LeftHandSideExpression
  : NewExpression
  | CallExpression
  ;

NewExpression
  : MemberExpression
  | 'new' NewExpression {
    console.log('new expression');
  }
  ;

CallExpression
  : MemberExpression Arguments {
    console.log('call expression');
  }
  | SuperCall {
    console.log('super call expression');
  }
  | CallExpression Arguments {
    console.log('call expression argument');
  }
  | CallExpression '[' Expression_In ']' {
    console.log('call expression expression in ');
  }
  | CallExpression '.' IdentifierName {
    console.log('call expression identifier name');
  }
  ;

SuperCall
  : 'super' Arguments
  ;

MemberExpression
  : PrimaryExpression {
    console.log('primary ' + $1);
  }
  | MemberExpression '[' Expression_In ']' {
    console.log('member expression');
  }
  | MemberExpression '.' IdentifierName {
    console.log('member expression .');
  }
  | SuperProperty {
    console.log('super property');
  }
  | MetaProperty {
    console.log('meta property');
  }
  | 'new' MemberExpression Arguments {
    console.log('new member arguments');
  }
  ;

Arguments
  : '(' ')'
  | '(' ArgumentList ')'
  ;

ArgumentList
  : AssignmentExpression_In
  | '...' AssignmentExpression_In
  | ArgumentList ',' AssignmentExpression_In
  | ArgumentList ',' '...' AssignmentExpression_In
  ;

SuperProperty
  : 'super' '[' Expression_In ']' {
    console.log('super ' + $3);
  }
  | 'super' '.' IdentifierName {
    console.log('super ' + $3);
  }
  ;

MetaProperty
  : 'new' '.' 'target' {
    console.log('new.target');
  }
  ;

ObjectLiteral
  : 'BLOCK_START' '}' {
    $$ = $1 + $2;
  }
  | 'BLOCK_START' PropertyDefinitionList '}' {
    $$ = $1 + $2 + $3;
  }
  | 'BLOCK_START' PropertyDefinitionList ',' '}' {
    $$ = $1 + $2 + $4;
  }
  ;

PropertyDefinitionList
  : PropertyDefinition {
    $$ = $1;
  }
  | PropertyDefinitionList ',' PropertyDefinition {
    $$ = $1 + $2 + $3;
  }
  ;

PropertyDefinition
  : IdentifierReference {
    $$ = $1;
  }
  | CoverInitializedName {
    $$ = $1;
  }
  | PropertyName ':' AssignmentExpression_In {
    $$ = $1;
  }
  ;

PropertyName
  :LiteralPropertyName;

LiteralPropertyName
  : IdentifierName {
    $$ = $1;
  }
  | NumericLiteral {
    $$ = $1;
  }
  | StringLiteral {
    $$ = $1;
  }
  ;

CoverInitializedName
  : IdentifierReference Initializer_In {
    $$ = $1 + $2;
  }
  ;

Initializer_In
  : '=' AssignmentExpression_In {
    $$ = $1 + $2;
  }
  ;

Initializer
  : '=' AssignmentExpression {
    $$ = $1 + $2;
  }
  ;

Expression
  : AssignmentExpression
  | Expression ',' AssignmentExpression {

  }
  ;

Expression_In
  : AssignmentExpression_In {
    console.log('assignment expresion in');
  }
  | Expression_In ',' AssignmentExpression_In {

  }
  ;

ExpressionStatement
  : Expression_In ';'
  ;

EmptyStatement
  : ';'
  ;

Statement
  : EmptyStatement {
    console.log('empty statement');
  }
  | ExpressionStatement {
    console.log('expression statement');
  }
  | VariableStatement {
    console.log('var statement');
  }
  | BlockStatement {
    console.log('block statement');
  }
  | LabelledStatement {
    console.log('label statement');
  }
  | IfStatement {
    console.log('if statement');
  }
  | BreakableStatement {
    console.log('breakable statement');
  }
  | ContinueStatement {
    console.log('continue statement');
  }
  | BreakStatement {
    console.log('break statement');
  }
  | WithStatement {
    console.log('with statement');
  }
  | ThrowStatement {
    console.log('throw statement');
  }
  | DebuggerStatement {
    console.log('debugger statement');
  }
  | TryStatement {
    console.log('try statement');
  }
  ;

Statement_Return
  : EmptyStatement {
    console.log('empty statement');
  }
  | ExpressionStatement {
    console.log('expression statement');
  }
  | VariableStatement {
    console.log('var statement');
  }
  | BlockStatement_Return {
    console.log('block statement');
  }
  | LabelledStatement {
    console.log('label statement');
  }
  | IfStatement_Return {
    console.log('if statement');
  }
  | BreakableStatement_Return {
    console.log('breakable statement');
  }
  | ContinueStatement_Return {
    console.log('continue statement');
  }
  | ReturnStatement {
    console.log('return statement');
  }
  | BreakStatement {
    console.log('break statement');
  }
  | WithStatement_Return {
    console.log('with statement');
  }
  | ThrowStatement {
    console.log('throw statement');
  }
  | DebuggerStatement {
    console.log('debugger statement');
  }
  | TryStatement_Return {
    console.log('try statement');
  }
  ;

VariableStatement
  : 'var' VariableDeclarationList_In ';'
  ;

VariableDeclarationList_In
  : VariableDeclaration_In
  | VariableDeclarationList_In ',' VariableDeclaration_In
  ;

VariableDeclaration_In
  : BindingIdentifier
  | BindingIdentifier Initializer_In
  | BindingPattern Initializer_In
  ;

VariableDeclarationList
  : VariableDeclaration
  | VariableDeclaration ',' VariableDeclaration
  ;

VariableDeclaration
  : BindingIdentifier
  | BindingIdentifier Initializer
  | BindingPattern Initializer
  ;

BlockStatement
  : Block
  ;

BlockStatement_Return
  : Block_Return
  ;

Block
  : '{' StatementList '}'
  | '{' '}'
  ;

Block_Return
  : '{' StatementList_Return '}'
  | '{' '}'
  ;

IfStatement
  : 'if' '(' Expression_In ')' Statement %prec 'if'
  | 'if' '(' Expression_In ')' Statement 'else' Statement %prec 'else'
  ;

IfStatement_Return
  : 'if' '(' Expression_In ')' Statement_Return %prec 'if'
  | 'if' '(' Expression_In ')' Statement_Return 'else' Statement_Return %prec 'else'
  ;

BreakableStatement
  : IterationStatement
  | SwitchStatement {
    console.log('switch statement');
  }
  ;

BreakableStatement_Return
  : IterationStatement_Return
  | SwitchStatement_Return {
    console.log('switch statement');
  }
  ;

IterationStatement
  : 'do' Statement 'while' '(' Expression_In ')' ';' {
    console.log('do while statement');
  }
  | 'while' '(' Expression_In ')' Statement {
    console.log('while statement');
  }
  | 'for' '(' LexicalDeclaration Expression_In ';' Expression_In ')' Statement {
    console.log('for lexical declaration statement');
  }
  | 'for' '(' 'var' VariableDeclarationList ';' Expression_In ';' Expression_In ')' Statement {
    console.log('for var statement');
  }
  | 'for' '(' LeftHandSideExpression 'in' Expression_In ')' Statement {
    console.log('for left hand side exp in statement');
  }
  | 'for' '(' ForDeclaration 'in' Expression_In ')' Statement {
    console.log('for declaration side exp statement');
  }
  | 'for' '(' LeftHandSideExpression 'of' AssignmentExpression_In ')' Statement {
    console.log('for of statement');
  }
  | 'for' '(' 'var' ForBinding 'of' AssignmentExpression_In ')' Statement {
    console.log('for var of statement');
  }
  | 'for' '(' ForDeclaration 'of' AssignmentExpression_In ')' Statement {
    console.log('for delaration of statement');
  }

  | 'for' '(' Expression ';' Expression_In ';' Expression_In ')' Statement {
    console.log('for expression statement');
  }
  | 'for' '(' Expression ';' ';' Expression_In ')' Statement {
    console.log('for expression statement');
  }
  | 'for' '(' Expression ';' ';' ')' Statement {
    console.log('for expression statement');
  }
  | 'for' '(' Expression ';' Expression_In ';' ')' Statement {
    console.log('for expression statement');
  }

  | 'for' '(' ';' Expression_In ';' Expression_In ')' Statement {
    console.log('for expression statement');
  }
  | 'for' '(' ';' ';' Expression_In ')' Statement {
    console.log('for expression statement');
  }
  | 'for' '(' ';' ';' ')' Statement {
    console.log('for expression statement');
  }
  | 'for' '(' ';' Expression_In ';' ')' Statement {
    console.log('for expression statement');
  }

  ;

IterationStatement_Return
  : 'do' Statement_Return 'while' '(' Expression_In ')' ';' {
    console.log('do while statement return');
  }
  | 'while' '(' Expression_In ')' Statement_Return {
    console.log('while statement');
  }
  | 'for' '(' LexicalDeclaration Expression_In ';' Expression_In ')' Statement_Return {
    console.log('for lexical declaration statement return');
  }
  | 'for' '(' 'var' VariableDeclarationList ';' Expression_In ';' Expression_In ')' Statement_Return {
    console.log('for var statement');
  }
  | 'for' '(' LeftHandSideExpression 'in' Expression_In ')' Statement_Return {
    console.log('for left hand side exp in statement');
  }
  | 'for' '(' ForDeclaration 'in' Expression_In ')' Statement_Return {
    console.log('for declaration side exp statement');
  }
  | 'for' '(' LeftHandSideExpression 'of' AssignmentExpression_In ')' Statement_Return {
    console.log('for of statement');
  }
  | 'for' '(' 'var' ForBinding 'of' AssignmentExpression_In ')' Statement_Return {
    console.log('for var of statement');
  }
  | 'for' '(' ForDeclaration 'of' AssignmentExpression_In ')' Statement_Return {
    console.log('for delaration of statement');
  }

  | 'for' '(' Expression ';' Expression_In ';' Expression_In ')' Statement_Return {
    console.log('for expression statement');
  }
  | 'for' '(' Expression ';' ';' Expression_In ')' Statement_Return {
    console.log('for expression statement');
  }
  | 'for' '(' Expression ';' ';' ')' Statement_Return {
    console.log('for expression statement');
  }
  | 'for' '(' Expression ';' Expression_In ';' ')' Statement_Return {
    console.log('for expression statement');
  }

  | 'for' '(' ';' Expression_In ';' Expression_In ')' Statement_Return {
    console.log('for expression statement');
  }
  | 'for' '(' ';' ';' Expression_In ')' Statement_Return {
    console.log('for expression statement');
  }
  | 'for' '(' ';' ';' ')' Statement_Return {
    console.log('for expression statement');
  }
  | 'for' '(' ';' Expression_In ';' ')' Statement_Return {
    console.log('for expression statement');
  }
  ;

ForDeclaration
  : LetOrConst ForBinding
  ;

ForBinding
  : BindingIdentifier {

  }
  | BindingPattern  {

  }
  ;

LabelledStatement
  : LabelIdentifier ':' LabelledItem
  ;

LabelIdentifier
  : Identifier
  ;

LabelledItem
  : Statement
  | FunctionDeclaration
  ;

SwitchStatement
  : 'switch' '(' Expression_In ')' CaseBlock
  ;

SwitchStatement_Return
  : 'switch' '(' Expression_In ')' CaseBlock_Return
  ;

CaseBlock
  : '{' '}'
  | '{' CaseClauses '}'
  | '{' DefaultClause CaseClauses '}'
  | '{' DefaultClause '}'
  | '{' CaseClauses DefaultClause '}'
  | '{' CaseClauses DefaultClause CaseClauses '}'
  ;

CaseBlock_Return
  : '{' '}'
  | '{' CaseClauses_Return '}'
  | '{' DefaultClause_Return CaseClauses_Return '}'
  | '{' DefaultClause_Return '}'
  | '{' CaseClauses_Return DefaultClause_Return '}'
  | '{' CaseClauses_Return DefaultClause_Return CaseClauses_Return '}'
  ;

CaseClauses
  : CaseClause {

  }
  | CaseClauses CaseClause {

  }
  ;

CaseClause
  : 'case' Expression_In ':' StatementList
  | 'case' Expression_In ':'
  ;

DefaultClause
  : 'default' ':' StatementList
  | 'default' ':'
  ;

CaseClauses_Return
  : CaseClause_Return {

  }
  | CaseClauses_Return CaseClause_Return {

  }
  ;

CaseClause_Return
  : 'case' Expression_In ':' StatementList_Return
  | 'case' Expression_In ':'
  ;

DefaultClause_Return
  : 'default' ':' StatementList_Return
  | 'default' ':'
  ;

ContinueStatement
  : 'continue' ';'
  | 'CONTINUE_LF' ';'
  | 'continue' LabelIdentifier ';'
  ;

BreakStatement
  : 'break' ';'
  | 'BREAK_LF' ';'
  | 'break' LabelIdentifier ';'
  ;

WithStatement
  : 'with' '(' Expression_In ')' Statement
  ;

WithStatement_Return
  : 'with' '(' Expression_In ')' Statement_Return
  ;

ThrowStatement
  : 'throw' Expression_In ';' {

  }
  | 'THROW_LF' ';' {
    console.log('throw with lf');
  }
  ;

ReturnStatement
  : 'return' ';' {

  }
  | 'return' Expression_In ';' {

  }
  ;

DebuggerStatement
  : 'debugger' ';'
  ;

StatementList
  : StatementListItem
  | StatementList StatementListItem
  ;

StatementListItem
  : Statement
  | Declaration
  ;

StatementList_Return
  : StatementListItem_Return
  | StatementList_Return StatementListItem_Return
  ;

StatementListItem_Return
  : Statement_Return
  | Declaration
  ;

Declaration
  : HoistableDeclaration
  | LexicalDeclaration_In
  ;

LexicalDeclaration_In
  : 'LetOrConst' BindingList_In ';' {
    console.log('let const declartion in');
  }
  ;

LexicalDeclaration
  : 'LetOrConst' BindingList ';' {
    console.log('let const declartion');
  }
  ;

BindingList_In
  : LexicalBinding_In
  | BindingList_In ',' LexicalBinding_In
  ;

LexicalBinding_In
  : BindingIdentifier
  | BindingIdentifier Initializer_In
  | BindingPattern Initializer_In
  ;

BindingList
  : LexicalBinding
  | BindingList ',' LexicalBinding
  ;

LexicalBinding
  : BindingIdentifier
  | BindingIdentifier Initializer
  | BindingPattern Initializer
  ;

HoistableDeclaration
  : FunctionDeclaration
  ;

HoistableDeclaration_Default
  : FunctionDeclaration_Default
  ;

FunctionDeclaration
  : 'FUNCTION' BindingIdentifier '(' ')' '{' FunctionBody '}' {
    console.log('function delaration');
  }
  | 'FUNCTION' BindingIdentifier '(' ')' '{' '}' {
    console.log('function delaration');
  }
  | 'FUNCTION' BindingIdentifier '(' FormalParameters ')' '{' FunctionBody '}' {
    console.log('function delaration');
  }
  | 'FUNCTION' BindingIdentifier '(' FormalParameters ')' '{' '}' {
    console.log('function delaration');
  }
  ;

FunctionDeclaration_Default
  : 'FUNCTION' BindingIdentifier '(' ')' '{' FunctionBody '}' {
    console.log('function delaration');
  }
  | 'FUNCTION' BindingIdentifier '(' ')' '{' '}' {
    console.log('function delaration');
  }
  | 'FUNCTION' BindingIdentifier '(' FormalParameters ')' '{' FunctionBody '}' {
    console.log('function delaration');
  }
  | 'FUNCTION' BindingIdentifier '(' FormalParameters ')' '{' '}' {
    console.log('function delaration');
  }
  | 'FUNCTION' '(' ')' '{' '}' {
  }
  | 'FUNCTION' '(' ')' '{' FunctionBody '}' {
  }
  | 'FUNCTION' '(' FormalParameters ')' '{' '}' {
  }
  | 'FUNCTION' '(' FormalParameters ')' '{' FunctionBody '}' {
  }
  ;

CoverParenthesizedExpressionAndArrowParameterList
  : '(' Expression_In ')'
  | '(' ')'
  | '(' '...' BindingIdentifier ')'
  | '(' '...' BindingPattern ')'
  | '(' 'Expression_In' ',' '...' BindingIdentifier ')'
  | '(' 'Expression_In' ',' '...' BindingPattern ')'
  ;

FunctionExpression
  : 'function' '(' ')' '{' '}'
  | 'function' BindingIdentifier '(' ')' '{' '}'
  | 'function' '(' ')' '{' FunctionBody '}'
  | 'function' BindingIdentifier '(' ')' '{' FunctionBody '}'
  | 'function' '(' FormalParameters ')' '{' '}'
  | 'function' BindingIdentifier '(' FormalParameters ')' '{' '}'
  | 'function' '(' FormalParameters ')' '{' FunctionBody '}'
  | 'function' BindingIdentifier '(' FormalParameters ')' '{' FunctionBody '}'
  ;

FunctionBody
  : FunctionStatementList
  ;

FunctionStatementList
  : StatementList_Return
  ;

BindingIdentifier
  : Identifier
  ;

FormalParameters
  : FormalParameterList
  ;

FormalParameterList
  : FunctionRestParameter
  | FormalsList
  | FormalsList ',' FunctionRestParameter
  ;

FormalsList
  : FormalParameter
  | FormalsList ',' FormalParameter
  ;

FunctionRestParameter
  : BindingRestElement
  ;

FormalParameter
  : BindingElement
  ;

BindingRestElement
  : '...' BindingIdentifier
  | '...' BindingPattern
  ;

BindingElement
  : SingleNameBinding
  | BindingPattern Initializer_In
  | BindingPattern
  ;

SingleNameBinding
  : BindingIdentifier Initializer_In {
  }
  | BindingIdentifier
  ;

BindingPattern
  : ObjectBindingPattern
  | ArrayBindingPattern
  ;

ObjectBindingPattern
  : 'BLOCK_START' '}'
  | 'BLOCK_START' BindingPropertyList '}'
  | 'BLOCK_START' BindingPropertyList ',' '}'
  ;

BindingPropertyList
  : BindingProperty
  | BindingPropertyList ',' BindingProperty
  ;

BindingProperty
  : SingleNameBinding
  | PropertyName ':' BindingElement
  ;

ArrayBindingPattern
  : '[' ']'
  | '[' Elision ']'
  | '[' BindingRestElement ']'
  | '[' Elision BindingRestElement ']'
  | '[' BindingElementList ']'
  | '[' BindingElementList ',' BindingRestElement ']'
  | '[' BindingElementList ',' Elision BindingRestElement ']'
  | '[' BindingElementList ',' Elision ']'
  ;

BindingElementList
  : BindingElisionElement
  | BindingElementList ',' BindingElisionElement
  ;

BindingElisionElement
  : BindingElement
  | Elision BindingElement
  ;

TryStatement
  : 'try' Block Catch
  | 'try' Block Finally
  | 'try' Block Catch Finally
  ;

TryStatement_Return
  : 'try' Block_Return Catch_Return
  | 'try' Block_Return Finally_Return
  | 'try' Block_Return Catch_Return Finally_Return
  ;

Catch
  : 'catch' '(' CatchParameter ')' Block
  ;

Catch_Return
  : 'catch' '(' CatchParameter ')' Block_Return
  ;

Finally
  : 'finally' Block
  ;

Finally_Return
  : 'finally' Block_Return
  ;

CatchParameter
  : BindingIdentifier
  | BindingPattern
  ;
{}

{
  ;
}

{ a: 1; }
{ a: 1 }

{
  var a = 100;
  let c, d = 1;
}

if (a) {}

if (true) {

}

if (exp) {

} else {
  console.log('hello');
}

if (a) {


} else if(b) {
} else {
  ;
}

do {
  ;
} while (exp);


while (i < 100) {
  i++;
}

for (let a = 1; a < 10; i++) {

}

for (var i = 100, j = 0; i >= 0; --i) {

}

for (var i = 0; ;) {

}

for (var i = 0; i; ) {

}

for (var i = 0; ; i) {

}

for (i in [1,2,'a']) {

}

for (let a in [a,b,c]) {

}

for (a of [1,2,3]) {

}

for (var a of []) {

}

for (let b of []) {

}

for (a; b; c)
  ;

for (a ; ; c) {

}

for (a ; ; ) {

}

for (; a;) {

}

for ( ; ; ) {

}

for (; exp ; ) {

}

switch(cond) {

}

switch(cond) {
  case 1: {
    break;
  }
}

switch(cond + 1) {
  case a: {
    console.log(a);
    break;
  }
  default:
    foo;
    break;
}

with(obj) {
  ;
}

with(obj)
  ;
;

throw new Error();

throw (function(a, b) {});

try {

} catch(ex) {
  ;
}

function foo() {
  return {
    name: 'test',
  }
}

function foo() {
  if (true) {
    return;
  }
}

(function dartProgram(){function copyProperties(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
b[r]=a[r]}}function mixinPropertiesHard(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
if(!b.hasOwnProperty(r)){b[r]=a[r]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var t=function(){}
t.prototype={p:{}}
var s=new t()
if(!(Object.getPrototypeOf(s)&&Object.getPrototypeOf(s).p===t.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var r=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(r))return true}}catch(q){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var t=Object.create(b.prototype)
copyProperties(a.prototype,t)
a.prototype=t}}function inheritMany(a,b){for(var t=0;t<b.length;t++){inherit(b[t],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){var s=d()
if(a[b]!==t){A.eV(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.C(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.c6(b)
return new t(c,this)}:function(){if(t===null)t=A.c6(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.c6(a).prototype
return t}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var t=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var s=staticTearOffGetter(t)
a[b]=s}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var t=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var s=instanceTearOffGetter(c,t)
a[b]=s}function setOrUpdateInterceptorsByTag(a){var t=v.interceptorsByTag
if(!t){v.interceptorsByTag=a
return}copyProperties(a,t)}function setOrUpdateLeafTags(a){var t=v.leafTags
if(!t){v.leafTags=a
return}copyProperties(a,t)}function updateTypes(a){var t=v.types
var s=t.length
t.push.apply(t,a)
return s}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var t=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},s=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:t(0,0,null,["$0"],0),_instance_1u:t(0,1,null,["$1"],0),_instance_2u:t(0,2,null,["$2"],0),_instance_0i:t(1,0,null,["$0"],0),_instance_1i:t(1,1,null,["$1"],0),_instance_2i:t(1,2,null,["$2"],0),_static_0:s(0,null,["$0"],0),_static_1:s(1,null,["$1"],0),_static_2:s(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
cb(a,b,c,d){return{i:a,p:b,e:c,x:d}},
c8(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.c9==null){A.eJ()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.d(A.cw("Return interceptor for "+A.n(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.bB
if(p==null)p=$.bB=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.eO(a)
if(q!=null)return q
if(typeof a=="function")return B.r
t=Object.getPrototypeOf(a)
if(t==null)return B.j
if(t===Object.prototype)return B.j
if(typeof r=="function"){p=$.bB
if(p==null)p=$.bB=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.f,enumerable:false,writable:true,configurable:true})
return B.f}return B.f},
U(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.ad.prototype
return J.aT.prototype}if(typeof a=="string")return J.a1.prototype
if(a==null)return J.ae.prototype
if(typeof a=="boolean")return J.aS.prototype
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.J.prototype
if(typeof a=="symbol")return J.ai.prototype
if(typeof a=="bigint")return J.ag.prototype
return a}if(a instanceof A.k)return a
return J.c8(a)},
cW(a){if(typeof a=="string")return J.a1.prototype
if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.J.prototype
if(typeof a=="symbol")return J.ai.prototype
if(typeof a=="bigint")return J.ag.prototype
return a}if(a instanceof A.k)return a
return J.c8(a)},
bN(a){if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.J.prototype
if(typeof a=="symbol")return J.ai.prototype
if(typeof a=="bigint")return J.ag.prototype
return a}if(a instanceof A.k)return a
return J.c8(a)},
eF(a){if(a==null)return a
if(!(a instanceof A.k))return J.a7.prototype
return a},
Y(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.U(a).F(a,b)},
bj(a,b){if(typeof b==="number")if(Array.isArray(a)||A.eM(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.bN(a).A(a,b)},
cd(a,b,c){return J.bN(a).k(a,b,c)},
df(a,b){return J.eF(a).S(a,b)},
bV(a){return J.U(a).gn(a)},
dg(a){return J.bN(a).ga5(a)},
dh(a){return J.bN(a).gu(a)},
ce(a){return J.cW(a).gj(a)},
di(a){return J.U(a).gl(a)},
aG(a){return J.U(a).h(a)},
aQ:function aQ(){},
aS:function aS(){},
ae:function ae(){},
ah:function ah(){},
K:function K(){},
b5:function b5(){},
a7:function a7(){},
J:function J(){},
ag:function ag(){},
ai:function ai(){},
t:function t(a){this.$ti=a},
aR:function aR(){},
bp:function bp(a){this.$ti=a},
Z:function Z(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
af:function af(){},
ad:function ad(){},
aT:function aT(){},
a1:function a1(){}},A={bX:function bX(){},
dy(a){return new A.a2("Field '"+a+"' has not been initialized.")},
dx(a){return new A.a2("Field '"+a+"' has already been initialized.")},
ca(a){var t,s
for(t=$.z.length,s=0;s<t;++s)if(a===$.z[s])return!0
return!1},
a2:function a2(a){this.a=a},
ac:function ac(){},
P:function P(){},
a3:function a3(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
r:function r(){},
d1(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
eM(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
n(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.aG(a)
return t},
b6(a){var t,s=$.cr
if(s==null)s=$.cr=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
b7(a){var t,s,r,q
if(a instanceof A.k)return A.y(A.aF(a),null)
t=J.U(a)
if(t===B.q||t===B.t||u.o.b(a)){s=B.h(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.y(A.aF(a),null)},
dC(a){var t,s,r
if(typeof a=="number"||A.bL(a))return J.aG(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.I)return a.h(0)
t=$.de()
for(s=0;s<1;++s){r=t[s].al(a)
if(r!=null)return r}return"Instance of '"+A.b7(a)+"'"},
p(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.e.a_(t,10)|55296)>>>0,t&1023|56320)}throw A.d(A.by(a,0,1114111,null,null))},
q(a,b){if(a==null)J.ce(a)
throw A.d(A.cV(a,b))},
cV(a,b){var t,s="index"
if(!A.cP(b))return new A.H(!0,b,s,null)
t=J.ce(a)
if(b<0||b>=t)return A.cm(b,t,a,s)
return new A.ar(null,null,!0,b,s,"Value not in range")},
eB(a){return new A.H(!0,a,null,null)},
d(a){return A.o(a,new Error())},
o(a,b){var t
if(a==null)a=new A.au()
b.dartException=a
t=A.eW
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
eW(){return J.aG(this.dartException)},
bU(a,b){throw A.o(a,b==null?new Error():b)},
d0(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.bU(A.e9(a,b,c),t)},
e9(a,b,c){var t,s,r,q,p,o,n,m,l
if(typeof b=="string")t=b
else{s="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
r=s.length
q=b
if(q>r){c=q/r|0
q%=r}t=s[q]}p=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
o=u.j.b(a)?"list":"ByteData"
n=a.$flags|0
m="a "
if((n&4)!==0)l="constant "
else if((n&2)!==0){l="unmodifiable "
m="an "}else l=(n&1)!==0?"fixed-length ":""
return new A.be("'"+t+"': Cannot "+p+" "+m+l+o)},
eU(a){throw A.d(A.aM(a))},
F(a){var t,s,r,q,p,o
a=A.eT(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.C([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.bz(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
bA(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
cv(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
bY(a,b){var t=b==null,s=t?null:b.method
return new A.aU(a,s,t?null:b.receiver)},
d2(a){if(a==null)return new A.bx(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.X(a,a.dartException)
return A.eA(a)},
X(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
eA(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.e.a_(s,16)&8191)===10)switch(r){case 438:return A.X(a,A.bY(A.n(t)+" (Error "+r+")",null))
case 445:case 5007:A.n(t)
return A.X(a,new A.aq())}}if(a instanceof TypeError){q=$.d4()
p=$.d5()
o=$.d6()
n=$.d7()
m=$.da()
l=$.db()
k=$.d9()
$.d8()
j=$.dd()
i=$.dc()
h=q.v(t)
if(h!=null)return A.X(a,A.bY(A.R(t),h))
else{h=p.v(t)
if(h!=null){h.method="call"
return A.X(a,A.bY(A.R(t),h))}else if(o.v(t)!=null||n.v(t)!=null||m.v(t)!=null||l.v(t)!=null||k.v(t)!=null||n.v(t)!=null||j.v(t)!=null||i.v(t)!=null){A.R(t)
return A.X(a,new A.aq())}}return A.X(a,new A.bd(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.at()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.X(a,new A.H(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.at()
return a},
eR(a){if(a==null)return J.bV(a)
if(typeof a=="object")return A.b6(a)
return J.bV(a)},
eE(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.k(0,a[t],a[s])}return b},
dq(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.ba().constructor.prototype):Object.create(new A.a_(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.ck(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.dl(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.ck(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
dl(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.d("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.dj)}throw A.d("Error in functionType of tearoff")},
dm(a,b,c,d){var t=A.cj
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
ck(a,b,c,d){if(c)return A.dp(a,b,d)
return A.dm(b.length,d,a,b)},
dn(a,b,c,d){var t=A.cj,s=A.dk
switch(b?-1:a){case 0:throw A.d(new A.b8("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
dp(a,b,c){var t,s
if($.ch==null)$.ch=A.cg("interceptor")
if($.ci==null)$.ci=A.cg("receiver")
t=b.length
s=A.dn(t,c,a,b)
return s},
c6(a){return A.dq(a)},
dj(a,b){return A.bH(v.typeUniverse,A.aF(a.a),b)},
cj(a){return a.a},
dk(a){return a.b},
cg(a){var t,s,r,q=new A.a_("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.d(A.cf("Field name "+a+" not found."))},
cX(a){return v.getIsolateTag(a)},
eO(a){var t,s,r,q,p,o=A.R($.cY.$1(a)),n=$.bM[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.bR[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.c4($.cT.$2(a,o))
if(r!=null){n=$.bM[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.bR[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.bT(t)
$.bM[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.bR[o]=t
return t}if(q==="-"){p=A.bT(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.cZ(a,t)
if(q==="*")throw A.d(A.cw(o))
if(v.leafTags[o]===true){p=A.bT(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.cZ(a,t)},
cZ(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.cb(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
bT(a){return J.cb(a,!1,null,!!a.$iv)},
eQ(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.bT(t)
else return J.cb(t,c,null,null)},
eJ(){if(!0===$.c9)return
$.c9=!0
A.eK()},
eK(){var t,s,r,q,p,o,n,m
$.bM=Object.create(null)
$.bR=Object.create(null)
A.eI()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.d_.$1(p)
if(o!=null){n=A.eQ(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
eI(){var t,s,r,q,p,o,n=B.k()
n=A.a9(B.l,A.a9(B.m,A.a9(B.i,A.a9(B.i,A.a9(B.n,A.a9(B.o,A.a9(B.p(B.h),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.cY=new A.bO(q)
$.cT=new A.bP(p)
$.d_=new A.bQ(o)},
a9(a,b){return a(b)||b},
eD(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
eT(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
as:function as(){},
bz:function bz(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
aq:function aq(){},
aU:function aU(a,b,c){this.a=a
this.b=b
this.c=c},
bd:function bd(a){this.a=a},
bx:function bx(a){this.a=a},
I:function I(){},
aJ:function aJ(){},
bb:function bb(){},
ba:function ba(){},
a_:function a_(a,b){this.a=a
this.b=b},
b8:function b8(a){this.a=a},
E:function E(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
bq:function bq(a){this.a=a},
bu:function bu(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
O:function O(a,b){this.a=a
this.$ti=b},
aW:function aW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bO:function bO(a){this.a=a},
bP:function bP(a){this.a=a},
bQ:function bQ(a){this.a=a},
a4:function a4(){},
an:function an(){},
aX:function aX(){},
a5:function a5(){},
al:function al(){},
am:function am(){},
aY:function aY(){},
aZ:function aZ(){},
b_:function b_(){},
b0:function b0(){},
b1:function b1(){},
b2:function b2(){},
b3:function b3(){},
ao:function ao(){},
b4:function b4(){},
av:function av(){},
aw:function aw(){},
ax:function ax(){},
ay:function ay(){},
c0(a,b){var t=b.c
return t==null?b.c=A.aB(a,"cl",[b.x]):t},
cs(a){var t=a.w
if(t===6||t===7)return A.cs(a.x)
return t===11||t===12},
dE(a){return a.as},
c7(a){return A.bG(v.typeUniverse,a,!1)},
S(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.S(a0,t,a2,a3)
if(s===t)return a1
return A.cF(a0,s,!0)
case 7:t=a1.x
s=A.S(a0,t,a2,a3)
if(s===t)return a1
return A.cE(a0,s,!0)
case 8:r=a1.y
q=A.a8(a0,r,a2,a3)
if(q===r)return a1
return A.aB(a0,a1.x,q)
case 9:p=a1.x
o=A.S(a0,p,a2,a3)
n=a1.y
m=A.a8(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.c1(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.a8(a0,k,a2,a3)
if(j===k)return a1
return A.cG(a0,l,j)
case 11:i=a1.x
h=A.S(a0,i,a2,a3)
g=a1.y
f=A.ex(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.cD(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.a8(a0,e,a2,a3)
p=a1.x
o=A.S(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.c2(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.d(A.aI("Attempted to substitute unexpected RTI kind "+a))}},
a8(a,b,c,d){var t,s,r,q,p=b.length,o=A.bI(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.S(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
ey(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.bI(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.S(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
ex(a,b,c,d){var t,s=b.a,r=A.a8(a,s,c,d),q=b.b,p=A.a8(a,q,c,d),o=b.c,n=A.ey(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.bg()
t.a=r
t.b=p
t.c=n
return t},
C(a,b){a[v.arrayRti]=b
return a},
cU(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.eH(t)
return a.$S()}return null},
eL(a,b){var t
if(A.cs(b))if(a instanceof A.I){t=A.cU(a)
if(t!=null)return t}return A.aF(a)},
aF(a){if(a instanceof A.k)return A.x(a)
if(Array.isArray(a))return A.aD(a)
return A.c5(J.U(a))},
aD(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
x(a){var t=a.$ti
return t!=null?t:A.c5(a)},
c5(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.eg(a,t)},
eg(a,b){var t=a instanceof A.I?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.e_(v.typeUniverse,t.name)
b.$ccache=s
return s},
eH(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.bG(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
eG(a){return A.T(A.x(a))},
ew(a){var t=a instanceof A.I?A.cU(a):null
if(t!=null)return t
if(u.R.b(a))return J.di(a).a
if(Array.isArray(a))return A.aD(a)
return A.aF(a)},
T(a){var t=a.r
return t==null?a.r=new A.bF(a):t},
D(a){return A.T(A.bG(v.typeUniverse,a,!1))},
ef(a){var t=this
t.b=A.ev(t)
return t.b(a)},
ev(a){var t,s,r,q,p
if(a===u.K)return A.em
if(A.V(a))return A.eq
t=a.w
if(t===6)return A.ed
if(t===1)return A.cR
if(t===7)return A.eh
s=A.eu(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.V)){a.f="$i"+r
if(r==="f")return A.ek
if(a===u.m)return A.ej
return A.ep}}else if(t===10){q=A.eD(a.x,a.y)
p=q==null?A.cR:q
return p==null?A.cL(p):p}return A.eb},
eu(a){if(a.w===8){if(a===u.S)return A.cP
if(a===u.i||a===u.H)return A.el
if(a===u.N)return A.eo
if(a===u.y)return A.bL}return null},
ee(a){var t=this,s=A.ea
if(A.V(t))s=A.e6
else if(t===u.K)s=A.cL
else if(A.aa(t)){s=A.ec
if(t===u.w)s=A.e3
else if(t===u.v)s=A.c4
else if(t===u.u)s=A.e1
else if(t===u.n)s=A.cK
else if(t===u.I)s=A.e2
else if(t===u.A)s=A.e5}else if(t===u.S)s=A.bJ
else if(t===u.N)s=A.R
else if(t===u.y)s=A.c3
else if(t===u.H)s=A.cJ
else if(t===u.i)s=A.N
else if(t===u.m)s=A.e4
t.a=s
return t.a(a)},
eb(a){var t=this
if(a==null)return A.aa(t)
return A.eN(v.typeUniverse,A.eL(a,t),t)},
ed(a){if(a==null)return!0
return this.x.b(a)},
ep(a){var t,s=this
if(a==null)return A.aa(s)
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.U(a)[t]},
ek(a){var t,s=this
if(a==null)return A.aa(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.U(a)[t]},
ej(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.k)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
cQ(a){if(typeof a=="object"){if(a instanceof A.k)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
ea(a){var t=this
if(a==null){if(A.aa(t))return a}else if(t.b(a))return a
throw A.o(A.cM(a,t),new Error())},
ec(a){var t=this
if(a==null||t.b(a))return a
throw A.o(A.cM(a,t),new Error())},
cM(a,b){return new A.az("TypeError: "+A.cx(a,A.y(b,null)))},
cx(a,b){return A.aO(a)+": type '"+A.y(A.ew(a),null)+"' is not a subtype of type '"+b+"'"},
A(a,b){return new A.az("TypeError: "+A.cx(a,b))},
eh(a){var t=this
return t.x.b(a)||A.c0(v.typeUniverse,t).b(a)},
em(a){return a!=null},
cL(a){if(a!=null)return a
throw A.o(A.A(a,"Object"),new Error())},
eq(a){return!0},
e6(a){return a},
cR(a){return!1},
bL(a){return!0===a||!1===a},
c3(a){if(!0===a)return!0
if(!1===a)return!1
throw A.o(A.A(a,"bool"),new Error())},
e1(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.o(A.A(a,"bool?"),new Error())},
N(a){if(typeof a=="number")return a
throw A.o(A.A(a,"double"),new Error())},
e2(a){if(typeof a=="number")return a
if(a==null)return a
throw A.o(A.A(a,"double?"),new Error())},
cP(a){return typeof a=="number"&&Math.floor(a)===a},
bJ(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.o(A.A(a,"int"),new Error())},
e3(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.o(A.A(a,"int?"),new Error())},
el(a){return typeof a=="number"},
cJ(a){if(typeof a=="number")return a
throw A.o(A.A(a,"num"),new Error())},
cK(a){if(typeof a=="number")return a
if(a==null)return a
throw A.o(A.A(a,"num?"),new Error())},
eo(a){return typeof a=="string"},
R(a){if(typeof a=="string")return a
throw A.o(A.A(a,"String"),new Error())},
c4(a){if(typeof a=="string")return a
if(a==null)return a
throw A.o(A.A(a,"String?"),new Error())},
e4(a){if(A.cQ(a))return a
throw A.o(A.A(a,"JSObject"),new Error())},
e5(a){if(a==null)return a
if(A.cQ(a))return a
throw A.o(A.A(a,"JSObject?"),new Error())},
cS(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.y(a[r],b)
return t},
et(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.cS(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.y(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
cN(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.C([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.m(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.q(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.y(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.y(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.y(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.y(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.y(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
y(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.y(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.y(a.x,b)+">"
if(m===8){q=A.ez(a.x)
p=a.y
return p.length>0?q+("<"+A.cS(p,b)+">"):q}if(m===10)return A.et(a,b)
if(m===11)return A.cN(a,b,null)
if(m===12)return A.cN(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.q(b,o)
return b[o]}return"?"},
ez(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
e0(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
e_(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.bG(a,b,!1)
else if(typeof n=="number"){t=n
s=A.aC(a,5,"#")
r=A.bI(t)
for(q=0;q<t;++q)r[q]=s
p=A.aB(a,b,r)
o[b]=p
return p}else return n},
dY(a,b){return A.cH(a.tR,b)},
dX(a,b){return A.cH(a.eT,b)},
bG(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.cB(A.cz(a,null,b,!1))
s.set(b,t)
return t},
bH(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.cB(A.cz(a,b,c,!0))
r.set(c,s)
return s},
dZ(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.c1(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
M(a,b){b.a=A.ee
b.b=A.ef
return b},
aC(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.B(null,null)
t.w=b
t.as=c
s=A.M(a,t)
a.eC.set(c,s)
return s},
cF(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.dV(a,b,s,c)
a.eC.set(s,t)
return t},
dV(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.V(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aa(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.B(null,null)
r.w=6
r.x=b
r.as=c
return A.M(a,r)},
cE(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.dT(a,b,s,c)
a.eC.set(s,t)
return t},
dT(a,b,c,d){var t,s
if(d){t=b.w
if(A.V(b)||b===u.K)return b
else if(t===1)return A.aB(a,"cl",[b])
else if(b===u.P||b===u.T)return u.O}s=new A.B(null,null)
s.w=7
s.x=b
s.as=c
return A.M(a,s)},
dW(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.B(null,null)
t.w=13
t.x=b
t.as=r
s=A.M(a,t)
a.eC.set(r,s)
return s},
aA(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
dS(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
aB(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.aA(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.B(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.M(a,s)
a.eC.set(q,r)
return r},
c1(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.aA(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.B(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.M(a,p)
a.eC.set(r,o)
return o},
cG(a,b,c){var t,s,r="+"+(b+"("+A.aA(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.B(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.M(a,t)
a.eC.set(r,s)
return s},
cD(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.aA(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.aA(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.dS(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.B(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.M(a,q)
a.eC.set(s,p)
return p},
c2(a,b,c,d){var t,s=b.as+("<"+A.aA(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.dU(a,b,c,s,d)
a.eC.set(s,t)
return t},
dU(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.bI(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.S(a,b,s,0)
n=A.a8(a,c,s,0)
return A.c2(a,o,n,c!==n)}}m=new A.B(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.M(a,m)},
cz(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
cB(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.dN(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.cA(a,s,m,l,!1)
else if(r===46)s=A.cA(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.Q(a.u,a.e,l.pop()))
break
case 94:l.push(A.dW(a.u,l.pop()))
break
case 35:l.push(A.aC(a.u,5,"#"))
break
case 64:l.push(A.aC(a.u,2,"@"))
break
case 126:l.push(A.aC(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.dP(a,l)
break
case 38:A.dO(a,l)
break
case 63:q=a.u
l.push(A.cF(q,A.Q(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.cE(q,A.Q(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.dM(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.cC(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.dR(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-2)
break
case 43:o=m.indexOf("(",s)
l.push(m.substring(s,o))
l.push(-4)
l.push(a.p)
a.p=l.length
s=o+1
break
default:throw"Bad character "+r}}}n=l.pop()
return A.Q(a.u,a.e,n)},
dN(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
cA(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.e0(t,p.x)[q]
if(o==null)A.bU('No "'+q+'" in "'+A.dE(p)+'"')
d.push(A.bH(t,p,o))}else d.push(q)
return n},
dP(a,b){var t,s=a.u,r=A.cy(a,b),q=b.pop()
if(typeof q=="string")b.push(A.aB(s,q,r))
else{t=A.Q(s,a.e,q)
switch(t.w){case 11:b.push(A.c2(s,t,r,a.n))
break
default:b.push(A.c1(s,t,r))
break}}},
dM(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.cy(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.Q(q,a.e,p)
r=new A.bg()
r.a=t
r.b=o
r.c=n
b.push(A.cD(q,s,r))
return
case-4:b.push(A.cG(q,b.pop(),t))
return
default:throw A.d(A.aI("Unexpected state under `()`: "+A.n(p)))}},
dO(a,b){var t=b.pop()
if(0===t){b.push(A.aC(a.u,1,"0&"))
return}if(1===t){b.push(A.aC(a.u,4,"1&"))
return}throw A.d(A.aI("Unexpected extended operation "+A.n(t)))},
cy(a,b){var t=b.splice(a.p)
A.cC(a.u,a.e,t)
a.p=b.pop()
return t},
Q(a,b,c){if(typeof c=="string")return A.aB(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.dQ(a,b,c)}else return c},
cC(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.Q(a,b,c[t])},
dR(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.Q(a,b,c[t])},
dQ(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.d(A.aI("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.d(A.aI("Bad index "+c+" for "+b.h(0)))},
eN(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.m(a,b,null,c,null)
s.set(c,t)}return t},
m(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.V(d))return!0
t=b.w
if(t===4)return!0
if(A.V(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.m(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.m(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.m(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.m(a,b.x,c,d,e))return!1
return A.m(a,A.c0(a,b),c,d,e)}if(t===6)return A.m(a,q,c,d,e)&&A.m(a,b.x,c,d,e)
if(r===7){if(A.m(a,b,c,d.x,e))return!0
return A.m(a,b,c,A.c0(a,d),e)}if(r===6)return A.m(a,b,c,q,e)||A.m(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.L)return!0
if(r===12){if(b===u.g)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.m(a,k,c,j,e)||!A.m(a,j,e,k,c))return!1}return A.cO(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.cO(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.ei(a,b,c,d,e)}if(p&&r===10)return A.en(a,b,c,d,e)
return!1},
cO(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.m(a2,a3.x,a4,a5.x,a6))return!1
t=a3.y
s=a5.y
r=t.a
q=s.a
p=r.length
o=q.length
if(p>o)return!1
n=o-p
m=t.b
l=s.b
k=m.length
j=l.length
if(p+k<o+j)return!1
for(i=0;i<p;++i){h=r[i]
if(!A.m(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.m(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.m(a2,l[i],a6,h,a4))return!1}g=t.c
f=s.c
e=g.length
d=f.length
for(c=0,b=0;b<d;b+=3){a=f[b]
for(;;){if(c>=e)return!1
a0=g[c]
c+=3
if(a<a0)return!1
a1=g[c-2]
if(a0<a){if(a1)return!1
continue}h=f[b+1]
if(a1&&!h)return!1
h=g[c-1]
if(!A.m(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
ei(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bH(a,b,s[p])
return A.cI(a,q,null,c,d.y,e)}return A.cI(a,b.y,null,c,d.y,e)},
cI(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.m(a,b[t],d,e[t],f))return!1
return!0},
en(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.m(a,s[t],c,r[t],e))return!1
return!0},
aa(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.V(a))if(t!==6)s=t===7&&A.aa(a.x)
return s},
V(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
cH(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
bI(a){return a>0?new Array(a):v.typeUniverse.sEA},
B:function B(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
bg:function bg(){this.c=this.b=this.a=null},
bF:function bF(a){this.a=a},
bf:function bf(){},
az:function az(a){this.a=a},
bZ(a,b){return new A.E(a.i("@<0>").H(b).i("E<1,2>"))},
ak(a,b,c){return b.i("@<0>").H(c).i("cp<1,2>").a(A.eE(a,new A.E(b.i("@<0>").H(c).i("E<1,2>"))))},
c_(a,b){return new A.E(a.i("@<0>").H(b).i("E<1,2>"))},
dz(a,b,c){var t=A.bZ(b,c)
a.B(0,new A.bv(t,b,c))
return t},
dA(a,b,c){var t=A.bZ(b,c)
t.S(0,a)
return t},
cq(a){var t,s
if(A.ca(a))return"{...}"
t=new A.a6("")
try{s={}
B.a.m($.z,a)
t.a+="{"
s.a=!0
a.B(0,new A.bw(s,t))
t.a+="}"}finally{if(0>=$.z.length)return A.q($.z,-1)
$.z.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
bv:function bv(a,b,c){this.a=a
this.b=b
this.c=c},
h:function h(){},
w:function w(){},
bw:function bw(a,b){this.a=a
this.b=b},
es(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.d2(s)
r=A.bo(String(t))
throw A.d(r)}r=A.bK(q)
return r},
bK(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.bh(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.bK(a[t])
return a},
co(a,b,c){return new A.aj(a,b)},
e8(a){return a.ap()},
dK(a,b){return new A.bC(a,[],A.eC())},
dL(a,b,c){var t,s=new A.a6(""),r=A.dK(s,b)
r.L(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
bh:function bh(a,b){this.a=a
this.b=b
this.c=null},
bi:function bi(a){this.a=a},
aK:function aK(){},
aN:function aN(){},
aj:function aj(a,b){this.a=a
this.b=b},
aV:function aV(a,b){this.a=a
this.b=b},
br:function br(){},
bt:function bt(a){this.b=a},
bs:function bs(a){this.a=a},
bD:function bD(){},
bE:function bE(a,b){this.a=a
this.b=b},
bC:function bC(a,b,c){this.c=a
this.a=b
this.b=c},
dB(a,b,c){var t,s
if(a<0||a>4294967295)A.bU(A.by(a,0,4294967295,"length",null))
t=A.C(new Array(a),c.i("t<0>"))
t.$flags=1
s=t
return s},
cu(a,b,c){var t=J.dh(b)
if(!t.p())return a
if(c.length===0){do a+=A.n(t.gq())
while(t.p())}else{a+=A.n(t.gq())
while(t.p())a=a+c+A.n(t.gq())}return a},
aO(a){if(typeof a=="number"||A.bL(a)||a==null)return J.aG(a)
if(typeof a=="string")return JSON.stringify(a)
return A.dC(a)},
aI(a){return new A.aH(a)},
cf(a){return new A.H(!1,null,null,a)},
by(a,b,c,d,e){return new A.ar(b,c,!0,a,d,"Invalid value")},
dD(a,b,c){if(a>c)throw A.d(A.by(a,0,c,"start",null))
if(a>b||b>c)throw A.d(A.by(b,a,c,"end",null))
return b},
cm(a,b,c,d){return new A.aP(b,!0,a,d,"Index out of range")},
cw(a){return new A.bc(a)},
ct(a){return new A.b9(a)},
aM(a){return new A.aL(a)},
bo(a){return new A.bn(a)},
dw(a,b,c){var t,s
if(A.ca(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.C([],u.s)
B.a.m($.z,a)
try{A.er(a,t)}finally{if(0>=$.z.length)return A.q($.z,-1)
$.z.pop()}s=A.cu(b,u.U.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
cn(a,b,c){var t,s
if(A.ca(a))return b+"..."+c
t=new A.a6(b)
B.a.m($.z,a)
try{s=t
s.a=A.cu(s.a,a,", ")}finally{if(0>=$.z.length)return A.q($.z,-1)
$.z.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
er(a,b){var t,s,r,q,p,o,n,m=a.gu(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.p())return
t=A.n(m.gq())
B.a.m(b,t)
l+=t.length+2;++k}if(!m.p()){if(k<=5)return
if(0>=b.length)return A.q(b,-1)
s=b.pop()
if(0>=b.length)return A.q(b,-1)
r=b.pop()}else{q=m.gq();++k
if(!m.p()){if(k<=4){B.a.m(b,A.n(q))
return}s=A.n(q)
if(0>=b.length)return A.q(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gq();++k
for(;m.p();q=p,p=o){o=m.gq();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.q(b,-1)
l-=b.pop().length+2;--k}B.a.m(b,"...")
return}}r=A.n(q)
s=A.n(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.q(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.m(b,n)
B.a.m(b,r)
B.a.m(b,s)},
j:function j(){},
aH:function aH(a){this.a=a},
au:function au(){},
H:function H(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ar:function ar(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
aP:function aP(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
be:function be(a){this.a=a},
bc:function bc(a){this.a=a},
b9:function b9(a){this.a=a},
aL:function aL(a){this.a=a},
at:function at(){},
bn:function bn(a){this.a=a},
c:function c(){},
ap:function ap(){},
k:function k(){},
a6:function a6(a){this.a=a},
eS(a){var t,s,r,q,p,o,n,m=A.bW(a),l=new A.ab(m),k=A.bW(a),j=u.t,i=A.C([],j),h=A.C([],j),g=A.C([],j)
j=m.x
j===$&&A.u()
t=m.w
t===$&&A.u()
s=[j,j+t,j+t*2+2]
for(j=u.N,t=u.z,r=0,q=0;q<=6e4;q+=20){if(q>0)l.a0(20)
p=q/1000
B.a.m(i,A.ak(["t",p,"target",k.t(p)],j,t))
B.a.m(h,A.ak(["t",m.z,"target",m.t(m.Q)],j,t))
if(r<3&&m.z+1e-8>=s[r]){o=l.K()
if(o!=null){B.a.m(g,o)
p=A.ak(["t",m.z,"target",m.t(m.Q)],j,t)
n=A.bZ(j,t)
n.S(0,p)
n.k(0,"phase","after")
B.a.m(h,n)}++r}}m=m.y
m===$&&A.u()
return A.ak(["ok",!0,"duration",60,"baseline",i,"actual",h,"events",g,"rewind",m],j,t)},
eP(){var t,s=v.G.globalThis,r=new A.bS(A.c_(u.N,u.a))
if(typeof r=="function")A.bU(A.cf("Attempting to rewrap a JS function."))
t=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.e7,r)
t[$.cc()]=r
s.untouchSpeedHelp=t},
ab:function ab(a){this.a=a},
bS:function bS(a){this.a=a},
bW(a){var t=new A.bk()
t.a9(a)
return t},
bk:function bk(){var _=this
_.y=_.x=_.w=_.r=_.f=_.e=_.d=_.c=_.b=_.a=$
_.as=_.Q=_.z=0
_.at=-100
_.cx=_.CW=_.ch=_.ay=0},
bm:function bm(a){this.a=a},
bl:function bl(a){this.a=a},
eV(a){throw A.o(new A.a2("Field '"+a+"' has been assigned during initialization."),new Error())},
u(){throw A.o(A.dy(""),new Error())},
G(){throw A.o(A.dx(""),new Error())},
e7(a,b,c){u.Z.a(a)
if(A.bJ(c)>=1)return a.$1(b)
return a.$0()}},B={}
var w=[A,J,B]
var $={}
A.bX.prototype={}
J.aQ.prototype={
F(a,b){return a===b},
gn(a){return A.b6(a)},
h(a){return"Instance of '"+A.b7(a)+"'"},
gl(a){return A.T(A.c5(this))}}
J.aS.prototype={
h(a){return String(a)},
gn(a){return a?519018:218159},
gl(a){return A.T(u.y)},
$ie:1,
$iaE:1}
J.ae.prototype={
F(a,b){return null==b},
h(a){return"null"},
gn(a){return 0},
$ie:1}
J.ah.prototype={$il:1}
J.K.prototype={
gn(a){return 0},
h(a){return String(a)}}
J.b5.prototype={}
J.a7.prototype={}
J.J.prototype={
h(a){var t=a[$.d3()]
if(t==null)t=a[$.cc()]
if(t==null)return this.a8(a)
return"JavaScript function for "+J.aG(t)},
$ia0:1}
J.ag.prototype={
gn(a){return 0},
h(a){return String(a)}}
J.ai.prototype={
gn(a){return 0},
h(a){return String(a)}}
J.t.prototype={
m(a,b){A.aD(a).c.a(b)
a.$flags&1&&A.d0(a,29)
a.push(b)},
ga5(a){return a.length!==0},
h(a){return A.cn(a,"[","]")},
gu(a){return new J.Z(a,a.length,A.aD(a).i("Z<1>"))},
gn(a){return A.b6(a)},
gj(a){return a.length},
k(a,b,c){var t
A.aD(a).c.a(c)
a.$flags&2&&A.d0(a)
t=a.length
if(b>=t)throw A.d(A.cV(a,b))
a[b]=c},
$ic:1,
$if:1}
J.aR.prototype={
al(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.b7(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.bp.prototype={}
J.Z.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
p(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.eU(r)
throw A.d(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0}}
J.af.prototype={
T(a,b){var t
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gV(b)
if(this.gV(a)===t)return 0
if(this.gV(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gV(a){return a===0?1/a<0:a<0},
E(a,b,c){if(B.e.T(b,c)>0)throw A.d(A.eB(b))
if(this.T(a,b)<0)return b
if(this.T(a,c)>0)return c
return a},
h(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gn(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
a_(a,b){var t
if(a>0)t=this.ac(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
ac(a,b){return b>31?0:a>>>b},
gl(a){return A.T(u.H)},
$ib:1,
$iW:1}
J.ad.prototype={
gl(a){return A.T(u.S)},
$ie:1,
$ia:1}
J.aT.prototype={
gl(a){return A.T(u.i)},
$ie:1}
J.a1.prototype={
G(a,b,c){return a.substring(b,A.dD(b,c,a.length))},
h(a){return a},
gn(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gl(a){return A.T(u.N)},
gj(a){return a.length},
$ie:1,
$ii:1}
A.a2.prototype={
h(a){return"LateInitializationError: "+this.a}}
A.ac.prototype={}
A.P.prototype={
gu(a){return new A.a3(this,this.gj(0),A.x(this).i("a3<P.E>"))},
gC(a){return this.a.gj(0)===0}}
A.a3.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
p(){var t,s=this,r=s.a,q=J.cW(r),p=q.gj(r)
if(s.b!==p)throw A.d(A.aM(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.J(r,t);++s.c
return!0}}
A.r.prototype={}
A.as.prototype={}
A.bz.prototype={
v(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
if(q==null)return null
t=Object.create(null)
s=r.b
if(s!==-1)t.arguments=q[s+1]
s=r.c
if(s!==-1)t.argumentsExpr=q[s+1]
s=r.d
if(s!==-1)t.expr=q[s+1]
s=r.e
if(s!==-1)t.method=q[s+1]
s=r.f
if(s!==-1)t.receiver=q[s+1]
return t}}
A.aq.prototype={
h(a){return"Null check operator used on a null value"}}
A.aU.prototype={
h(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bd.prototype={
h(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.bx.prototype={
h(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.I.prototype={
h(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.d1(s==null?"unknown":s)+"'"},
$ia0:1,
gao(){return this},
$C:"$1",
$R:1,
$D:null}
A.aJ.prototype={$C:"$2",$R:2}
A.bb.prototype={}
A.ba.prototype={
h(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.d1(t)+"'"}}
A.a_.prototype={
F(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.a_))return!1
return this.$_target===b.$_target&&this.a===b.a},
gn(a){return(A.eR(this.a)^A.b6(this.$_target))>>>0},
h(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.b7(this.a)+"'")}}
A.b8.prototype={
h(a){return"RuntimeError: "+this.a}}
A.E.prototype={
gj(a){return this.a},
gC(a){return this.a===0},
gD(){return new A.O(this,A.x(this).i("O<1>"))},
a1(a){var t=this.b
if(t==null)return!1
return t[a]!=null},
S(a,b){A.x(this).i("L<1,2>").a(b).B(0,new A.bq(this))},
A(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.ah(b)},
ah(a){var t,s,r=this.d
if(r==null)return null
t=r[this.a3(a)]
s=this.a4(t,a)
if(s<0)return null
return t[s].b},
k(a,b,c){var t,s,r=this,q=A.x(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.X(t==null?r.b=r.P():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.X(s==null?r.c=r.P():s,b,c)}else r.ai(b,c)},
ai(a,b){var t,s,r,q,p=this,o=A.x(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.P()
s=p.a3(a)
r=t[s]
if(r==null)t[s]=[p.R(a,b)]
else{q=p.a4(r,a)
if(q>=0)r[q].b=b
else r.push(p.R(a,b))}},
ak(a,b){var t=this.ab(this.b,b)
return t},
B(a,b){var t,s,r=this
A.x(r).i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.d(A.aM(r))
t=t.c}},
X(a,b,c){var t,s=A.x(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.R(b,c)
else t.b=c},
ab(a,b){var t
if(a==null)return null
t=a[b]
if(t==null)return null
this.ad(t)
delete a[b]
return t.b},
Y(){this.r=this.r+1&1073741823},
R(a,b){var t=this,s=A.x(t),r=new A.bu(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else{s=t.f
s.toString
r.d=s
t.f=s.c=r}++t.a
t.Y()
return r},
ad(a){var t=this,s=a.d,r=a.c
if(s==null)t.e=r
else s.c=r
if(r==null)t.f=s
else r.d=s;--t.a
t.Y()},
a3(a){return J.bV(a)&1073741823},
a4(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.Y(a[s].a,b))return s
return-1},
h(a){return A.cq(this)},
P(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$icp:1}
A.bq.prototype={
$2(a,b){var t=this.a,s=A.x(t)
t.k(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.x(this.a).i("~(1,2)")}}
A.bu.prototype={}
A.O.prototype={
gj(a){return this.a.a},
gC(a){return this.a.a===0},
gu(a){var t=this.a
return new A.aW(t,t.r,t.e,this.$ti.i("aW<1>"))}}
A.aW.prototype={
gq(){return this.d},
p(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.d(A.aM(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}}}
A.bO.prototype={
$1(a){return this.a(a)},
$S:0}
A.bP.prototype={
$2(a,b){return this.a(a,b)},
$S:2}
A.bQ.prototype={
$1(a){return this.a(A.R(a))},
$S:3}
A.a4.prototype={
gl(a){return B.w},
$ie:1}
A.an.prototype={}
A.aX.prototype={
gl(a){return B.x},
$ie:1}
A.a5.prototype={
gj(a){return a.length},
$iv:1}
A.al.prototype={$ic:1,$if:1}
A.am.prototype={$ic:1,$if:1}
A.aY.prototype={
gl(a){return B.y},
$ie:1}
A.aZ.prototype={
gl(a){return B.z},
$ie:1}
A.b_.prototype={
gl(a){return B.A},
$ie:1}
A.b0.prototype={
gl(a){return B.B},
$ie:1}
A.b1.prototype={
gl(a){return B.C},
$ie:1}
A.b2.prototype={
gl(a){return B.D},
$ie:1}
A.b3.prototype={
gl(a){return B.E},
$ie:1}
A.ao.prototype={
gl(a){return B.F},
gj(a){return a.length},
$ie:1}
A.b4.prototype={
gl(a){return B.G},
gj(a){return a.length},
$ie:1}
A.av.prototype={}
A.aw.prototype={}
A.ax.prototype={}
A.ay.prototype={}
A.B.prototype={
i(a){return A.bH(v.typeUniverse,this,a)},
H(a){return A.dZ(v.typeUniverse,this,a)}}
A.bg.prototype={}
A.bF.prototype={
h(a){return A.y(this.a,null)}}
A.bf.prototype={
h(a){return this.a}}
A.az.prototype={}
A.bv.prototype={
$2(a,b){this.a.k(0,this.b.a(a),this.c.a(b))},
$S:4}
A.h.prototype={
gu(a){return new A.a3(a,a.length,A.aF(a).i("a3<h.E>"))},
J(a,b){if(!(b<a.length))return A.q(a,b)
return a[b]},
ga5(a){return a.length!==0},
h(a){return A.cn(a,"[","]")}}
A.w.prototype={
B(a,b){var t,s,r,q=A.x(this)
q.i("~(w.K,w.V)").a(b)
for(t=this.gD(),t=t.gu(t),q=q.i("w.V");t.p();){s=t.gq()
r=this.A(0,s)
b.$2(s,r==null?q.a(r):r)}},
gj(a){var t=this.gD()
return t.gj(t)},
gC(a){var t=this.gD()
return t.gC(t)},
h(a){return A.cq(this)},
$iL:1}
A.bw.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.n(a)
s.a=(s.a+=t)+": "
t=A.n(b)
s.a+=t},
$S:1}
A.bh.prototype={
A(a,b){var t,s=this.b
if(s==null)return this.c.A(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.aa(b):t}},
gj(a){return this.b==null?this.c.a:this.I().length},
gC(a){return this.gj(0)===0},
gD(){if(this.b==null){var t=this.c
return new A.O(t,A.x(t).i("O<1>"))}return new A.bi(this)},
B(a,b){var t,s,r,q,p=this
u.x.a(b)
if(p.b==null)return p.c.B(0,b)
t=p.I()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.bK(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.d(A.aM(p))}},
I(){var t=u.M.a(this.c)
if(t==null)t=this.c=A.C(Object.keys(this.a),u.s)
return t},
aa(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.bK(this.a[a])
return this.b[a]=t}}
A.bi.prototype={
gj(a){return this.a.gj(0)},
J(a,b){var t=this.a
if(t.b==null)t=t.gD().J(0,b)
else{t=t.I()
if(!(b<t.length))return A.q(t,b)
t=t[b]}return t},
gu(a){var t=this.a
if(t.b==null){t=t.gD()
t=t.gu(t)}else{t=t.I()
t=new J.Z(t,t.length,A.aD(t).i("Z<1>"))}return t}}
A.aK.prototype={}
A.aN.prototype={}
A.aj.prototype={
h(a){var t=A.aO(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.aV.prototype={
h(a){return"Cyclic error in JSON stringify"}}
A.br.prototype={
ae(a,b){var t=A.es(a,this.gaf().a)
return t},
a2(a,b){var t=A.dL(a,this.gag().b,null)
return t},
gag(){return B.v},
gaf(){return B.u}}
A.bt.prototype={}
A.bs.prototype={}
A.bD.prototype={
a7(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.c.G(a,s,r)
s=r+1
p=A.p(92)
t.a+=p
p=A.p(117)
t.a+=p
p=A.p(100)
t.a+=p
p=q>>>8&15
p=A.p(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.p(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.p(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.c.G(a,s,r)
s=r+1
p=A.p(92)
t.a+=p
switch(q){case 8:p=A.p(98)
t.a+=p
break
case 9:p=A.p(116)
t.a+=p
break
case 10:p=A.p(110)
t.a+=p
break
case 12:p=A.p(102)
t.a+=p
break
case 13:p=A.p(114)
t.a+=p
break
default:p=A.p(117)
t.a+=p
p=A.p(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.p(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.p(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.c.G(a,s,r)
s=r+1
p=A.p(92)
t.a+=p
p=A.p(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.c.G(a,s,n)},
M(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.d(new A.aV(a,null))}B.a.m(t,a)},
L(a){var t,s,r,q,p=this
if(p.a6(a))return
p.M(a)
try{t=p.b.$1(a)
if(!p.a6(t)){r=A.co(a,null,p.gZ())
throw A.d(r)}r=p.a
if(0>=r.length)return A.q(r,-1)
r.pop()}catch(q){s=A.d2(q)
r=A.co(a,s,p.gZ())
throw A.d(r)}},
a6(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.h(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.a7(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.M(a)
r.am(a)
t=r.a
if(0>=t.length)return A.q(t,-1)
t.pop()
return!0}else if(u.f.b(a)){r.M(a)
s=r.an(a)
t=r.a
if(0>=t.length)return A.q(t,-1)
t.pop()
return s}else return!1},
am(a){var t,s=this.c
s.a+="["
if(J.dg(a)){if(0>=a.length)return A.q(a,0)
this.L(a[0])
for(t=1;t<a.length;++t){s.a+=","
this.L(a[t])}}s.a+="]"},
an(a){var t,s,r,q,p,o,n=this,m={}
if(a.gC(a)){n.c.a+="{}"
return!0}t=a.gj(a)*2
s=A.dB(t,null,u.X)
r=m.a=0
m.b=!0
a.B(0,new A.bE(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.a7(A.R(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.q(s,o)
n.L(s[o])}q.a+="}"
return!0}}
A.bE.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.k(t,s.a++,a)
B.a.k(t,s.a++,b)},
$S:1}
A.bC.prototype={
gZ(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.j.prototype={}
A.aH.prototype={
h(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.aO(t)
return"Assertion failed"}}
A.au.prototype={}
A.H.prototype={
gO(){return"Invalid argument"+(!this.a?"(s)":"")},
gN(){return""},
h(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.gO()+r+p
if(!t.a)return o
return o+t.gN()+": "+A.aO(t.gU())},
gU(){return this.b}}
A.ar.prototype={
gU(){return A.cK(this.b)},
gO(){return"RangeError"},
gN(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.n(r):""
else if(r==null)t=": Not greater than or equal to "+A.n(s)
else if(r>s)t=": Not in inclusive range "+A.n(s)+".."+A.n(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.n(s)
return t}}
A.aP.prototype={
gU(){return A.bJ(this.b)},
gO(){return"RangeError"},
gN(){if(A.bJ(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gj(a){return this.f}}
A.be.prototype={
h(a){return"Unsupported operation: "+this.a}}
A.bc.prototype={
h(a){return"UnimplementedError: "+this.a}}
A.b9.prototype={
h(a){return"Bad state: "+this.a}}
A.aL.prototype={
h(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.aO(t)+"."}}
A.at.prototype={
h(a){return"Stack Overflow"},
$ij:1}
A.bn.prototype={
h(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.c.prototype={
gj(a){var t,s=this.gu(this)
for(t=0;s.p();)++t
return t},
J(a,b){var t,s=this.gu(this)
for(t=b;s.p();){if(t===0)return s.gq();--t}throw A.d(A.cm(b,b-t,this,"index"))},
h(a){return A.dw(this,"(",")")}}
A.ap.prototype={
gn(a){return A.k.prototype.gn.call(this,0)},
h(a){return"null"}}
A.k.prototype={$ik:1,
F(a,b){return this===b},
gn(a){return A.b6(this)},
h(a){return"Instance of '"+A.b7(this)+"'"},
gl(a){return A.eG(this)},
toString(){return this.h(this)}}
A.a6.prototype={
gj(a){return this.a.length},
h(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$idF:1}
A.ab.prototype={
gaj(){var t=this.a
return A.ak(["t",t.z,"target",t.t(t.Q)],u.N,u.z)},
K(){var t,s,r,q,p,o,n=this.a
if(n.z>=60)return null
t=n.t(n.Q)
s=n.as
r=n.t(n.Q-(n.z-s))
if(!n.K())return null
q=n.z
p=n.t(n.Q)
o=n.z
n=n.y
n===$&&A.u()
return A.ak(["t",q,"before",t,"after",p,"pastT",B.b.E(o-n,0,60),"waitedSec",B.b.E(o-s,0,60),"readyAtBefore",s,"readyTarget",r],u.N,u.z)},
a0(a){var t,s,r,q
if(!isFinite(a)||a<0||a>1000)throw A.d(A.bo("tick"))
t=this.a
s=t.z
r=60-s
q=B.b.E(a/1000,0,r)
r=Math.abs(r-q)<1e-8?r:q
t.z=s+r
t.Q+=r}}
A.bS.prototype={
$1(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=null
A.R(a)
try{t=u.c.a(B.d.ae(a,g))
s=J.bj(t,"op")
m=A.c4(J.bj(t,"session"))
r=m==null?"default":m
l=u.Y.a(J.bj(t,"config"))
if(l==null){l=u.z
l=A.c_(l,l)}k=u.N
j=u.z
q=A.dz(l,k,j)
if(J.Y(s,"preview")){i=B.d.a2(A.eS(q),g)
return i}if(J.Y(s,"dispose")){this.a.ak(0,r)
return'{"ok":true}'}if(J.Y(s,"reset")){l=this.a
if(!l.a1(r)&&l.a>=16){n=A.ct("sessions")
throw A.d(n)}l.k(0,r,new A.ab(A.bW(q)))}p=this.a.A(0,r)
if(p==null){n=A.ct("session")
throw A.d(n)}o=null
if(J.Y(s,"advance"))p.a0(A.cJ(J.bj(t,"ms")))
if(J.Y(s,"press"))o=p.K()
n=A.c_(k,j)
l=!J.Y(s,"press")||o!=null
J.cd(n,"ok",l)
l=p
j=A.dA(l.gaj(),k,j)
l=l.a
j.k(0,"effective",l.Q)
j.k(0,"ready",l.gW()&&l.z<60)
j.k(0,"remaining",B.b.E(l.as-l.z,0,120))
if(l.cx===0){k=l.x
k===$&&A.u()}else{k=l.w
k===$&&A.u()}j.k(0,"cooldown",k)
k=l.y
k===$&&A.u()
j.k(0,"rewind",k)
j.k(0,"readyAt",l.as)
j.k(0,"readyTarget",l.gW()?l.t(l.Q-(l.z-l.as)):g)
j.k(0,"presses",l.cx)
j.k(0,"ended",l.z>=60)
J.df(n,j)
if(o!=null)J.cd(n,"event",o)
i=B.d.a2(n,g)
return i}catch(h){return'{"ok":false,"error":"speed_help_input"}'}},
$S:5}
A.bk.prototype={
a9(a){var t=this,s=new A.bm(a),r=new A.bl(a),q=A.c3(r.$1("brakeEnabled"))
t.a!==$&&A.G()
t.a=q
r=A.c3(r.$1("speedBarEnabled"))
t.b!==$&&A.G()
t.b=r
r=A.N(s.$4("initialSpeed",0,0,150))
t.c!==$&&A.G()
t.c=r
r=A.N(s.$4("growthMultiplier",70,0,200))
t.d!==$&&A.G()
t.d=r
r=A.N(s.$4("growthExponent",0.2,0.01,1))
t.e!==$&&A.G()
t.e=r
r=A.N(s.$4("startSmoothingSec",3,0.01,60))
t.f!==$&&A.G()
t.f=r
r=A.N(s.$4("initialCompensation",1,0,10))
t.r!==$&&A.G()
t.r=r
r=A.N(s.$4("brakeCooldownSec",6,0.1,120))
t.w!==$&&A.G()
t.w=r
r=A.N(s.$4("brakeFirstReadySec",6,0.1,120))
t.x!==$&&A.G()
t.x=r
s=A.N(s.$4("brakeRewindSec",6,0,120))
t.y!==$&&A.G()
t.y=s
t.as=r},
t(a){var t,s,r,q,p=this,o=p.c
o===$&&A.u()
t=p.d
t===$&&A.u()
s=Math.max(0,a)
r=p.f
r===$&&A.u()
q=p.e
q===$&&A.u()
q=Math.pow(s+r,q)
r=p.r
r===$&&A.u()
return Math.max(0,o+t*(q-r))},
gW(){var t=this.a
t===$&&A.u()
return t&&this.z+1e-9>=this.as},
K(){var t,s,r=this
if(!r.gW())return!1
r.ch=r.t(r.Q)+r.ay*B.b.E(1-(r.z-r.at)/0.18,0,1)
t=r.Q
s=r.y
s===$&&A.u()
s=Math.max(0,t-s)
r.Q=s
s=r.t(s)
r.CW=s
r.ay=Math.max(0,r.ch-s)
s=r.z
r.at=s
t=r.w
t===$&&A.u()
r.as=s+t;++r.cx
return!0}}
A.bm.prototype={
$4(a,b,c,d){var t=this.a.A(0,a)
if(t==null)t=b
if(typeof t!="number"||!isFinite(t)||t<c||t>d)throw A.d(A.bo("enemy_pace_"+a))
return t},
$S:6}
A.bl.prototype={
$1(a){var t=this.a,s=!t.a1(a)||t.A(0,a)
if(!A.bL(s))throw A.d(A.bo("enemy_pace_"+a))
return s},
$S:7};(function aliases(){var t=J.K.prototype
t.a8=t.h})();(function installTearOffs(){var t=hunkHelpers._static_1
t(A,"eC","e8",0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.k,null)
r(A.k,[A.bX,J.aQ,A.as,J.Z,A.j,A.c,A.a3,A.r,A.bz,A.bx,A.I,A.w,A.bu,A.aW,A.B,A.bg,A.bF,A.h,A.aK,A.aN,A.bD,A.at,A.bn,A.ap,A.a6,A.ab,A.bk])
r(J.aQ,[J.aS,J.ae,J.ah,J.ag,J.ai,J.af,J.a1])
r(J.ah,[J.K,J.t,A.a4,A.an])
r(J.K,[J.b5,J.a7,J.J])
s(J.aR,A.as)
s(J.bp,J.t)
r(J.af,[J.ad,J.aT])
r(A.j,[A.a2,A.au,A.aU,A.bd,A.b8,A.bf,A.aj,A.aH,A.H,A.be,A.bc,A.b9,A.aL])
s(A.ac,A.c)
r(A.ac,[A.P,A.O])
s(A.aq,A.au)
r(A.I,[A.aJ,A.bb,A.bO,A.bQ,A.bS,A.bm,A.bl])
r(A.bb,[A.ba,A.a_])
r(A.w,[A.E,A.bh])
r(A.aJ,[A.bq,A.bP,A.bv,A.bw,A.bE])
r(A.an,[A.aX,A.a5])
r(A.a5,[A.av,A.ax])
s(A.aw,A.av)
s(A.al,A.aw)
s(A.ay,A.ax)
s(A.am,A.ay)
r(A.al,[A.aY,A.aZ])
r(A.am,[A.b_,A.b0,A.b1,A.b2,A.b3,A.ao,A.b4])
s(A.az,A.bf)
s(A.bi,A.P)
s(A.aV,A.aj)
s(A.br,A.aK)
r(A.aN,[A.bt,A.bs])
s(A.bC,A.bD)
r(A.H,[A.ar,A.aP])
t(A.av,A.h)
t(A.aw,A.r)
t(A.ax,A.h)
t(A.ay,A.r)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",b:"double",W:"num",i:"String",aE:"bool",ap:"Null",f:"List",k:"Object",L:"Map",l:"JSObject"},mangledNames:{},types:["@(@)","~(k?,k?)","@(@,i)","@(i)","~(@,@)","i(i)","b(i,b,b,b)","aE(i)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti")}
A.dY(v.typeUniverse,JSON.parse('{"J":"K","b5":"K","a7":"K","f0":"a4","aS":{"aE":[],"e":[]},"ae":{"e":[]},"ah":{"l":[]},"K":{"l":[]},"t":{"f":["1"],"l":[],"c":["1"]},"aR":{"as":[]},"bp":{"t":["1"],"f":["1"],"l":[],"c":["1"]},"af":{"b":[],"W":[]},"ad":{"b":[],"a":[],"W":[],"e":[]},"aT":{"b":[],"W":[],"e":[]},"a1":{"i":[],"e":[]},"a2":{"j":[]},"ac":{"c":["1"]},"P":{"c":["1"]},"aq":{"j":[]},"aU":{"j":[]},"bd":{"j":[]},"I":{"a0":[]},"aJ":{"a0":[]},"bb":{"a0":[]},"ba":{"a0":[]},"a_":{"a0":[]},"b8":{"j":[]},"E":{"w":["1","2"],"cp":["1","2"],"L":["1","2"],"w.K":"1","w.V":"2"},"O":{"c":["1"]},"a4":{"l":[],"e":[]},"an":{"l":[]},"aX":{"l":[],"e":[]},"a5":{"v":["1"],"l":[]},"al":{"h":["b"],"f":["b"],"v":["b"],"l":[],"c":["b"],"r":["b"]},"am":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"]},"aY":{"h":["b"],"f":["b"],"v":["b"],"l":[],"c":["b"],"r":["b"],"e":[],"h.E":"b"},"aZ":{"h":["b"],"f":["b"],"v":["b"],"l":[],"c":["b"],"r":["b"],"e":[],"h.E":"b"},"b_":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"],"e":[],"h.E":"a"},"b0":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"],"e":[],"h.E":"a"},"b1":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"],"e":[],"h.E":"a"},"b2":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"],"e":[],"h.E":"a"},"b3":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"],"e":[],"h.E":"a"},"ao":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"],"e":[],"h.E":"a"},"b4":{"h":["a"],"f":["a"],"v":["a"],"l":[],"c":["a"],"r":["a"],"e":[],"h.E":"a"},"bf":{"j":[]},"az":{"j":[]},"w":{"L":["1","2"]},"bh":{"w":["i","@"],"L":["i","@"],"w.K":"i","w.V":"@"},"bi":{"P":["i"],"c":["i"],"P.E":"i"},"aj":{"j":[]},"aV":{"j":[]},"b":{"W":[]},"a":{"W":[]},"aH":{"j":[]},"au":{"j":[]},"H":{"j":[]},"ar":{"j":[]},"aP":{"j":[]},"be":{"j":[]},"bc":{"j":[]},"b9":{"j":[]},"aL":{"j":[]},"at":{"j":[]},"a6":{"dF":[]},"dv":{"f":["a"],"c":["a"]},"dJ":{"f":["a"],"c":["a"]},"dI":{"f":["a"],"c":["a"]},"dt":{"f":["a"],"c":["a"]},"dG":{"f":["a"],"c":["a"]},"du":{"f":["a"],"c":["a"]},"dH":{"f":["a"],"c":["a"]},"dr":{"f":["b"],"c":["b"]},"ds":{"f":["b"],"c":["b"]}}'))
A.dX(v.typeUniverse,JSON.parse('{"ac":1,"a5":1,"aK":2,"aN":2}'))
var u=(function rtii(){var t=A.c7
return{a:t("ab"),C:t("j"),Z:t("a0"),U:t("c<@>"),t:t("t<L<i,@>>"),s:t("t<i>"),b:t("t<@>"),T:t("ae"),m:t("l"),g:t("J"),p:t("v<@>"),j:t("f<@>"),c:t("L<i,@>"),f:t("L<@,@>"),P:t("ap"),K:t("k"),L:t("f1"),N:t("i"),R:t("e"),o:t("a7"),y:t("aE"),i:t("b"),z:t("@"),S:t("a"),O:t("cl<ap>?"),A:t("l?"),M:t("f<@>?"),Y:t("L<@,@>?"),X:t("k?"),v:t("i?"),u:t("aE?"),I:t("b?"),w:t("a?"),n:t("W?"),H:t("W"),x:t("~(i,@)")}})();(function constants(){B.q=J.aQ.prototype
B.a=J.t.prototype
B.e=J.ad.prototype
B.b=J.af.prototype
B.c=J.a1.prototype
B.r=J.J.prototype
B.t=J.ah.prototype
B.j=J.b5.prototype
B.f=J.a7.prototype
B.h=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.k=function() {
  var toStringFunction = Object.prototype.toString;
  function getTag(o) {
    var s = toStringFunction.call(o);
    return s.substring(8, s.length - 1);
  }
  function getUnknownTag(object, tag) {
    if (/^HTML[A-Z].*Element$/.test(tag)) {
      var name = toStringFunction.call(object);
      if (name == "[object Object]") return null;
      return "HTMLElement";
    }
  }
  function getUnknownTagGenericBrowser(object, tag) {
    if (object instanceof HTMLElement) return "HTMLElement";
    return getUnknownTag(object, tag);
  }
  function prototypeForTag(tag) {
    if (typeof window == "undefined") return null;
    if (typeof window[tag] == "undefined") return null;
    var constructor = window[tag];
    if (typeof constructor != "function") return null;
    return constructor.prototype;
  }
  function discriminator(tag) { return null; }
  var isBrowser = typeof HTMLElement == "function";
  return {
    getTag: getTag,
    getUnknownTag: isBrowser ? getUnknownTagGenericBrowser : getUnknownTag,
    prototypeForTag: prototypeForTag,
    discriminator: discriminator };
}
B.p=function(getTagFallback) {
  return function(hooks) {
    if (typeof navigator != "object") return hooks;
    var userAgent = navigator.userAgent;
    if (typeof userAgent != "string") return hooks;
    if (userAgent.indexOf("DumpRenderTree") >= 0) return hooks;
    if (userAgent.indexOf("Chrome") >= 0) {
      function confirm(p) {
        return typeof window == "object" && window[p] && window[p].name == p;
      }
      if (confirm("Window") && confirm("HTMLElement")) return hooks;
    }
    hooks.getTag = getTagFallback;
  };
}
B.l=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.o=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Firefox") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "GeoGeolocation": "Geolocation",
    "Location": "!Location",
    "WorkerMessageEvent": "MessageEvent",
    "XMLDocument": "!Document"};
  function getTagFirefox(o) {
    var tag = getTag(o);
    return quickMap[tag] || tag;
  }
  hooks.getTag = getTagFirefox;
}
B.n=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Trident/") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "HTMLDDElement": "HTMLElement",
    "HTMLDTElement": "HTMLElement",
    "HTMLPhraseElement": "HTMLElement",
    "Position": "Geoposition"
  };
  function getTagIE(o) {
    var tag = getTag(o);
    var newTag = quickMap[tag];
    if (newTag) return newTag;
    if (tag == "Object") {
      if (window.DataView && (o instanceof window.DataView)) return "DataView";
    }
    return tag;
  }
  function prototypeForTagIE(tag) {
    var constructor = window[tag];
    if (constructor == null) return null;
    return constructor.prototype;
  }
  hooks.getTag = getTagIE;
  hooks.prototypeForTag = prototypeForTagIE;
}
B.m=function(hooks) {
  var getTag = hooks.getTag;
  var prototypeForTag = hooks.prototypeForTag;
  function getTagFixed(o) {
    var tag = getTag(o);
    if (tag == "Document") {
      if (!!o.xmlVersion) return "!Document";
      return "!HTMLDocument";
    }
    return tag;
  }
  function prototypeForTagFixed(tag) {
    if (tag == "Document") return null;
    return prototypeForTag(tag);
  }
  hooks.getTag = getTagFixed;
  hooks.prototypeForTag = prototypeForTagFixed;
}
B.i=function(hooks) { return hooks; }

B.d=new A.br()
B.u=new A.bs(null)
B.v=new A.bt(null)
B.w=A.D("eX")
B.x=A.D("eY")
B.y=A.D("dr")
B.z=A.D("ds")
B.A=A.D("dt")
B.B=A.D("du")
B.C=A.D("dv")
B.D=A.D("dG")
B.E=A.D("dH")
B.F=A.D("dI")
B.G=A.D("dJ")})();(function staticFields(){$.bB=null
$.z=A.C([],A.c7("t<k>"))
$.cr=null
$.ci=null
$.ch=null
$.cY=null
$.cT=null
$.d_=null
$.bM=null
$.bR=null
$.c9=null})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"f_","d3",()=>A.cX("_$dart_dartClosure"))
t($,"eZ","cc",()=>A.cX("_$dart_dartClosure_dartJSInterop"))
t($,"fc","de",()=>A.C([new J.aR()],A.c7("t<as>")))
t($,"f2","d4",()=>A.F(A.bA({
toString:function(){return"$receiver$"}})))
t($,"f3","d5",()=>A.F(A.bA({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"f4","d6",()=>A.F(A.bA(null)))
t($,"f5","d7",()=>A.F(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"f8","da",()=>A.F(A.bA(void 0)))
t($,"f9","db",()=>A.F(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"f7","d9",()=>A.F(A.cv(null)))
t($,"f6","d8",()=>A.F(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"fb","dd",()=>A.F(A.cv(void 0)))
t($,"fa","dc",()=>A.F(function(){try{(void 0).$method$}catch(s){return s.message}}()))})();(function nativeSupport(){!function(){var t=function(a){var n={}
n[a]=1
return Object.keys(hunkHelpers.convertToFastObject(n))[0]}
v.getIsolateTag=function(a){return t("___dart_"+a+v.isolateTag)}
var s="___dart_isolate_tags_"
var r=Object[s]||(Object[s]=Object.create(null))
var q="_ZxYxX"
for(var p=0;;p++){var o=t(q+"_"+p+"_")
if(!(o in r)){r[o]=1
v.isolateTag=o
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.a4,SharedArrayBuffer:A.a4,ArrayBufferView:A.an,DataView:A.aX,Float32Array:A.aY,Float64Array:A.aZ,Int16Array:A.b_,Int32Array:A.b0,Int8Array:A.b1,Uint16Array:A.b2,Uint32Array:A.b3,Uint8ClampedArray:A.ao,CanvasPixelArray:A.ao,Uint8Array:A.b4})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.a5.$nativeSuperclassTag="ArrayBufferView"
A.av.$nativeSuperclassTag="ArrayBufferView"
A.aw.$nativeSuperclassTag="ArrayBufferView"
A.al.$nativeSuperclassTag="ArrayBufferView"
A.ax.$nativeSuperclassTag="ArrayBufferView"
A.ay.$nativeSuperclassTag="ArrayBufferView"
A.am.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$0=function(){return this()}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.eP
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
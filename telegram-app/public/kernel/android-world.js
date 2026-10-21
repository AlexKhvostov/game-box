/* Dart SDK runtime license:
Copyright 2012, the Dart project authors.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google LLC nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
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
if(a[b]!==t){A.hr(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.n(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.dj(b)
return new t(c,this)}:function(){if(t===null)t=A.dj(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.dj(a).prototype
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
dp(a,b,c,d){return{i:a,p:b,e:c,x:d}},
dk(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.dm==null){A.hg()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.c(A.dW("Return interceptor for "+A.q(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.cE
if(p==null)p=$.cE=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.hl(a)
if(q!=null)return q
if(typeof a=="function")return B.I
t=Object.getPrototypeOf(a)
if(t==null)return B.q
if(t===Object.prototype)return B.q
if(typeof r=="function"){p=$.cE
if(p==null)p=$.cE=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.j,enumerable:false,writable:true,configurable:true})
return B.j}return B.j},
dF(a,b){if(a<0||a>4294967295)throw A.c(A.aX(a,0,4294967295,"length",null))
return J.f1(new Array(a),b)},
dG(a,b){if(a<0)throw A.c(A.c0("Length must be a non-negative integer: "+a))
return A.n(new Array(a),b.i("l<0>"))},
d1(a,b){if(a<0)throw A.c(A.c0("Length must be a non-negative integer: "+a))
return A.n(new Array(a),b.i("l<0>"))},
f1(a,b){var t=A.n(a,b.i("l<0>"))
t.$flags=1
return t},
dH(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
f2(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.dH(s))break;++b}return b},
f3(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.f(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.dH(r))break}return b},
am(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aI.prototype
return J.by.prototype}if(typeof a=="string")return J.ar.prototype
if(a==null)return J.aJ.prototype
if(typeof a=="boolean")return J.bx.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a3.prototype
if(typeof a=="symbol")return J.aM.prototype
if(typeof a=="bigint")return J.aK.prototype
return a}if(a instanceof A.m)return a
return J.dk(a)},
bg(a){if(typeof a=="string")return J.ar.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a3.prototype
if(typeof a=="symbol")return J.aM.prototype
if(typeof a=="bigint")return J.aK.prototype
return a}if(a instanceof A.m)return a
return J.dk(a)},
a_(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a3.prototype
if(typeof a=="symbol")return J.aM.prototype
if(typeof a=="bigint")return J.aK.prototype
return a}if(a instanceof A.m)return a
return J.dk(a)},
hc(a){if(typeof a=="number")return J.aq.prototype
if(a==null)return a
if(!(a instanceof A.m))return J.ax.prototype
return a},
T(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.am(a).H(a,b)},
a0(a,b){if(typeof b==="number")if(Array.isArray(a)||A.hk(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.a_(a).h(a,b)},
eI(a,b,c){return J.a_(a).u(a,b,c)},
dr(a,b){return J.a_(a).M(a,b)},
ds(a,b,c){return J.hc(a).m(a,b,c)},
dt(a,b){return J.a_(a).B(a,b)},
G(a){return J.am(a).gt(a)},
eJ(a){return J.bg(a).gan(a)},
du(a){return J.a_(a).gv(a)},
a1(a){return J.bg(a).gk(a)},
eK(a){return J.am(a).gp(a)},
eL(a,b,c){return J.a_(a).aK(a,b,c)},
bh(a){return J.am(a).j(a)},
bv:function bv(){},
bx:function bx(){},
aJ:function aJ(){},
aL:function aL(){},
a4:function a4(){},
bK:function bK(){},
ax:function ax(){},
a3:function a3(){},
aK:function aK(){},
aM:function aM(){},
l:function l(a){this.$ti=a},
bw:function bw(){},
cl:function cl(a){this.$ti=a},
ab:function ab(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aq:function aq(){},
aI:function aI(){},
by:function by(){},
ar:function ar(){}},A={d2:function d2(){},
f4(a){return new A.af("Field '"+a+"' has not been initialized.")},
aO(a){return new A.af("Local '"+a+"' has not been initialized.")},
a6(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
da(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
ej(a,b,c){return a},
dn(a){var t,s
for(t=$.I.length,s=0;s<t;++s)if(a===$.I[s])return!0
return!1},
dU(a,b,c,d){A.d7(b,"start")
if(c!=null){A.d7(c,"end")
if(b>c)A.J(A.aX(b,0,c,"start",null))}return new A.b0(a,b,c,d.i("b0<0>"))},
dE(){return new A.b_("No element")},
af:function af(a){this.a=a},
aG:function aG(a){this.a=a},
cx:function cx(){},
aH:function aH(){},
D:function D(){},
b0:function b0(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
X:function X(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
L:function L(a,b,c){this.a=a
this.b=b
this.$ti=c},
ah:function ah(a,b,c){this.a=a
this.b=b
this.$ti=c},
b4:function b4(a,b,c){this.a=a
this.b=b
this.$ti=c},
C:function C(){},
b2:function b2(){},
ay:function ay(){},
et(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
hk(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
q(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.bh(a)
return t},
bL(a){var t,s=$.dP
if(s==null)s=$.dP=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bM(a){var t,s,r,q
if(a instanceof A.m)return A.E(A.aa(a),null)
t=J.am(a)
if(t===B.H||t===B.J||u.o.b(a)){s=B.m(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.E(A.aa(a),null)},
dQ(a){var t,s,r
if(a==null||typeof a=="number"||A.dh(a))return J.bh(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.B)return a.j(0)
if(a instanceof A.ak)return a.aF(!0)
t=$.eH()
for(s=0;s<1;++s){r=t[s].bv(a)
if(r!=null)return r}return"Instance of '"+A.bM(a)+"'"},
f5(){return Date.now()},
f6(){var t,s
if($.cw!==0)return
$.cw=1000
if(typeof window=="undefined")return
t=window
if(t==null)return
if(!!t.dartUseDateNowForTicks)return
s=t.performance
if(s==null)return
if(typeof s.now!="function")return
$.cw=1e6
$.dR=new A.cv(s)},
z(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.c.aE(t,10)|55296)>>>0,t&1023|56320)}throw A.c(A.aX(a,0,1114111,null,null))},
cS(a){throw A.c(A.ei(a))},
f(a,b){if(a==null)J.a1(a)
throw A.c(A.cP(a,b))},
cP(a,b){var t,s="index"
if(!A.ed(b))return new A.U(!0,b,s,null)
t=J.a1(a)
if(b<0||b>=t)return A.d_(b,t,a,s)
return new A.aW(null,null,!0,b,s,"Value not in range")},
ei(a){return new A.U(!0,a,null,null)},
c(a){return A.y(a,new Error())},
y(a,b){var t
if(a==null)a=new A.b1()
b.dartException=a
t=A.hs
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hs(){return J.bh(this.dartException)},
J(a,b){throw A.y(a,b==null?new Error():b)},
aE(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.J(A.fH(a,b,c),t)},
fH(a,b,c){var t,s,r,q,p,o,n,m,l
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
return new A.b3("'"+t+"': Cannot "+p+" "+m+l+o)},
O(a){throw A.c(A.P(a))},
Y(a){var t,s,r,q,p,o
a=A.hq(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.n([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.cA(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
cB(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
dV(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
d3(a,b){var t=b==null,s=t?null:b.method
return new A.bz(a,s,t?null:b.receiver)},
eu(a){if(a==null)return new A.ct(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.ao(a,a.dartException)
return A.h7(a)},
ao(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
h7(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.c.aE(s,16)&8191)===10)switch(r){case 438:return A.ao(a,A.d3(A.q(t)+" (Error "+r+")",null))
case 445:case 5007:A.q(t)
return A.ao(a,new A.aV())}}if(a instanceof TypeError){q=$.ex()
p=$.ey()
o=$.ez()
n=$.eA()
m=$.eD()
l=$.eE()
k=$.eC()
$.eB()
j=$.eG()
i=$.eF()
h=q.C(t)
if(h!=null)return A.ao(a,A.d3(A.a8(t),h))
else{h=p.C(t)
if(h!=null){h.method="call"
return A.ao(a,A.d3(A.a8(t),h))}else if(o.C(t)!=null||n.C(t)!=null||m.C(t)!=null||l.C(t)!=null||k.C(t)!=null||n.C(t)!=null||j.C(t)!=null||i.C(t)!=null){A.a8(t)
return A.ao(a,new A.aV())}}return A.ao(a,new A.bT(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.aZ()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.ao(a,new A.U(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.aZ()
return a},
eq(a){if(a==null)return J.G(a)
if(typeof a=="object")return A.bL(a)
return J.G(a)},
hb(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.u(0,a[t],a[s])}return b},
eT(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bQ().constructor.prototype):Object.create(new A.ap(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.dz(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.eP(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.dz(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
eP(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.c("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.eN)}throw A.c("Error in functionType of tearoff")},
eQ(a,b,c,d){var t=A.dy
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
dz(a,b,c,d){if(c)return A.eS(a,b,d)
return A.eQ(b.length,d,a,b)},
eR(a,b,c,d){var t=A.dy,s=A.eO
switch(b?-1:a){case 0:throw A.c(new A.bO("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
eS(a,b,c){var t,s
if($.dw==null)$.dw=A.dv("interceptor")
if($.dx==null)$.dx=A.dv("receiver")
t=b.length
s=A.eR(t,c,a,b)
return s},
dj(a){return A.eT(a)},
eN(a,b){return A.bf(v.typeUniverse,A.aa(a.a),b)},
dy(a){return a.a},
eO(a){return a.b},
dv(a){var t,s,r,q=new A.ap("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.c(A.c0("Field name "+a+" not found."))},
el(a){return v.getIsolateTag(a)},
hl(a){var t,s,r,q,p,o=A.a8($.em.$1(a)),n=$.cQ[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cW[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.bZ($.eh.$2(a,o))
if(r!=null){n=$.cQ[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cW[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.cY(t)
$.cQ[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.cW[o]=t
return t}if(q==="-"){p=A.cY(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.er(a,t)
if(q==="*")throw A.c(A.dW(o))
if(v.leafTags[o]===true){p=A.cY(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.er(a,t)},
er(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.dp(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
cY(a){return J.dp(a,!1,null,!!a.$iH)},
hn(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.cY(t)
else return J.dp(t,c,null,null)},
hg(){if(!0===$.dm)return
$.dm=!0
A.hh()},
hh(){var t,s,r,q,p,o,n,m
$.cQ=Object.create(null)
$.cW=Object.create(null)
A.hf()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.es.$1(p)
if(o!=null){n=A.hn(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
hf(){var t,s,r,q,p,o,n=B.v()
n=A.aC(B.w,A.aC(B.x,A.aC(B.n,A.aC(B.n,A.aC(B.y,A.aC(B.z,A.aC(B.A(B.m),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.em=new A.cT(q)
$.eh=new A.cU(p)
$.es=new A.cV(o)},
aC(a,b){return a(b)||b},
h9(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
hq(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
ba:function ba(a,b){this.a=a
this.b=b},
bu:function bu(){},
ad:function ad(a,b){this.a=a
this.$ti=b},
cv:function cv(a){this.a=a},
aY:function aY(){},
cA:function cA(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
aV:function aV(){},
bz:function bz(a,b,c){this.a=a
this.b=b
this.c=c},
bT:function bT(a){this.a=a},
ct:function ct(a){this.a=a},
B:function B(){},
bk:function bk(){},
bl:function bl(){},
bR:function bR(){},
bQ:function bQ(){},
ap:function ap(a,b){this.a=a
this.b=b},
bO:function bO(a){this.a=a},
ae:function ae(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cm:function cm(a){this.a=a},
cq:function cq(a,b){this.a=a
this.b=b
this.c=null},
ag:function ag(a,b){this.a=a
this.$ti=b},
aP:function aP(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
cT:function cT(a){this.a=a},
cU:function cU(a){this.a=a},
cV:function cV(a){this.a=a},
ak:function ak(){},
az:function az(){},
hr(a){throw A.y(new A.af("Field '"+a+"' has been assigned during initialization."),new Error())},
j(){throw A.y(A.f4(""),new Error())},
cD(){var t=new A.cC()
return t.b=t},
cC:function cC(){this.b=null},
al(a,b,c){if(a>>>0!==a||a>=c)throw A.c(A.cP(b,a))},
at:function at(){},
aS:function aS(){},
bB:function bB(){},
au:function au(){},
aQ:function aQ(){},
aR:function aR(){},
bC:function bC(){},
bD:function bD(){},
bE:function bE(){},
bF:function bF(){},
bG:function bG(){},
bH:function bH(){},
bI:function bI(){},
aT:function aT(){},
bJ:function bJ(){},
b6:function b6(){},
b7:function b7(){},
b8:function b8(){},
b9:function b9(){},
d8(a,b){var t=b.c
return t==null?b.c=A.bd(a,"dA",[b.x]):t},
dS(a){var t=a.w
if(t===6||t===7)return A.dS(a.x)
return t===11||t===12},
fa(a){return a.as},
cR(a){return A.cK(v.typeUniverse,a,!1)},
hj(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.a9(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
a9(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.a9(a0,t,a2,a3)
if(s===t)return a1
return A.e4(a0,s,!0)
case 7:t=a1.x
s=A.a9(a0,t,a2,a3)
if(s===t)return a1
return A.e3(a0,s,!0)
case 8:r=a1.y
q=A.aB(a0,r,a2,a3)
if(q===r)return a1
return A.bd(a0,a1.x,q)
case 9:p=a1.x
o=A.a9(a0,p,a2,a3)
n=a1.y
m=A.aB(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.dd(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.aB(a0,k,a2,a3)
if(j===k)return a1
return A.e5(a0,l,j)
case 11:i=a1.x
h=A.a9(a0,i,a2,a3)
g=a1.y
f=A.h4(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.e2(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.aB(a0,e,a2,a3)
p=a1.x
o=A.a9(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.de(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.c(A.bj("Attempted to substitute unexpected RTI kind "+a))}},
aB(a,b,c,d){var t,s,r,q,p=b.length,o=A.cL(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.a9(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
h5(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.cL(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.a9(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
h4(a,b,c,d){var t,s=b.a,r=A.aB(a,s,c,d),q=b.b,p=A.aB(a,q,c,d),o=b.c,n=A.h5(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.bV()
t.a=r
t.b=p
t.c=n
return t},
n(a,b){a[v.arrayRti]=b
return a},
cO(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.he(t)
return a.$S()}return null},
hi(a,b){var t
if(A.dS(b))if(a instanceof A.B){t=A.cO(a)
if(t!=null)return t}return A.aa(a)},
aa(a){if(a instanceof A.m)return A.c_(a)
if(Array.isArray(a))return A.A(a)
return A.dg(J.am(a))},
A(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
c_(a){var t=a.$ti
return t!=null?t:A.dg(a)},
dg(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.fO(a,t)},
fO(a,b){var t=a instanceof A.B?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fx(v.typeUniverse,t.name)
b.$ccache=s
return s},
he(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.cK(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
hd(a){return A.Z(A.c_(a))},
dl(a){var t=A.cO(a)
return A.Z(t==null?A.aa(a):t)},
di(a){var t
if(a instanceof A.ak)return A.ha(a.$r,a.az())
t=a instanceof A.B?A.cO(a):null
if(t!=null)return t
if(u.R.b(a))return J.eK(a).a
if(Array.isArray(a))return A.A(a)
return A.aa(a)},
Z(a){var t=a.r
return t==null?a.r=new A.cJ(a):t},
ha(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.f(r,0)
t=A.bf(v.typeUniverse,A.di(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.f(r,s)
t=A.e6(v.typeUniverse,t,A.di(r[s]))}return A.bf(v.typeUniverse,t,a)},
S(a){return A.Z(A.cK(v.typeUniverse,a,!1))},
fN(a){var t=this
t.b=A.h3(t)
return t.b(a)},
h3(a){var t,s,r,q,p
if(a===u.K)return A.fU
if(A.an(a))return A.fY
t=a.w
if(t===6)return A.fL
if(t===1)return A.ef
if(t===7)return A.fP
s=A.h2(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.an)){a.f="$i"+r
if(r==="h")return A.fS
if(a===u.m)return A.fR
return A.fX}}else if(t===10){q=A.h9(a.x,a.y)
p=q==null?A.ef:q
return p==null?A.e9(p):p}return A.fJ},
h2(a){if(a.w===8){if(a===u.S)return A.ed
if(a===u.i||a===u.H)return A.fT
if(a===u.N)return A.fW
if(a===u.y)return A.dh}return null},
fM(a){var t=this,s=A.fI
if(A.an(t))s=A.fE
else if(t===u.K)s=A.e9
else if(A.aD(t)){s=A.fK
if(t===u.x)s=A.fB
else if(t===u.w)s=A.bZ
else if(t===u.e)s=A.N
else if(t===u.B)s=A.p
else if(t===u.I)s=A.fA
else if(t===u.A)s=A.fD}else if(t===u.S)s=A.cM
else if(t===u.N)s=A.a8
else if(t===u.y)s=A.fz
else if(t===u.H)s=A.t
else if(t===u.i)s=A.df
else if(t===u.m)s=A.fC
t.a=s
return t.a(a)},
fJ(a){var t=this
if(a==null)return A.aD(t)
return A.en(v.typeUniverse,A.hi(a,t),t)},
fL(a){if(a==null)return!0
return this.x.b(a)},
fX(a){var t,s=this
if(a==null)return A.aD(s)
t=s.f
if(a instanceof A.m)return!!a[t]
return!!J.am(a)[t]},
fS(a){var t,s=this
if(a==null)return A.aD(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.m)return!!a[t]
return!!J.am(a)[t]},
fR(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.m)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
ee(a){if(typeof a=="object"){if(a instanceof A.m)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
fI(a){var t=this
if(a==null){if(A.aD(t))return a}else if(t.b(a))return a
throw A.y(A.ea(a,t),new Error())},
fK(a){var t=this
if(a==null||t.b(a))return a
throw A.y(A.ea(a,t),new Error())},
ea(a,b){return new A.aA("TypeError: "+A.dX(a,A.E(b,null)))},
ek(a,b,c,d){if(A.en(v.typeUniverse,a,b))return a
throw A.y(A.fp("The type argument '"+A.E(a,null)+"' is not a subtype of the type variable bound '"+A.E(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
dX(a,b){return A.bq(a)+": type '"+A.E(A.di(a),null)+"' is not a subtype of type '"+b+"'"},
fp(a){return new A.aA("TypeError: "+a)},
M(a,b){return new A.aA("TypeError: "+A.dX(a,b))},
fP(a){var t=this
return t.x.b(a)||A.d8(v.typeUniverse,t).b(a)},
fU(a){return a!=null},
e9(a){if(a!=null)return a
throw A.y(A.M(a,"Object"),new Error())},
fY(a){return!0},
fE(a){return a},
ef(a){return!1},
dh(a){return!0===a||!1===a},
fz(a){if(!0===a)return!0
if(!1===a)return!1
throw A.y(A.M(a,"bool"),new Error())},
N(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.y(A.M(a,"bool?"),new Error())},
df(a){if(typeof a=="number")return a
throw A.y(A.M(a,"double"),new Error())},
fA(a){if(typeof a=="number")return a
if(a==null)return a
throw A.y(A.M(a,"double?"),new Error())},
ed(a){return typeof a=="number"&&Math.floor(a)===a},
cM(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.y(A.M(a,"int"),new Error())},
fB(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.y(A.M(a,"int?"),new Error())},
fT(a){return typeof a=="number"},
t(a){if(typeof a=="number")return a
throw A.y(A.M(a,"num"),new Error())},
p(a){if(typeof a=="number")return a
if(a==null)return a
throw A.y(A.M(a,"num?"),new Error())},
fW(a){return typeof a=="string"},
a8(a){if(typeof a=="string")return a
throw A.y(A.M(a,"String"),new Error())},
bZ(a){if(typeof a=="string")return a
if(a==null)return a
throw A.y(A.M(a,"String?"),new Error())},
fC(a){if(A.ee(a))return a
throw A.y(A.M(a,"JSObject"),new Error())},
fD(a){if(a==null)return a
if(A.ee(a))return a
throw A.y(A.M(a,"JSObject?"),new Error())},
eg(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.E(a[r],b)
return t},
h1(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.eg(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.E(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
eb(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.n([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.l(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.f(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.E(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.E(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.E(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.E(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.E(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
E(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.E(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.E(a.x,b)+">"
if(m===8){q=A.h6(a.x)
p=a.y
return p.length>0?q+("<"+A.eg(p,b)+">"):q}if(m===10)return A.h1(a,b)
if(m===11)return A.eb(a,b,null)
if(m===12)return A.eb(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.f(b,o)
return b[o]}return"?"},
h6(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
fy(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fx(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.cK(a,b,!1)
else if(typeof n=="number"){t=n
s=A.be(a,5,"#")
r=A.cL(t)
for(q=0;q<t;++q)r[q]=s
p=A.bd(a,b,r)
o[b]=p
return p}else return n},
fw(a,b){return A.e7(a.tR,b)},
fv(a,b){return A.e7(a.eT,b)},
cK(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.e0(A.dZ(a,null,b,!1))
s.set(b,t)
return t},
bf(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.e0(A.dZ(a,b,c,!0))
r.set(c,s)
return s},
e6(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.dd(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
a7(a,b){b.a=A.fM
b.b=A.fN
return b},
be(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.Q(null,null)
t.w=b
t.as=c
s=A.a7(a,t)
a.eC.set(c,s)
return s},
e4(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.ft(a,b,s,c)
a.eC.set(s,t)
return t},
ft(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.an(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aD(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.Q(null,null)
r.w=6
r.x=b
r.as=c
return A.a7(a,r)},
e3(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fr(a,b,s,c)
a.eC.set(s,t)
return t},
fr(a,b,c,d){var t,s
if(d){t=b.w
if(A.an(b)||b===u.K)return b
else if(t===1)return A.bd(a,"dA",[b])
else if(b===u.P||b===u.T)return u.Q}s=new A.Q(null,null)
s.w=7
s.x=b
s.as=c
return A.a7(a,s)},
fu(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.Q(null,null)
t.w=13
t.x=b
t.as=r
s=A.a7(a,t)
a.eC.set(r,s)
return s},
bc(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fq(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bd(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.bc(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.Q(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.a7(a,s)
a.eC.set(q,r)
return r},
dd(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.bc(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.Q(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.a7(a,p)
a.eC.set(r,o)
return o},
e5(a,b,c){var t,s,r="+"+(b+"("+A.bc(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.Q(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.a7(a,t)
a.eC.set(r,s)
return s},
e2(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.bc(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.bc(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fq(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.Q(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.a7(a,q)
a.eC.set(s,p)
return p},
de(a,b,c,d){var t,s=b.as+("<"+A.bc(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fs(a,b,c,s,d)
a.eC.set(s,t)
return t},
fs(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.cL(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.a9(a,b,s,0)
n=A.aB(a,c,s,0)
return A.de(a,o,n,c!==n)}}m=new A.Q(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.a7(a,m)},
dZ(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
e0(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.fk(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.e_(a,s,m,l,!1)
else if(r===46)s=A.e_(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.aj(a.u,a.e,l.pop()))
break
case 94:l.push(A.fu(a.u,l.pop()))
break
case 35:l.push(A.be(a.u,5,"#"))
break
case 64:l.push(A.be(a.u,2,"@"))
break
case 126:l.push(A.be(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.fm(a,l)
break
case 38:A.fl(a,l)
break
case 63:q=a.u
l.push(A.e4(q,A.aj(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.e3(q,A.aj(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.fj(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.e1(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fo(a.u,a.e,p)
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
return A.aj(a.u,a.e,n)},
fk(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
e_(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fy(t,p.x)[q]
if(o==null)A.J('No "'+q+'" in "'+A.fa(p)+'"')
d.push(A.bf(t,p,o))}else d.push(q)
return n},
fm(a,b){var t,s=a.u,r=A.dY(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bd(s,q,r))
else{t=A.aj(s,a.e,q)
switch(t.w){case 11:b.push(A.de(s,t,r,a.n))
break
default:b.push(A.dd(s,t,r))
break}}},
fj(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.dY(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.aj(q,a.e,p)
r=new A.bV()
r.a=t
r.b=o
r.c=n
b.push(A.e2(q,s,r))
return
case-4:b.push(A.e5(q,b.pop(),t))
return
default:throw A.c(A.bj("Unexpected state under `()`: "+A.q(p)))}},
fl(a,b){var t=b.pop()
if(0===t){b.push(A.be(a.u,1,"0&"))
return}if(1===t){b.push(A.be(a.u,4,"1&"))
return}throw A.c(A.bj("Unexpected extended operation "+A.q(t)))},
dY(a,b){var t=b.splice(a.p)
A.e1(a.u,a.e,t)
a.p=b.pop()
return t},
aj(a,b,c){if(typeof c=="string")return A.bd(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.fn(a,b,c)}else return c},
e1(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.aj(a,b,c[t])},
fo(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.aj(a,b,c[t])},
fn(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.c(A.bj("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.c(A.bj("Bad index "+c+" for "+b.j(0)))},
en(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.x(a,b,null,c,null)
s.set(c,t)}return t},
x(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.an(d))return!0
t=b.w
if(t===4)return!0
if(A.an(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.x(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.x(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.x(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.x(a,b.x,c,d,e))return!1
return A.x(a,A.d8(a,b),c,d,e)}if(t===6)return A.x(a,q,c,d,e)&&A.x(a,b.x,c,d,e)
if(r===7){if(A.x(a,b,c,d.x,e))return!0
return A.x(a,b,c,A.d8(a,d),e)}if(r===6)return A.x(a,b,c,q,e)||A.x(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.J)return!0
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
if(!A.x(a,k,c,j,e)||!A.x(a,j,e,k,c))return!1}return A.ec(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.ec(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.fQ(a,b,c,d,e)}if(p&&r===10)return A.fV(a,b,c,d,e)
return!1},
ec(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.x(a2,a3.x,a4,a5.x,a6))return!1
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
if(!A.x(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.x(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.x(a2,l[i],a6,h,a4))return!1}g=t.c
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
if(!A.x(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
fQ(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bf(a,b,s[p])
return A.e8(a,q,null,c,d.y,e)}return A.e8(a,b.y,null,c,d.y,e)},
e8(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.x(a,b[t],d,e[t],f))return!1
return!0},
fV(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.x(a,s[t],c,r[t],e))return!1
return!0},
aD(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.an(a))if(t!==6)s=t===7&&A.aD(a.x)
return s},
an(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
e7(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
cL(a){return a>0?new Array(a):v.typeUniverse.sEA},
Q:function Q(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
bV:function bV(){this.c=this.b=this.a=null},
cJ:function cJ(a){this.a=a},
bU:function bU(){},
aA:function aA(a){this.a=a},
K(a,b,c){return b.i("@<0>").I(c).i("dJ<1,2>").a(A.hb(a,new A.ae(b.i("@<0>").I(c).i("ae<1,2>"))))},
dK(a,b){return new A.ae(a.i("@<0>").I(b).i("ae<1,2>"))},
d4(a){return new A.b5(a.i("b5<0>"))},
dc(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
fi(a,b,c){var t=new A.ai(a,b,c.i("ai<0>"))
t.c=a.e
return t},
dM(a){var t,s
if(A.dn(a))return"{...}"
t=new A.aw("")
try{s={}
B.a.l($.I,a)
t.a+="{"
s.a=!0
a.R(0,new A.cr(s,t))
t.a+="}"}finally{if(0>=$.I.length)return A.f($.I,-1)
$.I.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
b5:function b5(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
bY:function bY(a){this.a=a
this.c=this.b=null},
ai:function ai(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
i:function i(){},
F:function F(){},
cr:function cr(a,b){this.a=a
this.b=b},
av:function av(){},
bb:function bb(){},
h0(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.eu(s)
r=A.br(String(t))
throw A.c(r)}r=A.cN(q)
return r},
cN(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.bW(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.cN(a[t])
return a},
dI(a,b,c){return new A.aN(a,b)},
fG(a){return a.U()},
fg(a,b){return new A.cF(a,[],A.h8())},
fh(a,b,c){var t,s=new A.aw(""),r=A.fg(s,b)
r.a4(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
bW:function bW(a,b){this.a=a
this.b=b
this.c=null},
bX:function bX(a){this.a=a},
bm:function bm(){},
bo:function bo(){},
aN:function aN(a,b){this.a=a
this.b=b},
bA:function bA(a,b){this.a=a
this.b=b},
cn:function cn(){},
cp:function cp(a){this.b=a},
co:function co(a){this.a=a},
cG:function cG(){},
cH:function cH(a,b){this.a=a
this.b=b},
cF:function cF(a,b,c){this.c=a
this.a=b
this.b=c},
d6(a,b,c,d){var t,s=c?J.dG(a,d):J.dF(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
dL(a,b,c){var t,s,r=A.n([],c.i("l<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.O)(a),++s)B.a.l(r,c.a(a[s]))
if(b)return r
r.$flags=1
return r},
d5(a,b){var t,s=A.n([],b.i("l<0>"))
for(t=a.gv(a);t.n();)B.a.l(s,t.gq())
return s},
dT(a,b,c){var t=J.du(b)
if(!t.n())return a
if(c.length===0){do a+=A.q(t.gq())
while(t.n())}else{a+=A.q(t.gq())
while(t.n())a=a+c+A.q(t.gq())}return a},
bq(a){if(typeof a=="number"||A.dh(a)||a==null)return J.bh(a)
if(typeof a=="string")return JSON.stringify(a)
return A.dQ(a)},
bj(a){return new A.bi(a)},
c0(a){return new A.U(!1,null,null,a)},
eM(a,b,c){return new A.U(!0,a,b,c)},
aX(a,b,c,d,e){return new A.aW(b,c,!0,a,d,"Invalid value")},
f8(a,b,c){if(0>a||a>c)throw A.c(A.aX(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.c(A.aX(b,a,c,"end",null))
return b}return c},
d7(a,b){if(a<0)throw A.c(A.aX(a,0,null,b,null))
return a},
d_(a,b,c,d){return new A.bt(b,!0,a,d,"Index out of range")},
db(a){return new A.b3(a)},
dW(a){return new A.bS(a)},
bP(a){return new A.b_(a)},
P(a){return new A.bn(a)},
br(a){return new A.V(a)},
f0(a,b,c){var t,s
if(A.dn(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.n([],u.s)
B.a.l($.I,a)
try{A.fZ(a,t)}finally{if(0>=$.I.length)return A.f($.I,-1)
$.I.pop()}s=A.dT(b,u.Y.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
d0(a,b,c){var t,s
if(A.dn(a))return b+"..."+c
t=new A.aw(b)
B.a.l($.I,a)
try{s=t
s.a=A.dT(s.a,a,", ")}finally{if(0>=$.I.length)return A.f($.I,-1)
$.I.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
fZ(a,b){var t,s,r,q,p,o,n,m=a.gv(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.n())return
t=A.q(m.gq())
B.a.l(b,t)
l+=t.length+2;++k}if(!m.n()){if(k<=5)return
if(0>=b.length)return A.f(b,-1)
s=b.pop()
if(0>=b.length)return A.f(b,-1)
r=b.pop()}else{q=m.gq();++k
if(!m.n()){if(k<=4){B.a.l(b,A.q(q))
return}s=A.q(q)
if(0>=b.length)return A.f(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gq();++k
for(;m.n();q=p,p=o){o=m.gq();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.f(b,-1)
l-=b.pop().length+2;--k}B.a.l(b,"...")
return}}r=A.q(q)
s=A.q(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.f(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.l(b,n)
B.a.l(b,r)
B.a.l(b,s)},
dO(a,b,c,d){var t
if(B.f===c){t=J.G(a)
b=J.G(b)
return A.da(A.a6(A.a6($.cZ(),t),b))}if(B.f===d){t=J.G(a)
b=J.G(b)
c=J.G(c)
return A.da(A.a6(A.a6(A.a6($.cZ(),t),b),c))}t=J.G(a)
b=J.G(b)
c=J.G(c)
d=J.G(d)
d=A.da(A.a6(A.a6(A.a6(A.a6($.cZ(),t),b),c),d))
return d},
o:function o(){},
bi:function bi(a){this.a=a},
b1:function b1(){},
U:function U(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aW:function aW(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bt:function bt(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
b3:function b3(a){this.a=a},
bS:function bS(a){this.a=a},
b_:function b_(a){this.a=a},
bn:function bn(a){this.a=a},
aZ:function aZ(){},
V:function V(a){this.a=a},
d:function d(){},
aU:function aU(){},
m:function m(){},
cz:function cz(){this.b=this.a=0},
aw:function aw(a){this.a=a},
eU(a){var t,s,r,q,p,o,n,m,l,k,j=null,i=a.h(0,"aspects")
if(i==null)i=a.h(0,"enemyAspects")
if(u.j.b(i)&&J.eJ(i)){t=J.eL(i,new A.c3(),u.i)
s=A.d5(t,t.$ti.i("D.E"))}else s=B.o
t=A.p(a.h(0,"areaMultiplier"))
if(t==null)t=j
if(t==null){t=A.p(a.h(0,"enemyAreaMultiplier"))
if(t==null)t=j}if(t==null)t=2
r=A.p(a.h(0,"angleMinDeg"))
if(r==null)r=j
if(r==null)r=30
q=A.p(a.h(0,"angleMaxDeg"))
if(q==null)q=j
if(q==null)q=60
p=A.p(a.h(0,"speedMin"))
if(p==null)p=j
if(p==null)p=75
o=A.p(a.h(0,"speedMax"))
if(o==null)o=j
if(o==null)o=105
n=A.p(a.h(0,"accelMin"))
if(n==null)n=j
if(n==null)n=9
m=A.p(a.h(0,"accelMax"))
if(m==null)m=j
if(m==null)m=15
l=A.N(a.h(0,"collideWithEachOther"))
if(l==null)l=A.N(a.h(0,"enemiesCollide"))
k=A.p(a.h(0,"spinDegPerSec"))
if(k==null)k=j
if(k==null)k=0
return new A.bp(t,s,r,q,p,o,n,m,l===!0,k)},
dB(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=null,c="warning",b=A.N(a0.h(0,"startHintEnabled")),a=A.p(a0.h(0,"idleSpeedMultiplier"))
if(a==null)a=d
if(a==null)a=0.5
t=A.N(a0.h(0,"idleEnemiesMove"))
s=A.p(a0.h(0,"speedRampSeconds"))
if(s==null)s=d
if(s==null)s=0.5
r=A.N(a0.h(0,"jumpEnabled"))
if(r==null)r=A.N(a0.h(0,"jumpsEnabled"))
q=A.p(a0.h(0,"jumpDurationSec"))
if(q==null)q=d
if(q==null)q=0.38
p=A.p(a0.h(0,"jumpCooldownSec"))
if(p==null)p=d
if(p==null)p=2
o=A.p(a0.h(0,"jumpScale"))
if(o==null)o=d
if(o==null)o=1.32
n=A.N(a0.h(0,"helmetEnabled"))
m=A.p(a0.h(0,"helmetInvulnSec"))
if(m==null)m=d
if(m==null)m=0.3
l=A.p(a0.h(0,"startInvulnSec"))
if(l==null)l=d
if(l==null)l=1
k=A.N(a0.h(0,"heartbeatHaptic"))
j=A.N(a0.h(0,"timerHaptic"))
i=A.bZ(a0.h(0,"timerHapticStyle"))
if(i==null)i=c
h=A.bZ(a0.h(0,"timerHapticStyle5"))
if(h==null)h=c
g=A.bZ(a0.h(0,"timerHapticStyle10"))
if(g==null)g=c
f=A.p(a0.h(0,"hudSpeedScaleMax"))
if(f==null)f=d
if(f==null)f=400
e=A.N(a0.h(0,"wallsKillPlayer"))
return new A.c7(b!==!1,a,t!==!1,s,r!==!1,q,p,o,n!==!1,m,l,k!==!1,j!==!1,i,h,g,f,e!==!1)},
dN(a,b){if(a==null)return b
if(typeof a!="number"||!isFinite(a)||a<0||a>0.5)throw A.c(B.B)
return a},
ck:function ck(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bp:function bp(a,b,c,d,e,f,g,h,i,j){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j},
c3:function c3(){},
cu:function cu(a,b){this.a=a
this.b=b},
c6:function c6(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
c7:function c7(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.y=j
_.z=k
_.Q=l
_.as=m
_.at=n
_.ax=o
_.ay=p
_.ch=q
_.CW=r},
c1:function c1(){},
cs:function cs(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dD(a,b){return new A.v(Math.max(a.a,b.a),Math.max(a.b,b.b),Math.min(a.c,b.c),Math.min(a.d,b.d))},
b:function b(a,b){this.a=a
this.b=b},
cy:function cy(a,b){this.a=a
this.b=b},
v:function v(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bs(a,b){var t
if(isFinite(a)&&a>0)t=isFinite(b)&&b>0&&Math.abs(a/b-1)<=0.030000001
else t=!1
return t},
eX(a3,a4,a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
try{g=a5.a
if(isFinite(g)&&g>0){f=a5.b
f=isFinite(f)&&f>0}else f=!1
e=!0
if(f){f=a4.c-a4.a
d=a4.d-a4.b
if(isFinite(f)&&f>0&&isFinite(d)&&d>0){f=a6.c-a6.a
d=a6.d-a6.b
if(isFinite(f)&&f>0&&isFinite(d)&&d>0)f=!(isFinite(a3)&&a3>0)
else f=e}else f=e}else f=e
if(f)return"field_not_ready"
f=a4.a
e=a4.b
if(isFinite(f)&&isFinite(e))d=!(isFinite(a6.a)&&isFinite(a6.b))
else d=!0
if(d)return"field_position"
d=a7.b
c=d.a
if(!A.bs(c,380)||!A.bs(d.b,380))return"world_scale"
if(!A.bs(g,a5.b)||!A.bs(a4.c-f,a4.d-e))return"field_distorted"
t=A.dD(a4,a6)
g=t
if(!(g.c-g.a<=0||g.d-g.b<=0)){g=t
b=t
b=(g.c-g.a)*(b.d-b.b)/((a4.c-f)*(a4.d-e))<0.97
g=b}else g=!0
if(g)return"field_clipped"
g=a7.a
b=g.b.a*1.2
s=b/c
r=b/380
a=!0
if(A.bs(s,r)){a0=s
if(typeof a0!=="number")return a0.a5()
if(!(a0<0.03)){a=s
if(typeof a!=="number")return a.bB()
a=a>0.25}}if(a)return"hero_scale"
q=(a4.c-f)/c
p=(a4.d-e)/d.b
o=new A.ca(a7)
n=new A.c9(q,p,a3)
f=a7.e
f===$&&A.j()
e=f.a
f=f.b
if(!o.$1(new A.v(e,f,e+b,f+b))||!n.$2(b,b))return"hero_invisible"
g=g.a
f=g.b
e=A.A(f)
d=e.i("ah<1>")
a1=A.d5(new A.ah(f,e.i("w(1)").a(new A.c8()),d),d.i("d.E"))
m=a1
if(J.a1(m)===0)J.dr(m,A.n([1,0.25,0.5,3],u.t))
f=a7.f
if(f.length!==4||J.a1(m)!==4)return"enemy_count"
l=b*b*B.b.m(g.a,0.2,20)
k=0
for(;;){g=k
if(typeof g!=="number")return g.a5()
if(!(g<4))break
j=B.a.h(f,k)
g=l
e=J.a0(m,k)
if(typeof g!=="number")return g.W()
i=Math.sqrt(g*e)
e=l
g=J.a0(m,k)
if(typeof e!=="number")return e.ao()
h=Math.sqrt(e/g)
g=j.y
e=i
if(isFinite(g)&&g>0)g=isFinite(e)&&e>0&&Math.abs(g/e-1)<=0.030000001
else g=!1
if(g){g=j.z
e=h
if(isFinite(g)&&g>0)g=isFinite(e)&&e>0&&Math.abs(g/e-1)<=0.030000001
else g=!1
g=!g}else g=!0
if(g)return"enemy_scale"
g=j.a
e=!0
if(isFinite(g.a)&&isFinite(g.b)){g=j.c
g===$&&A.j()
if(isFinite(g.a)&&isFinite(g.b))if(isFinite(j.CW))if(o.$1(j.gA())){g=j.c
g===$&&A.j()
g=g.a
e=j.c
e===$&&A.j()
e=e.b
g=!o.$1(new A.v(g,e,g+j.y,e+j.z))||!n.$2(j.y,j.z)}else g=e
else g=e
else g=e}else g=e
if(g)return"enemy_invisible"
g=j.b
if(isFinite(g.a)&&isFinite(g.b)){g=j.d
g===$&&A.j()
g=!(isFinite(g.a)&&isFinite(g.b))||!isFinite(j.ay)||j.ay<0||!isFinite(j.ch)||j.ch<0}else g=!0
if(g)return"enemy_motion"
g=k
if(typeof g!=="number")return g.G()
k=g+1}return null}catch(a2){return"world_not_ready"}},
ca:function ca(a){this.a=a},
c9:function c9(a,b,c){this.a=a
this.b=b
this.c=c},
c8:function c8(){},
hm(){var t,s,r={}
r.a=null
t=v.G.globalThis
r=new A.cX(r)
if(typeof r=="function")A.J(A.c0("Attempting to rewrap a JS function."))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.fF,r)
s[$.dq()]=r
t.untouchKernel=s},
cX:function cX(a){this.a=a},
f9(a){var t,s,r,q
for(t=new A.aG(a),s=u.V,t=new A.X(t,t.gk(0),s.i("X<i.E>")),s=s.i("i.E"),r=2166136261;t.n();){q=t.d
r=(r^(q==null?s.a(q):q))>>>0
r=r*403+((r&255)<<24>>>0)>>>0}return r===0?1:r},
bN:function bN(a){this.a=a},
c5:function c5(a,b){this.a=a
this.b=b},
c2:function c2(a){var _=this
_.e=_.d=_.c=_.b=_.a=$
_.r=_.f=0
_.y=_.x=_.w=!1
_.z=null
_.at=_.as=_.Q=0
_.ax=a
_.ay=null},
dC(a,b){var t,s
if(a.V(b))return 0
t=Math.max(0,Math.max(a.a-b.c,b.a-a.c))
s=Math.max(0,Math.max(a.b-b.d,b.b-a.d))
if(t>0&&s>0)return Math.sqrt(t*t+s*s)
return Math.max(t,s)},
aF:function aF(a,b){this.a=a
this.b=b},
a5:function a5(a){this.a=a
this.b=0},
ac:function ac(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.d=_.c=$
_.e=0
_.f=1.4
_.r=1.1
_.w=0
_.x=1
_.y=c
_.z=d
_.ay=e
_.ch=f
_.CW=g
_.cx=h},
c4:function c4(a,b,c){this.a=a
this.b=b
this.c=c},
cb:function cb(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=$
_.f=e
_.r=0
_.w=f
_.z=_.y=_.x=0
_.Q=g
_.as=h
_.at=i},
ch:function ch(a){this.a=a},
cg:function cg(){},
ci:function ci(){},
cc:function cc(){},
cd:function cd(){},
ce:function ce(){},
cf:function cf(){},
cj:function cj(a){this.a=a},
fF(a,b,c){u.Z.a(a)
if(A.cM(c)>=1)return a.$1(b)
return a.$0()},
ep(a,b,c){A.ek(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
eo(a,b,c){A.ek(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.d2.prototype={}
J.bv.prototype={
H(a,b){return a===b},
gt(a){return A.bL(a)},
j(a){return"Instance of '"+A.bM(a)+"'"},
gp(a){return A.Z(A.dg(this))}}
J.bx.prototype={
j(a){return String(a)},
gt(a){return a?519018:218159},
gp(a){return A.Z(u.y)},
$ik:1,
$iw:1}
J.aJ.prototype={
H(a,b){return null==b},
j(a){return"null"},
gt(a){return 0},
$ik:1}
J.aL.prototype={$iu:1}
J.a4.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.bK.prototype={}
J.ax.prototype={}
J.a3.prototype={
j(a){var t=a[$.ev()]
if(t==null)t=a[$.dq()]
if(t==null)return this.aV(a)
return"JavaScript function for "+J.bh(t)},
$iW:1}
J.aK.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.aM.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.l.prototype={
l(a,b){A.A(a).c.a(b)
a.$flags&1&&A.aE(a,29)
a.push(b)},
b4(a,b,c){var t,s,r,q,p
A.A(a).i("w(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.c(A.P(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
M(a,b){A.A(a).i("d<1>").a(b)
a.$flags&1&&A.aE(a,"addAll",2)
this.aX(a,b)
return},
aX(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.c(A.P(a))
for(s=0;s<t;++s)a.push(b[s])},
E(a){a.$flags&1&&A.aE(a,"clear","clear")
a.length=0},
aK(a,b,c){var t=A.A(a)
return new A.L(a,t.I(c).i("1(2)").a(b),t.i("@<1>").I(c).i("L<1,2>"))},
bh(a,b){var t,s=A.d6(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.u(s,t,A.q(a[t]))
return s.join(b)},
B(a,b){if(!(b>=0&&b<a.length))return A.f(a,b)
return a[b]},
gF(a){if(a.length>0)return a[0]
throw A.c(A.dE())},
af(a,b){var t,s
A.A(a).i("w(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.c(A.P(a))}return!1},
ap(a,b){var t,s,r,q
a.$flags&2&&A.aE(a,"shuffle")
t=a.length
while(t>1){s=b.bl(t);--t
r=a.length
if(!(t<r))return A.f(a,t)
q=a[t]
if(!(s>=0&&s<r))return A.f(a,s)
a[t]=a[s]
a[s]=q}},
gan(a){return a.length!==0},
j(a){return A.d0(a,"[","]")},
gv(a){return new J.ab(a,a.length,A.A(a).i("ab<1>"))},
gt(a){return A.bL(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.aE(a,"set length","change the length of")
if(b>a.length)A.A(a).c.a(null)
a.length=b},
h(a,b){if(!(b>=0&&b<a.length))throw A.c(A.cP(a,b))
return a[b]},
u(a,b,c){A.A(a).c.a(c)
a.$flags&2&&A.aE(a)
if(!(b>=0&&b<a.length))throw A.c(A.cP(a,b))
a[b]=c},
$id:1,
$ih:1}
J.bw.prototype={
bv(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bM(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.cl.prototype={}
J.ab.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.O(r)
throw A.c(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$ia2:1}
J.aq.prototype={
ag(a,b){var t
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gam(b)
if(this.gam(a)===t)return 0
if(this.gam(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gam(a){return a===0?1/a<0:a<0},
b9(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.c(A.db(""+a+".ceil()"))},
ak(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.c(A.db(""+a+".floor()"))},
bp(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.c(A.db(""+a+".round()"))},
m(a,b,c){if(this.ag(b,c)>0)throw A.c(A.ei(b))
if(this.ag(a,b)<0)return b
if(this.ag(a,c)>0)return c
return a},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gt(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
a6(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
aE(a,b){var t
if(a>0)t=this.b5(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
b5(a,b){return b>31?0:a>>>b},
gp(a){return A.Z(u.H)},
$ie:1,
$iR:1}
J.aI.prototype={
gp(a){return A.Z(u.S)},
$ik:1,
$ia:1}
J.by.prototype={
gp(a){return A.Z(u.i)},
$ik:1}
J.ar.prototype={
Y(a,b,c){return a.substring(b,A.f8(b,c,a.length))},
aO(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.f(q,0)
if(q.charCodeAt(0)===133){t=J.f2(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.f(q,s)
r=q.charCodeAt(s)===133?J.f3(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
j(a){return a},
gt(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gp(a){return A.Z(u.N)},
gk(a){return a.length},
$ik:1,
$ir:1}
A.af.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.aG.prototype={
gk(a){return this.a.length},
h(a,b){var t=this.a
if(!(b>=0&&b<t.length))return A.f(t,b)
return t.charCodeAt(b)}}
A.cx.prototype={}
A.aH.prototype={}
A.D.prototype={
gv(a){var t=this
return new A.X(t,t.gk(t),A.c_(t).i("X<D.E>"))},
gS(a){return this.gk(this)===0},
a3(a,b){var t,s,r,q=this
A.c_(q).i("D.E(D.E,D.E)").a(b)
t=q.gk(q)
if(t===0)throw A.c(A.dE())
s=q.B(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.B(0,r))
if(t!==q.gk(q))throw A.c(A.P(q))}return s}}
A.b0.prototype={
gb_(){var t=J.a1(this.a),s=this.c
if(s==null||s>t)return t
return s},
gb7(){var t=J.a1(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.a1(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
B(a,b){var t=this,s=t.gb7()+b
if(b<0||s>=t.gb_())throw A.c(A.d_(b,t.gk(0),t,"index"))
return J.dt(t.a,s)},
bu(a,b){var t,s,r,q=this,p=q.b,o=q.a,n=J.bg(o),m=n.gk(o),l=q.c
if(l!=null&&l<m)m=l
t=m-p
if(t<=0){o=q.$ti.c
return b?J.dG(0,o):J.dF(0,o)}s=A.d6(t,n.B(o,p),b,q.$ti.c)
for(r=1;r<t;++r){B.a.u(s,r,n.B(o,p+r))
if(n.gk(o)<m)throw A.c(A.P(q))}return s},
aN(a){return this.bu(0,!0)}}
A.X.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=J.bg(r),p=q.gk(r)
if(s.b!==p)throw A.c(A.P(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.B(r,t);++s.c
return!0},
$ia2:1}
A.L.prototype={
gk(a){return J.a1(this.a)},
B(a,b){return this.b.$1(J.dt(this.a,b))}}
A.ah.prototype={
gv(a){return new A.b4(J.du(this.a),this.b,this.$ti.i("b4<1>"))}}
A.b4.prototype={
n(){var t,s
for(t=this.a,s=this.b;t.n();)if(s.$1(t.gq()))return!0
return!1},
gq(){return this.a.gq()},
$ia2:1}
A.C.prototype={}
A.b2.prototype={}
A.ay.prototype={}
A.ba.prototype={$r:"+(1,2)",$s:1}
A.bu.prototype={
H(a,b){if(b==null)return!1
return b instanceof A.ad&&this.a.H(0,b.a)&&A.dl(this)===A.dl(b)},
gt(a){return A.dO(this.a,A.dl(this),B.f,B.f)},
j(a){var t=B.a.bh([A.Z(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.ad.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hj(A.cO(this.a),this.$ti)}}
A.cv.prototype={
$0(){return B.b.ak(1000*this.a.now())},
$S:1}
A.aY.prototype={}
A.cA.prototype={
C(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
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
A.aV.prototype={
j(a){return"Null check operator used on a null value"}}
A.bz.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bT.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.ct.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.B.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.et(s==null?"unknown":s)+"'"},
$iW:1,
gbA(){return this},
$C:"$1",
$R:1,
$D:null}
A.bk.prototype={$C:"$0",$R:0}
A.bl.prototype={$C:"$2",$R:2}
A.bR.prototype={}
A.bQ.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.et(t)+"'"}}
A.ap.prototype={
H(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.ap))return!1
return this.$_target===b.$_target&&this.a===b.a},
gt(a){return(A.eq(this.a)^A.bL(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bM(this.a)+"'")}}
A.bO.prototype={
j(a){return"RuntimeError: "+this.a}}
A.ae.prototype={
gk(a){return this.a},
gS(a){return this.a===0},
gT(){return new A.ag(this,this.$ti.i("ag<1>"))},
M(a,b){this.$ti.i("as<1,2>").a(b).R(0,new A.cm(this))},
h(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.bg(b)},
bg(a){var t,s,r=this.d
if(r==null)return null
t=r[J.G(a)&1073741823]
s=this.aH(t,a)
if(s<0)return null
return t[s].b},
u(a,b,c){var t,s,r,q,p,o,n=this,m=n.$ti
m.c.a(b)
m.y[1].a(c)
if(typeof b=="string"){t=n.b
n.aq(t==null?n.b=n.ad():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=n.c
n.aq(s==null?n.c=n.ad():s,b,c)}else{r=n.d
if(r==null)r=n.d=n.ad()
q=J.G(b)&1073741823
p=r[q]
if(p==null)r[q]=[n.a8(b,c)]
else{o=n.aH(p,b)
if(o>=0)p[o].b=c
else p.push(n.a8(b,c))}}},
R(a,b){var t,s,r=this
r.$ti.i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.c(A.P(r))
t=t.c}},
aq(a,b,c){var t,s=this.$ti
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.a8(b,c)
else t.b=c},
a8(a,b){var t=this,s=t.$ti,r=new A.cq(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
aH(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.T(a[s].a,b))return s
return-1},
j(a){return A.dM(this)},
ad(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$idJ:1}
A.cm.prototype={
$2(a,b){var t=this.a,s=t.$ti
t.u(0,s.c.a(a),s.y[1].a(b))},
$S(){return this.a.$ti.i("~(1,2)")}}
A.cq.prototype={}
A.ag.prototype={
gk(a){return this.a.a},
gS(a){return this.a.a===0},
gv(a){var t=this.a
return new A.aP(t,t.r,t.e,this.$ti.i("aP<1>"))}}
A.aP.prototype={
gq(){return this.d},
n(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.c(A.P(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$ia2:1}
A.cT.prototype={
$1(a){return this.a(a)},
$S:2}
A.cU.prototype={
$2(a,b){return this.a(a,b)},
$S:6}
A.cV.prototype={
$1(a){return this.a(A.a8(a))},
$S:7}
A.ak.prototype={
j(a){return this.aF(!1)},
aF(a){var t,s,r,q,p,o=this.b0(),n=this.az(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.f(n,r)
p=n[r]
m=a?m+A.dQ(p):m+A.q(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
b0(){var t,s=this.$s
while($.cI.length<=s)B.a.l($.cI,null)
t=$.cI[s]
if(t==null){t=this.aY()
B.a.u($.cI,s,t)}return t},
aY(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=u.K,k=J.d1(m,l)
for(t=0;t<m;++t)k[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.u(k,r,s[t])}}k=A.dL(k,!1,l)
k.$flags=3
return k}}
A.az.prototype={
az(){return[this.a,this.b]},
H(a,b){if(b==null)return!1
return b instanceof A.az&&this.$s===b.$s&&J.T(this.a,b.a)&&J.T(this.b,b.b)},
gt(a){return A.dO(this.$s,this.a,this.b,B.f)}}
A.cC.prototype={
L(){var t=this.b
if(t===this)throw A.c(new A.af("Local '' has not been initialized."))
return t}}
A.at.prototype={
gp(a){return B.O},
$ik:1}
A.aS.prototype={}
A.bB.prototype={
gp(a){return B.P},
$ik:1}
A.au.prototype={
gk(a){return a.length},
$iH:1}
A.aQ.prototype={
h(a,b){A.al(b,a,a.length)
return a[b]},
$id:1,
$ih:1}
A.aR.prototype={$id:1,$ih:1}
A.bC.prototype={
gp(a){return B.Q},
$ik:1}
A.bD.prototype={
gp(a){return B.R},
$ik:1}
A.bE.prototype={
gp(a){return B.S},
h(a,b){A.al(b,a,a.length)
return a[b]},
$ik:1}
A.bF.prototype={
gp(a){return B.T},
h(a,b){A.al(b,a,a.length)
return a[b]},
$ik:1}
A.bG.prototype={
gp(a){return B.U},
h(a,b){A.al(b,a,a.length)
return a[b]},
$ik:1}
A.bH.prototype={
gp(a){return B.W},
h(a,b){A.al(b,a,a.length)
return a[b]},
$ik:1}
A.bI.prototype={
gp(a){return B.X},
h(a,b){A.al(b,a,a.length)
return a[b]},
$ik:1}
A.aT.prototype={
gp(a){return B.Y},
gk(a){return a.length},
h(a,b){A.al(b,a,a.length)
return a[b]},
$ik:1}
A.bJ.prototype={
gp(a){return B.Z},
gk(a){return a.length},
h(a,b){A.al(b,a,a.length)
return a[b]},
$ik:1}
A.b6.prototype={}
A.b7.prototype={}
A.b8.prototype={}
A.b9.prototype={}
A.Q.prototype={
i(a){return A.bf(v.typeUniverse,this,a)},
I(a){return A.e6(v.typeUniverse,this,a)}}
A.bV.prototype={}
A.cJ.prototype={
j(a){return A.E(this.a,null)}}
A.bU.prototype={
j(a){return this.a}}
A.aA.prototype={}
A.b5.prototype={
gv(a){var t=this,s=new A.ai(t,t.r,t.$ti.i("ai<1>"))
s.c=t.e
return s},
gk(a){return this.a},
ah(a,b){var t
if((b&1073741823)===b){t=this.c
if(t==null)return!1
return u.L.a(t[b])!=null}else return this.aZ(b)},
aZ(a){var t=this.d
if(t==null)return!1
return this.aw(t[B.c.gt(a)&1073741823],a)>=0},
l(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.ar(t==null?r.b=A.dc():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.ar(s==null?r.c=A.dc():s,b)}else return r.aW(b)},
aW(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.dc()
s=J.G(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.ae(a)]
else{if(q.aw(r,a)>=0)return!1
r.push(q.ae(a))}return!0},
E(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.aA()}},
ar(a,b){this.$ti.c.a(b)
if(u.L.a(a[b])!=null)return!1
a[b]=this.ae(b)
return!0},
aA(){this.r=this.r+1&1073741823},
ae(a){var t,s=this,r=new A.bY(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.aA()
return r},
aw(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.T(a[s].a,b))return s
return-1}}
A.bY.prototype={}
A.ai.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.c(A.P(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.i("1?").a(s.a)
t.c=s.b
return!0}},
$ia2:1}
A.i.prototype={
gv(a){return new A.X(a,this.gk(a),A.aa(a).i("X<i.E>"))},
B(a,b){return this.h(a,b)},
gan(a){return this.gk(a)!==0},
af(a,b){var t,s
A.aa(a).i("w(i.E)").a(b)
t=this.gk(a)
for(s=0;s<t;++s){if(b.$1(this.h(a,s)))return!0
if(t!==this.gk(a))throw A.c(A.P(a))}return!1},
aK(a,b,c){var t=A.aa(a)
return new A.L(a,t.I(c).i("1(i.E)").a(b),t.i("@<i.E>").I(c).i("L<1,2>"))},
j(a){return A.d0(a,"[","]")},
$id:1,
$ih:1}
A.F.prototype={
R(a,b){var t,s,r,q=A.c_(this)
q.i("~(F.K,F.V)").a(b)
for(t=this.gT(),t=t.gv(t),q=q.i("F.V");t.n();){s=t.gq()
r=this.h(0,s)
b.$2(s,r==null?q.a(r):r)}},
gk(a){var t=this.gT()
return t.gk(t)},
gS(a){var t=this.gT()
return t.gS(t)},
j(a){return A.dM(this)},
$ias:1}
A.cr.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.q(a)
s.a=(s.a+=t)+": "
t=A.q(b)
s.a+=t},
$S:3}
A.av.prototype={
M(a,b){var t,s,r
this.$ti.i("d<1>").a(b)
for(t=A.fi(b,b.r,b.$ti.c),s=t.$ti.c;t.n();){r=t.d
this.l(0,r==null?s.a(r):r)}},
j(a){return A.d0(this,"{","}")},
$id:1,
$id9:1}
A.bb.prototype={}
A.bW.prototype={
h(a,b){var t,s=this.b
if(s==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.b2(b):t}},
gk(a){return this.b==null?this.c.a:this.a_().length},
gS(a){return this.gk(0)===0},
gT(){if(this.b==null){var t=this.c
return new A.ag(t,t.$ti.i("ag<1>"))}return new A.bX(this)},
R(a,b){var t,s,r,q,p=this
u.D.a(b)
if(p.b==null)return p.c.R(0,b)
t=p.a_()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.cN(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.c(A.P(p))}},
a_(){var t=u.d.a(this.c)
if(t==null)t=this.c=A.n(Object.keys(this.a),u.s)
return t},
b2(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.cN(this.a[a])
return this.b[a]=t}}
A.bX.prototype={
gk(a){return this.a.gk(0)},
B(a,b){var t=this.a
if(t.b==null)t=t.gT().B(0,b)
else{t=t.a_()
if(!(b>=0&&b<t.length))return A.f(t,b)
t=t[b]}return t},
gv(a){var t=this.a
if(t.b==null){t=t.gT()
t=t.gv(t)}else{t=t.a_()
t=new J.ab(t,t.length,A.A(t).i("ab<1>"))}return t}}
A.bm.prototype={}
A.bo.prototype={}
A.aN.prototype={
j(a){var t=A.bq(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.bA.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.cn.prototype={
bb(a,b){var t=A.h0(a,this.gbc().a)
return t},
a0(a,b){var t=A.fh(a,this.gbe().b,null)
return t},
gbe(){return B.L},
gbc(){return B.K}}
A.cp.prototype={}
A.co.prototype={}
A.cG.prototype={
aQ(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.d.Y(a,s,r)
s=r+1
p=A.z(92)
t.a+=p
p=A.z(117)
t.a+=p
p=A.z(100)
t.a+=p
p=q>>>8&15
p=A.z(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.z(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.z(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.d.Y(a,s,r)
s=r+1
p=A.z(92)
t.a+=p
switch(q){case 8:p=A.z(98)
t.a+=p
break
case 9:p=A.z(116)
t.a+=p
break
case 10:p=A.z(110)
t.a+=p
break
case 12:p=A.z(102)
t.a+=p
break
case 13:p=A.z(114)
t.a+=p
break
default:p=A.z(117)
t.a+=p
p=A.z(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.z(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.z(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.d.Y(a,s,r)
s=r+1
p=A.z(92)
t.a+=p
p=A.z(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.d.Y(a,s,n)},
a9(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.c(new A.bA(a,null))}B.a.l(t,a)},
a4(a){var t,s,r,q,p=this
if(p.aP(a))return
p.a9(a)
try{t=p.b.$1(a)
if(!p.aP(t)){r=A.dI(a,null,p.gaC())
throw A.c(r)}r=p.a
if(0>=r.length)return A.f(r,-1)
r.pop()}catch(q){s=A.eu(q)
r=A.dI(a,s,p.gaC())
throw A.c(r)}},
aP(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.aQ(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.a9(a)
r.by(a)
t=r.a
if(0>=t.length)return A.f(t,-1)
t.pop()
return!0}else if(a instanceof A.F){r.a9(a)
s=r.bz(a)
t=r.a
if(0>=t.length)return A.f(t,-1)
t.pop()
return s}else return!1},
by(a){var t,s,r=this.c
r.a+="["
t=J.bg(a)
if(t.gan(a)){this.a4(t.h(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.a4(t.h(a,s))}}r.a+="]"},
bz(a){var t,s,r,q,p,o,n=this,m={}
if(a.gS(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.d6(t,null,!1,u.X)
r=m.a=0
m.b=!0
a.R(0,new A.cH(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.aQ(A.a8(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.f(s,o)
n.a4(s[o])}q.a+="}"
return!0}}
A.cH.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.u(t,s.a++,a)
B.a.u(t,s.a++,b)},
$S:3}
A.cF.prototype={
gaC(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.o.prototype={}
A.bi.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bq(t)
return"Assertion failed"}}
A.b1.prototype={}
A.U.prototype={
gab(){return"Invalid argument"+(!this.a?"(s)":"")},
gaa(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+A.q(q),o=t.gab()+r+p
if(!t.a)return o
return o+t.gaa()+": "+A.bq(t.gal())},
gal(){return this.b}}
A.aW.prototype={
gal(){return A.p(this.b)},
gab(){return"RangeError"},
gaa(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.q(r):""
else if(r==null)t=": Not greater than or equal to "+A.q(s)
else if(r>s)t=": Not in inclusive range "+A.q(s)+".."+A.q(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.q(s)
return t}}
A.bt.prototype={
gal(){return A.cM(this.b)},
gab(){return"RangeError"},
gaa(){if(A.cM(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.b3.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bS.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.b_.prototype={
j(a){return"Bad state: "+this.a}}
A.bn.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bq(t)+"."}}
A.aZ.prototype={
j(a){return"Stack Overflow"},
$io:1}
A.V.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.d.prototype={
gk(a){var t,s=this.gv(this)
for(t=0;s.n();)++t
return t},
B(a,b){var t,s
A.d7(b,"index")
t=this.gv(this)
for(s=b;t.n();){if(s===0)return t.gq();--s}throw A.c(A.d_(b,b-s,this,"index"))},
j(a){return A.f0(this,"(",")")}}
A.aU.prototype={
gt(a){return A.m.prototype.gt.call(this,0)},
j(a){return"null"}}
A.m.prototype={$im:1,
H(a,b){return this===b},
gt(a){return A.bL(this)},
j(a){return"Instance of '"+A.bM(this)+"'"},
gp(a){return A.hd(this)},
toString(){return this.j(this)}}
A.cz.prototype={}
A.aw.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$ifb:1}
A.ck.prototype={}
A.bp.prototype={
U(){var t=this
return A.K(["areaMultiplier",t.a,"aspects",t.b,"angleMinDeg",t.c,"angleMaxDeg",t.d,"speedMin",t.e,"speedMax",t.f,"accelMin",t.r,"accelMax",t.w,"collideWithEachOther",t.x,"spinDegPerSec",t.y],u.N,u.z)}}
A.c3.prototype={
$1(a){return A.t(a)},
$S:8}
A.cu.prototype={
U(){return A.K(["size",this.a,"showFace",this.b],u.N,u.z)}}
A.c6.prototype={
U(){var t,s=this,r=A.dK(u.N,u.z)
r.u(0,"borderWidth",s.a)
r.u(0,"brightness",s.b)
r.u(0,"shadowBrightness",s.c)
t=s.d
if(t!=null&&t.length!==0)r.u(0,"color",t)
return r}}
A.c7.prototype={
U(){var t=this
return A.K(["startHintEnabled",t.a,"idleSpeedMultiplier",t.b,"idleEnemiesMove",t.c,"speedRampSeconds",t.d,"jumpEnabled",t.e,"jumpDurationSec",t.f,"jumpCooldownSec",t.r,"jumpScale",t.w,"helmetEnabled",t.x,"helmetInvulnSec",t.y,"startInvulnSec",t.z,"heartbeatHaptic",t.Q,"timerHaptic",t.as,"timerHapticStyle",t.at,"timerHapticStyle5",t.ax,"timerHapticStyle10",t.ay,"hudSpeedScaleMax",t.ch,"wallsKillPlayer",t.CW],u.N,u.z)}}
A.c1.prototype={
U(){return A.K(["sfxMobWall",!0,"sfxMobCollide",!0,"sfxHeroMob",!0,"sfxHeroWall",!0,"sfxNearMiss",!0,"sfxHelmet",!0,"sfxJump",!0,"sfxStart",!0,"music",!0,"sfxVolume",1,"musicVolume",0.08],u.N,u.z)}}
A.cs.prototype={}
A.b.prototype={
G(a,b){return new A.b(this.a+b.a,this.b+b.b)},
X(a,b){return new A.b(this.a-b.a,this.b-b.b)},
W(a,b){return new A.b(this.a*b,this.b*b)},
ao(a,b){return new A.b(this.a/b,this.b/b)},
gbd(){var t=this.a,s=this.b
return Math.sqrt(t*t+s*s)}}
A.cy.prototype={}
A.v.prototype={
gP(){var t=this
return new A.b((t.a+t.c)/2,(t.b+t.d)/2)},
V(a){var t=this
return t.a<a.c&&t.c>a.a&&t.b<a.d&&t.d>a.b}}
A.ca.prototype={
$1(a){var t,s,r,q=a.a,p=a.b
if(isFinite(q)&&isFinite(p)){s=a.c-q
r=a.d-p
r=!(isFinite(s)&&s>0&&isFinite(r)&&r>0)
s=r}else s=!0
if(s)return!1
s=this.a.b
t=A.dD(a,new A.v(0,0,0+s.a,0+s.b))
s=t
if(!(s.c-s.a<=0||s.d-s.b<=0)){s=t
r=t
p=(s.c-s.a)*(r.d-r.b)/((a.c-q)*(a.d-p))>=0.97
q=p}else q=!1
return q},
$S:9}
A.c9.prototype={
$2(a,b){return Math.min(a*this.a,b*this.b)*this.c>=8},
$S:10}
A.c8.prototype={
$1(a){A.df(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.cX.prototype={
$1(b3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1=null,b2="startPose"
A.a8(b3)
try{p=u.c
t=p.a(B.e.bb(b3,b1))
s=J.a0(t,"op")
if(J.T(s,"rewardFrame")){q=A.t(J.a0(t,"p"))
p=J.T(J.a0(t,"reduced"),!0)
r=new A.c5(B.b.m(q,0,1),p)
p=r.a
q=B.b.m(r.a/0.1125,0,1)
o=r.gJ()
n=r.gaG()
m=r
if(m.b)m=1
else{l=B.b.m(m.a/0.1125,0,1)-1
m=(0.82+0.18*(1+2.70158*Math.pow(l,3)+1.70158*Math.pow(l,2)))*(1-0.78*m.gaG())}l=r
k=B.b.m(l.a/0.1125,0,1)
l=B.b.m((l.gJ()-0.76)/0.24,0,1)
j=r
i=j.b
j=j.a
j=i?j:B.b.m((j-0.8)/0.2,0,1)
i=r
i=i.b?0:Math.sin(3.141592653589793*B.b.m((i.a-0.83)/0.17,0,1))
h=B.e.a0(A.K(["ok",!0,"p",p,"appearance",q,"flight",o,"fly",n,"scale",m,"opacity",k*(1-l),"roll",j,"hit",i],u.N,u.K),b1)
return h}if(J.T(s,"create")){o=t
g=new A.c2(A.n([],u.U))
b3=p.a(o.h(0,"config"))
f=A.eU(p.a(b3.h(0,"enemies")))
n=p.a(b3.h(0,"player"))
m=A.p(n.h(0,"size"))
if(m==null)m=b1
if(m==null){m=A.p(n.h(0,"playerSize"))
if(m==null)m=b1}if(m==null)m=36
l=A.N(n.h(0,"showFace"))
n=l==null?A.N(n.h(0,"playerShowFace")):l
l=p.a(b3.h(0,"field"))
k=l.h(0,"color")
e=k==null?l.h(0,"colorHex"):k
if(e==null)e=l.h(0,"surfaceColor")
d=typeof e=="string"&&B.d.aO(e).length!==0?B.d.aO(e):b1
k=A.p(l.h(0,"borderWidth"))
if(k==null)k=b1
if(k==null)k=3
j=A.p(l.h(0,"brightness"))
if(j==null)j=b1
if(j==null){j=A.p(l.h(0,"fieldBrightness"))
if(j==null)j=b1}if(j==null)j=1
l=A.p(l.h(0,"shadowBrightness"))
if(l==null)l=b1
if(l==null)l=1
i=A.dB(p.a(b3.h(0,"game")))
p=p.a(b3.h(0,"mobileEnemies"))
c=p.h(0,"startSpeedSteps")
b=p.h(0,"accelerationSteps")
if(typeof c!="number"||typeof b!="number"||!isFinite(c)||!isFinite(b)||c<0.01||c>250||b<0||b>50)A.J(B.E)
a=A.dN(p.h(0,"speedVariation"),0.05)
p=A.dN(p.h(0,"accelerationVariation"),0.08)
a0=m*1.2
a1=Math.max(0.000001,(a0===0?36:a0)*0.1)
a2=c*a1
a3=b*a1
a4=i.U()
a4.u(0,"speedRampSeconds",0)
i=A.dB(a4)
p=new A.ck(new A.bp(f.a,f.b,f.c,f.d,a2*(1-a),a2*(1+a),a3*(1-p),a3*(1+p),f.x,f.y),new A.cu(m,n===!0),new A.c6(k,j,l,d),i,B.u,new A.cs(c,b,a,p))
g.a=p
a=A.f9(A.a8(o.h(0,"requestId")))
k/=2
l=B.b.m(k+0.5,0.5,12)
j=A.n([],u.v)
n=new A.cz()
$.ew()
m=$.dR.$0()
n.a=m
n.b=null
m=A.n([],u.l)
a5=u.S
a6=A.d4(a5)
a5=A.d4(a5)
p=new A.cb(p,B.r,new A.bN(a),l+k,j,n,m,a6,a5)
a0=(380-a0)/2
p.e=new A.b(a0,a0)
B.a.E(m)
a6.E(0)
a5.E(0)
B.a.E(j)
B.a.M(j,p.b6())
g.b=p
g.c=J.T(o.h(0,"hadHelmet"),!0)
g.d=J.T(o.h(0,"hadJump"),!0)
if(o.h(0,b2)!=null)p.bo(o.h(0,b2))
g.e=Math.max(0,i.z)
p=this.a
p.a=g}else{o=this.a
n=o.a
if(n==null){q=A.bP("session_missing")
throw A.c(q)}switch(s){case"idle":p=A.t(J.a0(t,"ms"))
if(n.w||n.x||!isFinite(p)||p<=0||p>50)A.J(A.bP("idle"))
m=n.b
m===$&&A.j()
a7=m.bq(p/1000)
n.Q=a7.a
n.as=a7.b
break
case"start":if(n.w||n.x)A.J(A.bP("start"))
p=n.b
p===$&&A.j()
p.aT()
n.ay=p.gaU()
n.as=n.Q=0
n.w=!0
break
case"tick":n.aj([0,J.a0(t,"ms")])
break
case"move":p=A.t(J.a0(t,"dx"))
m=A.t(J.a0(t,"dy"))
if(!n.w)A.J(A.bP("move"))
if(n.r===0)n.aj([0,1])
if(!n.x)n.aj([1,p,m])
break
case"jump":n.bi()
break
case"snapshot":break
case"proof":q=u.N
h=B.e.a0(A.K(["ok",!0,"proof",A.K(["version",1,"events",n.ax,"startPose",n.ay],q,u.z)],q,u.K),b1)
return h
case"guard":q=p.a(t)
p=u.j
a8=p.a(q.h(0,"field"))
a9=p.a(q.h(0,"visible"))
n=n.b
n===$&&A.j()
p=J.a_(a8)
o=A.t(p.h(a8,0))
m=A.t(p.h(a8,1))
l=A.t(p.h(a8,2))
p=A.t(p.h(a8,3))
k=J.a_(a9)
j=A.t(k.h(a9,0))
i=A.t(k.h(a9,1))
a=A.t(k.h(a9,2))
k=A.t(k.h(a9,3))
h=B.e.a0(A.K(["ok",!0,"issue",A.eX(A.t(q.h(0,"dpr")),new A.v(o,m,o+l,m+p),B.r,new A.v(j,i,j+a,i+k),n)],u.N,u.X),b1)
return h
default:q=A.br("unknown_operation")
throw A.c(q)}p=o}q=A.dK(u.N,u.z)
J.eI(q,"ok",!0)
J.dr(q,p.a.gaS())
h=B.e.a0(q,b1)
return h}catch(b0){return'{"ok":false,"error":"invalid_kernel_operation"}'}},
$S:11}
A.bN.prototype={
b1(){var t=this.a
t^=t<<13
t^=t>>>17
return this.a=(t^t<<5)>>>0},
D(){var t=this.a
t^=t<<13
t^=t>>>17
t=(t^t<<5)>>>0
this.a=t
return t/4294967296},
bl(a){if(a<=0)throw A.c(A.eM(a,null,null))
return B.b.ak(this.b1()/4294967296*a)},
$if7:1}
A.c5.prototype={
gJ(){return this.b?0:B.b.m((this.a-0.4)/0.4,0,1)},
gaG(){var t=this
return t.gJ()<0.5?4*t.gJ()*t.gJ()*t.gJ():1-Math.pow(-2*t.gJ()+2,3)/2}}
A.c2.prototype={
ga1(){var t=this.e
t===$&&A.j()
return t>0||this.f>0},
ba(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
if(e.ga1())return
t=e.b
t===$&&A.j()
s=t.a.d.CW&&t.aM()
r=!s
if(r&&!t.bm())return
e.y=s
q=t.e
q===$&&A.j()
p=q.a
o=t.a.b.a*1.2
n=o/2
m=p+n
q=q.b
l=q+n
if(s){q=380-m
k=Math.min(Math.min(m,q),Math.min(l,380-l))
if(k===m){j=l
i=0}else if(k===q){j=l
i=380}else{j=k===l?0:380
i=m}}else{h=new A.v(p,q,p+o,q+o)
q=t.f
p=q.length
g=0
for(;;){if(!(g<q.length)){j=l
i=m
break}f=q[g]
if(h.V(f.gA())){q=f.gA()
i=(m+(q.a+q.c)/2)/2
q=f.gA()
j=(l+(q.b+q.d)/2)/2
break}q.length===p||(0,A.O)(q);++g}}e.z=A.K(["x",i,"y",j],u.N,u.i)
q=e.c
q===$&&A.j()
if(q){e.c=!1
q=e.a
q===$&&A.j()
e.f=Math.max(0,q.d.y)
if(r)t.bn()}else{e.x=!0
e.w=!1}},
bi(){var t,s=this,r=!0
if(s.w){t=s.d
t===$&&A.j()
if(t){r=s.b
r===$&&A.j()
r=!r.bw(s.r)}}if(r)return;++s.at
B.a.l(s.ax,A.n([2],u.a))},
aj(a){var t,s,r,q,p,o,n,m,l,k,j,i=this
if(!i.w||i.x||i.ax.length>=6e5)throw A.c(A.bP("event"))
if(0>=a.length)return A.f(a,0)
if(J.T(a[0],0)){if(1>=a.length)return A.f(a,1)
t=A.t(a[1])
if(!isFinite(t)||t<=0||t>50||i.r+t>36e5)throw A.c(A.br("tick"))
B.a.l(i.ax,A.n([0,t],u.a))
i.r+=t
s=t/1000
r=i.b
r===$&&A.j()
r.br(s)
q=r.bt(s,i.r/1000,!i.ga1())
i.Q=q.a
i.as=q.b
r=i.e
r===$&&A.j()
i.e=Math.max(0,r-s)
i.f=Math.max(0,i.f-s)}else{if(0>=a.length)return A.f(a,0)
if(J.T(a[0],1)){r=a.length
if(1>=r)return A.f(a,1)
p=A.t(a[1])
if(2>=r)return A.f(a,2)
o=A.t(a[2])
if(!isFinite(p)||!isFinite(o)||Math.abs(p)>2000||Math.abs(o)>2000)throw A.c(A.br("move"))
B.a.l(i.ax,A.n([1,p,o],u.a))
r=i.b
r===$&&A.j()
r.bj(new A.b(p,o),!i.ga1())}else throw A.c(A.br("event"))}r=i.b
r===$&&A.j()
n=r.a
if(!n.d.CW&&r.aM()){m=n.b.a*1.2
l=r.d
n=r.b
k=Math.max(l,n.a-l-m)
j=Math.max(l,n.b-l-m)
n=r.e
n===$&&A.j()
r.e=new A.b(B.b.m(n.a,l,k),B.b.m(r.e.b,l,j))}i.ba()},
gaS(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this,a2=a1.w,a3=a1.x,a4=B.b.ak(a1.r),a5=a1.b
a5===$&&A.j()
t=B.b.bp(Math.max(0,a5.y/Math.max(0.000001,a5.a.b.a*1.2*0.1)))
s=a5.z
r=a1.c
r===$&&A.j()
q=a1.ga1()
p=a5.aI(a1.r)
o=a1.at
n=a5.e
n===$&&A.j()
m=u.N
l=u.i
n=A.K(["x",n.a,"y",n.b,"size",a5.a.b.a*1.2,"visualScale",a5.gbx(),"jumpLift",a5.gaJ()],m,l)
k=u.O
j=A.n([],k)
for(i=a5.f,h=i.length,g=0;g<i.length;i.length===h||(0,A.O)(i),++g){f=i[g]
e=f.a
j.push(A.K(["x",e.a,"y",e.b,"w",f.y,"h",f.z,"angle",f.CW,"speed",f.ay+f.ch*(a1.r/1000)],m,l))}i=a1.Q
h=a1.as
e=a1.y
d=a1.z
c=a5.gbf()
k=A.n([],k)
for(a5=a5.Q,b=a5.length,g=0;g<a5.length;a5.length===b||(0,A.O)(a5),++g){a=a5[g]
a0=a.a
k.push(A.K(["x",a0.a,"y",a0.b,"age",a.b],m,l))}return A.K(["playing",a2,"dead",a3,"timeMs",a4,"runDistance",t,"riskCount",s,"helmet",r,"invulnerable",q,"jumpCooldownMs",p,"jumpCount",o,"player",n,"enemies",j,"wallBounces",i,"enemyBounces",h,"againstWall",e,"impactOrigin",d,"startled",c,"nearMissFx",k],m,u.z)}}
A.aF.prototype={}
A.a5.prototype={}
A.ac.prototype={
gP(){var t=this.a
return new A.b(t.a+this.y*0.5,t.b+this.z*0.5)},
aR(a){this.a=new A.b(a.a-this.y*0.5,a.b-this.z*0.5)},
gN(){var t=this.CW*3.141592653589793/180
return new A.b(Math.cos(t),Math.sin(t))},
gO(){var t=this.CW*3.141592653589793/180
return new A.b(-Math.sin(t),Math.cos(t))},
gai(){var t=this,s=t.y*0.5,r=t.z*0.5,q=new A.c4(t.gP(),t.gN(),t.gO()),p=-s,o=-r
return A.n([q.$2(p,o),q.$2(s,o),q.$2(s,r),q.$2(p,r)],u.M)},
gA(){var t,s,r,q,p=this.gai(),o=B.a.gF(p).a,n=B.a.gF(p).a,m=B.a.gF(p).b,l=B.a.gF(p).b
for(t=0;t<4;++t){s=p[t]
r=s.a
if(r<o)o=r
if(r>n)n=r
q=s.b
if(q<m)m=q
if(q>l)l=q}return new A.v(o,m,n,l)},
a2(a){var t=this,s=t.gP(),r=t.gN(),q=t.gO(),p=a.a,o=a.b,n=s.a*p+s.b*o,m=t.y*0.5*Math.abs(p*r.a+o*r.b)+t.z*0.5*Math.abs(p*q.a+o*q.b)
return new A.ba(n-m,n+m)},
a7(a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
for(t=[B.h,B.i,this.gN(),this.gO()],s=a1.a,r=a1.c,q=(s+r)/2,p=a1.b,o=a1.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,o=a2.a,r=a2.b,m=0,l=1,k=0;k<4;++k){j=t[k]
i=this.a2(j)
h=i.a
g=i.b
f=j.a
e=j.b
d=q*f+n*e
c=s*Math.abs(f)+p*Math.abs(e)
b=o*f+r*e
if(Math.abs(b)<1e-12){if(d+c<=h||d-c>=g)return null
continue}a=(h-d-c)/b
a0=(g-d+c)/b
m=Math.max(m,Math.min(a,a0))
l=Math.min(l,Math.max(a,a0))
if(m>=l)return null}return l<=0?null:m},
aL(a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[B.h,B.i,b.gN(),b.gO()],a0=a3.gP(),a1=(a3.c-a3.a)*0.5,a2=(a3.d-a3.b)*0.5
for(t=a0.a,s=a0.b,r=b.y*0.5,q=b.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.b(l,k)
g=b.a2(h)
f=t*l+s*k
e=a1*Math.abs(l)+a2*Math.abs(k)
d=Math.min(g.b,f+e)-Math.max(g.a,f-e)
if(d<=0)return null
if(d<p){c=b.a
o=(c.a+r-t)*l+(c.b+q-s)*k>=0?h:new A.b(-l,-k)
p=d}}if(o==null)return null
return o.W(0,p+0.5)},
bk(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[b.gN(),b.gO(),a0.gN(),a0.gO()]
for(t=b.y*0.5,s=a0.y*0.5,r=b.z*0.5,q=a0.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.b(l,k)
g=b.a2(h)
f=a0.a2(h)
e=Math.min(g.b,f.b)-Math.max(g.a,f.a)
if(e<=0)return null
if(e<p){d=b.a
c=a0.a
o=(d.a+t-(c.a+s))*l+(d.b+r-(c.b+q))*k>=0?h:new A.b(-l,-k)
p=e}}if(o==null)return null
return o.W(0,p+0.5)},
K(a){var t,s,r,q,p,o=a.a,n=a.b,m=o*o+n*n
if(m<1e-12)return
t=1/Math.sqrt(m)
s=o*t
r=n*t
o=this.b
n=o.a
o=o.b
q=n*s+o*r
if(q>=0)return
p=2*q
this.b=new A.b(n-p*s,o-p*r)}}
A.c4.prototype={
$2(a,b){var t=this.a,s=this.b,r=this.c
return new A.b(t.a+s.a*a+r.a*b,t.b+s.b*a+r.b*b)},
$S:12}
A.cb.prototype={
aI(a){var t=this.x
return Math.max(0,t-a)},
gbf(){var t,s,r=this.e
r===$&&A.j()
t=r.a
r=r.b
s=this.a.b.a*1.2
return B.a.af(this.f,new A.ch(new A.v(t,r,t+s,r+s)))},
gaJ(){var t=this.r
if(!(t>0))return 0
return Math.sin(3.141592653589793*B.b.m(1-t/Math.max(0.05,this.a.d.f),0,1))},
gbx(){if(!(this.r>0))return 1
return 1+(B.b.m(this.a.d.w,1.05,1.8)-1)*this.gaJ()},
bw(a){var t,s,r=this
if(!isFinite(a)||!r.a.d.e||r.r>0||r.aI(a)>0)return!1
t=r.a.d
r.r=Math.max(0.12,t.f)
s=t.r
t=isFinite(s)?s:2
r.x=a+Math.max(0,t)*1000
r.at.E(0)
r.as.E(0)
r.ac()
return!0},
br(a){var t=this,s=t.r
if(s<=0)return
s=Math.max(0,s-a)
t.r=s
if(s>0)t.ac()
else t.at.E(0)},
b6(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=a9.a,b1=b0.a,b2=A.dL(b1.b,!0,u.i),b3=A.A(b2),b4=b3.i("ah<1>"),b5=A.d5(new A.ah(b2,b3.i("w(1)").a(new A.cg()),b4),b4.i("d.E"))
if(b5.length===0)B.a.M(b5,B.o)
t=b5.length
s=Math.max(t,4)
b2=u.S
b3=J.d1(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.a6(r,4)
b4=a9.c
B.a.ap(b3,b4)
q=A.dU(b3,0,A.ej(t,"count",b2),A.A(b3).c).aN(0)
b3=J.d1(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.a6(r,4)
B.a.ap(b3,b4)
p=A.dU(b3,0,A.ej(t,"count",b2),A.A(b3).c).aN(0)
o=A.n([],u.v)
for(b2=b1.e,b3=b1.f,n=b1.r,m=b1.w,l=b1.y,b0=b0.b.a*1.2,b0*=b0,k=b1.a,j=b1.c,b1=b1.d,r=0;r<t;++r){if(!(r<b5.length))return A.f(b5,r)
i=b5[r]
if(!(r<q.length))return A.f(q,r)
h=q[r]
if(!(r<p.length))return A.f(p,r)
g=p[r]
f=Math.max(1,b0)*B.b.m(k,0.2,20)
e=B.b.m(i,0.05,50)
d=Math.sqrt(f/e)
c=Math.sqrt(f*e)
b=a9.b3(g,d,c)
a=Math.min(j,b1)
a0=Math.max(j,b1)
a1=a+b4.D()*(a0-a)+90*h
a2=(a1>=360?a1-360:a1)*3.141592653589793/180
a3=Math.min(b2,b3)
a4=Math.max(b2,b3)
a5=a3+b4.D()*(a4-a3)
a3=Math.min(n,m)
a4=Math.max(n,m)
i=b4.D()
h=Math.cos(a2)
g=Math.sin(a2)
a6=Math.abs(l)>0.01
a7=a6?b4.D()*360:0
a8=new A.ac(b,new A.b(h*a5,g*a5),c,d,a5,a3+i*(a4-a3),a7,l)
if(a6)a9.aB(a8)
a8.c=a8.a
a8.d=a8.b
a8.w=b4.D()*3.141592653589793*2
a8.x=b4.D()*3.141592653589793*2
a8.f=1.15+b4.D()*0.85
a8.r=0.85+b4.D()*0.85
B.a.l(o,a8)}return o},
bq(a){var t,s,r,q,p,o,n,m,l,k,j,i=this,h=B.b.m(a,0,0.05),g=i.a,f=g.d
if(!f.c)return i.b8(h)
t=B.b.m(f.b,0.05,1)
for(f=i.f,s=f.length,r=0,q=0;q<f.length;f.length===s||(0,A.O)(f),++q){p=f[q]
o=B.b.m(p.ay*t,0,2000)
n=p.b
m=n.a
n=n.b
l=Math.sqrt(m*m+n*n)
if(l<0.000001)k=B.p
else{n=p.b
k=new A.b(n.a/l,n.b/l)}n=k.a*o
m=k.b*o
p.b=new A.b(n,m)
j=p.a
p.a=new A.b(j.a+n*h,j.b+m*h)
n=p.cx
if(Math.abs(n)>0.01)p.CW=p.CW+n*h
if(i.Z(p))++r}return new A.aF(r,g.a.x?i.aD():0)},
aT(){var t,s,r,q,p,o,n,m
for(t=this.f,s=t.length,r=0;r<t.length;t.length===s||(0,A.O)(t),++r){q=t[r]
p=q.b
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.b
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
m=new A.b(o/n,p/n)}else{p=q.d
p===$&&A.j()
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.d
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
n=new A.b(o/n,p/n)
m=n}else m=B.h}p=q.ay
q.b=new A.b(m.a*p,m.b*p)}},
gaU(){var t,s,r,q,p,o,n,m=A.n([],u.q)
for(t=this.f,s=t.length,r=u.t,q=0;q<t.length;t.length===s||(0,A.O)(t),++q){p=t[q]
o=p.a
n=p.b
m.push(A.n([o.a,o.b,n.a,n.b,p.CW],r))}return m},
bo(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=u.j
if(!f.b(a)||J.a1(a)!==this.f.length)throw A.c(B.D)
for(t=this.f,s=J.a_(a),r=this.b,q=r.a+0.0001,r=r.b+0.0001,p=0;p<t.length;++p){o=s.h(a,p)
if(f.b(o)){n=J.bg(o)
n=n.gk(o)!==5||n.af(o,new A.ci())}else n=!0
if(n)throw A.c(B.C)
if(!(p<t.length))return A.f(t,p)
m=t[p]
n=J.a_(o)
l=A.t(n.h(o,0))
k=A.t(n.h(o,1))
j=A.t(n.h(o,2))
i=A.t(n.h(o,3))
h=A.t(n.h(o,4))
n=m.ay
if(Math.abs(Math.sqrt(j*j+i*i)-n)>Math.max(0.0001,n*0.000001)||Math.abs(h)>1e9)throw A.c(B.G)
m.a=new A.b(l,k)
m.b=new A.b(j,i)
m.CW=h
g=m.gA()
if(g.a<-0.0001||g.b<-0.0001||g.c>q||g.d>r)throw A.c(B.F)}},
b8(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.f,s=t.length,r=0;r<t.length;t.length===s||(0,A.O)(t),++r){q=t[r]
q.e+=a
p=Math.min(q.y,q.z)*0.5
o=q.d
o===$&&A.j()
n=o.a
o=o.b
m=Math.sqrt(n*n+o*o)
if(m<0.000001)l=B.h
else{o=q.d
l=new A.b(o.a/m,o.b/m)}o=l.b
n=l.a
k=Math.cos(q.e*q.f+q.w)*p
j=Math.sin(q.e*q.r+q.x)*p*0.35
i=n*k+-o*j
n=o*k+n*j
h=new A.b(i,n)
o=i*i+n*n
if(Math.sqrt(o)>p&&Math.sqrt(o)>0.000001){o=p/Math.sqrt(o)
h=new A.b(i*o,n*o)}o=q.c
o===$&&A.j()
q.a=new A.b(o.a+h.a,o.b+h.b)
o=q.cx
if(Math.abs(o)>0.01)q.CW=q.CW+o*a*0.35
this.aB(q)}return B.t},
aB(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.d,s=this.b,r=s.a-t,q=s.b-t,p=0;p<3;++p){o=a.gai()
s=A.A(o)
n=s.i("e(1)")
s=s.i("L<1,e>")
m=new A.L(o,n.a(new A.cc()),s).a3(0,B.k)
l=new A.L(o,n.a(new A.cd()),s).a3(0,B.l)
k=new A.L(o,n.a(new A.ce()),s).a3(0,B.k)
j=new A.L(o,n.a(new A.cf()),s).a3(0,B.l)
if(m<t)i=t-m
else i=l>r?r-l:0
if(k<t)h=t-k
else h=j>q?q-j:0
if(i===0&&h===0)break
s=a.a
a.a=new A.b(s.a+i,s.b+h)}},
bt(a6,a7,a8){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=this,a3=B.b.m(a6,0,0.05),a4=B.c.m(1,0,2),a5=B.b.m(a7,0,3600)
for(t=a2.f,s=t.length,r=a2.a,q=r.b.a*1.2,p=0,o=0;o<t.length;t.length===s||(0,A.O)(t),++o){n=t[o]
m=B.b.m((n.ay+n.ch*a5)*a4,0,4000)
l=n.b
k=l.a
l=l.b
j=Math.sqrt(k*k+l*l)
if(j<0.000001)i=B.p
else{l=n.b
i=new A.b(l.a/j,l.b/j)}n.b=new A.b(i.a*m,i.b*m)
l=n.cx
k=Math.abs(l)
h=Math.max(1,B.b.b9(k*a3/5))
for(k=k>0.01,g=a3/h,l=l*a3/h,f=0;f<h;++f){e=n.b
d=e.a*g
e=e.b*g
if(k)n.CW+=l
if(a8&&!(a2.r>0)){c=a2.e
c===$&&A.j()
b=c.a
c=c.b
a=n.a7(new A.v(b,c,b+q,c+q),new A.b(-d,-e))}else a=null
c=n.a
b=a==null
if(b)a0=1
else a0=a===0?0:Math.min(1,a+1e-7)
n.a=new A.b(c.a+d*a0,c.b+e*a0)
if(a2.Z(n))++p
if(!b)break}}a1=r.a.x?a2.aD():0
a2.bs(a3)
return new A.aF(p,a1)},
bj(a,b){var t,s,r,q,p,o,n,m,l,k,j,i=this,h=a.a,g=!0
if(isFinite(h)){t=a.b
if(isFinite(t))h=h===0&&t===0
else h=g}else h=g
if(h)return
h=i.e
h===$&&A.j()
s=h.G(0,a)
g=i.a
if(!g.d.CW){t=i.d
r=i.b
q=g.b.a*1.2
s=new A.b(B.b.m(s.a,t,Math.max(t,r.a-t-q)),B.b.m(s.b,t,Math.max(t,r.b-t-q)))}p=s.X(0,h)
t=i.e
r=t.a
t=t.b
g=g.b.a*1.2
o=new A.v(r,t,r+g,t+g)
n=1
if(b&&!(i.r>0))for(g=i.f,t=g.length,m=0;m<g.length;g.length===t||(0,A.O)(g),++m){l=g[m].a7(o,p)
if(l!=null){r=l===0?0:l+1e-7
n=Math.min(n,r)}}g=h.G(0,p.W(0,Math.min(1,n)))
i.e=g
k=g.X(0,h).gbd()
if(k===0)return
i.y+=k
if(i.r>0){for(h=i.f,j=0;j<h.length;++j)if(h[j].a7(o,p)!=null)i.au(j)}else i.av()},
bs(a){var t=this,s=t.Q,r=A.A(s).i("w(1)").a(new A.cj(a))
s.$flags&1&&A.aE(s,16)
B.a.b4(s,r,!0)
if(t.r>0)t.ac()
else t.av()},
ac(){var t,s,r,q,p,o=this
if(!(o.r>0))return
t=o.e
t===$&&A.j()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.v(s,t,s+r,t+r)
for(t=o.f,s=o.at,p=0;p<t.length;++p){if(s.ah(0,p))continue
if(!(p<t.length))return A.f(t,p)
if(!q.V(t[p].gA()))continue
o.au(p)}},
au(a){var t,s,r,q=this
if(!q.at.l(0,a))return;++q.z
t=q.e
t===$&&A.j()
s=q.a.b.a*1.2/2
r=t.G(0,new A.b(s,s))
s=q.f
if(!(a<s.length))return A.f(s,a)
B.a.l(q.Q,new A.a5(r.G(0,s[a].gA().gP()).ao(0,2)))},
av(){var t,s,r,q,p,o,n,m,l,k,j,i=this
if(i.r>0)return
t=i.e
t===$&&A.j()
s=t.a
t=t.b
r=i.a.b.a*1.2
q=s+r
r=t+r
p=new A.v(s,t,q,r)
o=A.d4(u.S)
for(n=i.f,m=i.as,q=(s+q)/2,r=(t+r)/2,t=i.Q,l=0;l<n.length;++l){k=A.dC(p,n[l].gA())
if(k<=0)continue
if(k<=14){m.l(0,l)
o.l(0,l)}else if(k>=22&&m.ah(0,l)){++i.z
if(!(l<n.length))return A.f(n,l)
s=n[l].gA()
if(!(l<n.length))return A.f(n,l)
j=n[l].gA()
B.a.l(t,new A.a5(new A.b((q+(s.a+s.c)/2)/2,(r+(j.b+j.d)/2)/2)))}else if(m.ah(0,l))o.l(0,l)}m.E(0)
m.M(0,o)},
aM(){var t,s,r,q,p=this,o=p.e
o===$&&A.j()
t=o.a
s=p.d
r=!0
if(!(t<=s)){o=o.b
if(!(o<=s)){r=p.a.b.a*1.2
q=p.b
o=t+r>=q.a-s||o+r>=q.b-s}else o=r}else o=r
return o},
bm(){var t,s,r,q,p,o=this
if(o.r>0)return!1
t=o.e
t===$&&A.j()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.v(s,t,s+r,t+r)
for(t=o.f,s=t.length,p=0;p<t.length;t.length===s||(0,A.O)(t),++p)if(t[p].aL(q)!=null)return!0
return!1},
bn(){var t,s,r,q,p,o,n,m=this.e
m===$&&A.j()
t=m.a
m=m.b
s=this.a.b.a*1.2
r=new A.v(t,m,t+s,m+s)
for(m=this.f,t=m.length,q=0,p=0;p<m.length;m.length===t||(0,A.O)(m),++p){o=m[p]
n=o.aL(r)
if(n==null)continue
s=o.a
o.a=new A.b(s.a+n.a,s.b+n.b)
o.K(n);++q}return q},
b3(a0,a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this,d=Math.max(8,e.d+2),c=e.b,b=c.a,a=b/2
c=c.b
t=c/2
s=A.cD()
r=A.cD()
q=A.cD()
p=A.cD()
switch(B.c.a6(a0,4)){case 0:s.b=d
r.b=a-a2-d
q.b=d
p.b=t-a1-d
break
case 1:s.b=a+d
r.b=b-a2-d
q.b=d
p.b=t-a1-d
break
case 2:s.b=d
r.b=a-a2-d
q.b=t+d
p.b=c-a1-d
break
default:s.b=a+d
r.b=b-a2-d
q.b=t+d
p.b=c-a1-d}o=r.L()
n=s.L()
if(typeof o!=="number")return o.a5()
if(typeof n!=="number")return A.cS(n)
if(o<n){s.b=d
r.b=Math.max(d,b-a2-d)}o=p.L()
n=q.L()
if(typeof o!=="number")return o.a5()
if(typeof n!=="number")return A.cS(n)
if(o<n){q.b=d
p.b=Math.max(d,c-a1-d)}o=e.e
o===$&&A.j()
n=o.a
o=o.b
m=e.a.b.a*1.2
l=m*0.6
k=new A.v(n-l,o-l,n+m+l,o+m+l)
for(o=e.c,j=0;j<12;++j){n=s.b
if(n===s)A.J(A.aO(""))
m=o.D()
l=r.b
if(l===r)A.J(A.aO(""))
i=s.b
if(i===s)A.J(A.aO(""))
if(typeof l!=="number")return l.X()
if(typeof i!=="number")return A.cS(i)
l=Math.max(1,l-i)
if(typeof n!=="number")return n.G()
h=n+m*l
n=q.b
if(n===q)A.J(A.aO(""))
m=o.D()
l=p.b
if(l===p)A.J(A.aO(""))
i=q.b
if(i===q)A.J(A.aO(""))
if(typeof l!=="number")return l.X()
if(typeof i!=="number")return A.cS(i)
l=Math.max(1,l-i)
if(typeof n!=="number")return n.G()
g=n+m*l
f=new A.b(h,g)
if(!new A.v(h,g,h+a2,g+a1).V(k))return f}return new A.b(J.ds(s.L(),d,b-a2-d),J.ds(q.L(),d,c-a1-d))},
Z(a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=a2.gP()
for(t=this.d,s=this.b,r=s.a-t,q=s.b-t,s=a2.y*0.5,p=a2.z*0.5,o=!1,n=0;n<3;++n){m=a1.a
l=a1.b
a2.a=new A.b(m-s,l-p)
k=a2.gai()
j=B.a.gF(k).a
i=B.a.gF(k).a
h=B.a.gF(k).b
g=B.a.gF(k).b
for(f=0;f<4;++f){e=k[f]
d=e.a
if(d<j)j=d
if(d>i)i=d
c=e.b
if(c<h)h=c
if(c>g)g=c}b=!0
if(j<t){a=t-j
a2.K(B.h)
o=b}else if(i>r){a=r-i
a2.K(B.N)
o=b}else a=0
if(h<t){a0=t-h
a2.K(B.i)
o=b}else if(g>q){a0=q-g
a2.K(B.M)
o=b}else a0=0
if(a===0&&a0===0)break
a1=new A.b(m+a,l+a0)}a2.aR(a1)
return o},
aD(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f
for(t=this.f,s=0,r=0;r<t.length;r=q)for(q=r+1,p=q;o=t.length,p<o;++p){if(!(r<o))return A.f(t,r)
n=t[r]
m=t[p]
if(!n.gA().V(m.gA()))continue
l=n.bk(m)
if(l==null)continue;++s
o=l.a
k=o*0.5
j=l.b
i=j*0.5
h=n.a
g=n.y*0.5
f=n.z*0.5
n.a=new A.b(h.a+g+k-g,h.b+f+i-f)
f=m.a
h=m.y*0.5
g=m.z*0.5
m.a=new A.b(f.a+h-k-h,f.b+g-i-g)
n.K(l)
m.K(new A.b(-o,-j))
this.Z(n)
this.Z(m)}return s}}
A.ch.prototype={
$1(a){return A.dC(this.a,u.W.a(a).gA())<=14},
$S:13}
A.cg.prototype={
$1(a){A.df(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.ci.prototype={
$1(a){return typeof a!="number"||!isFinite(a)},
$S:14}
A.cc.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.cd.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.ce.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cf.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cj.prototype={
$1(a){return!((u._.a(a).b+=this.a)<0.42)},
$S:15};(function aliases(){var t=J.a4.prototype
t.aV=t.j})();(function installTearOffs(){var t=hunkHelpers._static_0,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(A,"h_","f5",1)
s(A,"h8","fG",2)
r(A,"hp",2,null,["$1$2","$2"],["ep",function(a,b){return A.ep(a,b,u.H)}],5,0)
r(A,"ho",2,null,["$1$2","$2"],["eo",function(a,b){return A.eo(a,b,u.H)}],5,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.m,null)
r(A.m,[A.d2,J.bv,A.aY,J.ab,A.o,A.i,A.cx,A.d,A.X,A.b4,A.C,A.b2,A.ak,A.B,A.cA,A.ct,A.F,A.cq,A.aP,A.cC,A.Q,A.bV,A.cJ,A.av,A.bY,A.ai,A.bm,A.bo,A.cG,A.aZ,A.V,A.aU,A.cz,A.aw,A.ck,A.bp,A.cu,A.c6,A.c7,A.c1,A.cs,A.b,A.cy,A.v,A.bN,A.c5,A.c2,A.aF,A.a5,A.ac,A.cb])
r(J.bv,[J.bx,J.aJ,J.aL,J.aK,J.aM,J.aq,J.ar])
r(J.aL,[J.a4,J.l,A.at,A.aS])
r(J.a4,[J.bK,J.ax,J.a3])
s(J.bw,A.aY)
s(J.cl,J.l)
r(J.aq,[J.aI,J.by])
r(A.o,[A.af,A.b1,A.bz,A.bT,A.bO,A.bU,A.aN,A.bi,A.U,A.b3,A.bS,A.b_,A.bn])
s(A.ay,A.i)
s(A.aG,A.ay)
r(A.d,[A.aH,A.ah])
r(A.aH,[A.D,A.ag])
r(A.D,[A.b0,A.L,A.bX])
s(A.az,A.ak)
s(A.ba,A.az)
r(A.B,[A.bu,A.bk,A.bl,A.bR,A.cT,A.cV,A.c3,A.ca,A.c8,A.cX,A.ch,A.cg,A.ci,A.cc,A.cd,A.ce,A.cf,A.cj])
s(A.ad,A.bu)
s(A.cv,A.bk)
s(A.aV,A.b1)
r(A.bR,[A.bQ,A.ap])
r(A.F,[A.ae,A.bW])
r(A.bl,[A.cm,A.cU,A.cr,A.cH,A.c9,A.c4])
r(A.aS,[A.bB,A.au])
r(A.au,[A.b6,A.b8])
s(A.b7,A.b6)
s(A.aQ,A.b7)
s(A.b9,A.b8)
s(A.aR,A.b9)
r(A.aQ,[A.bC,A.bD])
r(A.aR,[A.bE,A.bF,A.bG,A.bH,A.bI,A.aT,A.bJ])
s(A.aA,A.bU)
s(A.bb,A.av)
s(A.b5,A.bb)
s(A.bA,A.aN)
s(A.cn,A.bm)
r(A.bo,[A.cp,A.co])
s(A.cF,A.cG)
r(A.U,[A.aW,A.bt])
t(A.ay,A.b2)
t(A.b6,A.i)
t(A.b7,A.C)
t(A.b8,A.i)
t(A.b9,A.C)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",e:"double",R:"num",r:"String",w:"bool",aU:"Null",h:"List",m:"Object",as:"Map",u:"JSObject"},mangledNames:{},types:["e(b)","a()","@(@)","~(m?,m?)","w(e)","0^(0^,0^)<R>","@(@,r)","@(r)","e(@)","w(v)","w(e,e)","r(r)","b(e,e)","w(ac)","w(@)","w(a5)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.ba&&a.b(c.a)&&b.b(c.b)}}
A.fw(v.typeUniverse,JSON.parse('{"a3":"a4","bK":"a4","ax":"a4","hx":"at","bx":{"w":[],"k":[]},"aJ":{"k":[]},"aL":{"u":[]},"a4":{"u":[]},"l":{"h":["1"],"u":[],"d":["1"]},"bw":{"aY":[]},"cl":{"l":["1"],"h":["1"],"u":[],"d":["1"]},"ab":{"a2":["1"]},"aq":{"e":[],"R":[]},"aI":{"e":[],"a":[],"R":[],"k":[]},"by":{"e":[],"R":[],"k":[]},"ar":{"r":[],"k":[]},"af":{"o":[]},"aG":{"i":["a"],"b2":["a"],"h":["a"],"d":["a"],"i.E":"a"},"aH":{"d":["1"]},"D":{"d":["1"]},"b0":{"D":["1"],"d":["1"],"d.E":"1","D.E":"1"},"X":{"a2":["1"]},"L":{"D":["2"],"d":["2"],"d.E":"2","D.E":"2"},"ah":{"d":["1"],"d.E":"1"},"b4":{"a2":["1"]},"ay":{"i":["1"],"b2":["1"],"h":["1"],"d":["1"]},"ba":{"az":[],"ak":[]},"bu":{"B":[],"W":[]},"ad":{"B":[],"W":[]},"aV":{"o":[]},"bz":{"o":[]},"bT":{"o":[]},"B":{"W":[]},"bk":{"B":[],"W":[]},"bl":{"B":[],"W":[]},"bR":{"B":[],"W":[]},"bQ":{"B":[],"W":[]},"ap":{"B":[],"W":[]},"bO":{"o":[]},"ae":{"F":["1","2"],"dJ":["1","2"],"as":["1","2"],"F.K":"1","F.V":"2"},"ag":{"d":["1"],"d.E":"1"},"aP":{"a2":["1"]},"az":{"ak":[]},"at":{"u":[],"k":[]},"aS":{"u":[]},"bB":{"u":[],"k":[]},"au":{"H":["1"],"u":[]},"aQ":{"i":["e"],"h":["e"],"H":["e"],"u":[],"d":["e"],"C":["e"]},"aR":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"]},"bC":{"i":["e"],"h":["e"],"H":["e"],"u":[],"d":["e"],"C":["e"],"k":[],"i.E":"e"},"bD":{"i":["e"],"h":["e"],"H":["e"],"u":[],"d":["e"],"C":["e"],"k":[],"i.E":"e"},"bE":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"],"k":[],"i.E":"a"},"bF":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"],"k":[],"i.E":"a"},"bG":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"],"k":[],"i.E":"a"},"bH":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"],"k":[],"i.E":"a"},"bI":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"],"k":[],"i.E":"a"},"aT":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"],"k":[],"i.E":"a"},"bJ":{"i":["a"],"h":["a"],"H":["a"],"u":[],"d":["a"],"C":["a"],"k":[],"i.E":"a"},"bU":{"o":[]},"aA":{"o":[]},"b5":{"av":["1"],"d9":["1"],"d":["1"]},"ai":{"a2":["1"]},"i":{"h":["1"],"d":["1"]},"F":{"as":["1","2"]},"av":{"d9":["1"],"d":["1"]},"bb":{"av":["1"],"d9":["1"],"d":["1"]},"bW":{"F":["r","@"],"as":["r","@"],"F.K":"r","F.V":"@"},"bX":{"D":["r"],"d":["r"],"d.E":"r","D.E":"r"},"aN":{"o":[]},"bA":{"o":[]},"e":{"R":[]},"a":{"R":[]},"h":{"d":["1"]},"bi":{"o":[]},"b1":{"o":[]},"U":{"o":[]},"aW":{"o":[]},"bt":{"o":[]},"b3":{"o":[]},"bS":{"o":[]},"b_":{"o":[]},"bn":{"o":[]},"aZ":{"o":[]},"aw":{"fb":[]},"bN":{"f7":[]},"f_":{"h":["a"],"d":["a"]},"ff":{"h":["a"],"d":["a"]},"fe":{"h":["a"],"d":["a"]},"eY":{"h":["a"],"d":["a"]},"fc":{"h":["a"],"d":["a"]},"eZ":{"h":["a"],"d":["a"]},"fd":{"h":["a"],"d":["a"]},"eV":{"h":["e"],"d":["e"]},"eW":{"h":["e"],"d":["e"]}}'))
A.fv(v.typeUniverse,JSON.parse('{"aH":1,"ay":1,"au":1,"bb":1,"bm":2,"bo":2}'))
var u=(function rtii(){var t=A.cR
return{V:t("aG"),W:t("ac"),C:t("o"),Z:t("W"),u:t("ad<e>"),Y:t("d<@>"),v:t("l<ac>"),q:t("l<h<e>>"),U:t("l<h<R>>"),O:t("l<as<r,e>>"),l:t("l<a5>"),M:t("l<b>"),s:t("l<r>"),t:t("l<e>"),b:t("l<@>"),a:t("l<R>"),T:t("aJ"),m:t("u"),g:t("a3"),p:t("H<@>"),j:t("h<@>"),c:t("as<r,@>"),_:t("a5"),P:t("aU"),K:t("m"),n:t("b"),J:t("hy"),F:t("+()"),N:t("r"),R:t("k"),o:t("ax"),y:t("w"),i:t("e"),z:t("@"),S:t("a"),Q:t("dA<aU>?"),A:t("u?"),d:t("h<@>?"),X:t("m?"),w:t("r?"),L:t("bY?"),e:t("w?"),I:t("e?"),x:t("a?"),B:t("R?"),H:t("R"),D:t("~(r,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.H=J.bv.prototype
B.a=J.l.prototype
B.c=J.aI.prototype
B.b=J.aq.prototype
B.d=J.ar.prototype
B.I=J.a3.prototype
B.J=J.aL.prototype
B.q=J.bK.prototype
B.j=J.ax.prototype
B.t=new A.aF(0,0)
B.l=new A.ad(A.ho(),u.u)
B.k=new A.ad(A.hp(),u.u)
B.u=new A.c1()
B.m=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.v=function() {
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
B.A=function(getTagFallback) {
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
B.w=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.z=function(hooks) {
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
B.y=function(hooks) {
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
B.x=function(hooks) {
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
B.n=function(hooks) { return hooks; }

B.e=new A.cn()
B.f=new A.cx()
B.B=new A.V("Invalid mobile enemy variation")
B.C=new A.V("start pose values")
B.D=new A.V("start pose count")
B.E=new A.V("Invalid mobile enemy pace")
B.F=new A.V("start pose bounds")
B.G=new A.V("start pose speed")
B.K=new A.co(null)
B.L=new A.cp(null)
B.o=t([1,0.25,0.5,3],u.t)
B.i=new A.b(0,1)
B.M=new A.b(0,-1)
B.h=new A.b(1,0)
B.p=new A.b(1,1)
B.N=new A.b(-1,0)
B.r=new A.cy(380,380)
B.O=A.S("ht")
B.P=A.S("hu")
B.Q=A.S("eV")
B.R=A.S("eW")
B.S=A.S("eY")
B.T=A.S("eZ")
B.U=A.S("f_")
B.V=A.S("m")
B.W=A.S("fc")
B.X=A.S("fd")
B.Y=A.S("fe")
B.Z=A.S("ff")})();(function staticFields(){$.cE=null
$.I=A.n([],A.cR("l<m>"))
$.dP=null
$.cw=0
$.dR=A.h_()
$.dx=null
$.dw=null
$.em=null
$.eh=null
$.es=null
$.cQ=null
$.cW=null
$.dm=null
$.cI=A.n([],A.cR("l<h<m>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hw","ev",()=>A.el("_$dart_dartClosure"))
t($,"hv","dq",()=>A.el("_$dart_dartClosure_dartJSInterop"))
t($,"hL","eH",()=>A.n([new J.bw()],A.cR("l<aY>")))
t($,"hA","ex",()=>A.Y(A.cB({
toString:function(){return"$receiver$"}})))
t($,"hB","ey",()=>A.Y(A.cB({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hC","ez",()=>A.Y(A.cB(null)))
t($,"hD","eA",()=>A.Y(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hG","eD",()=>A.Y(A.cB(void 0)))
t($,"hH","eE",()=>A.Y(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hF","eC",()=>A.Y(A.dV(null)))
t($,"hE","eB",()=>A.Y(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"hJ","eG",()=>A.Y(A.dV(void 0)))
t($,"hI","eF",()=>A.Y(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"hK","cZ",()=>A.eq(B.V))
t($,"hz","ew",()=>{A.f6()
return $.cw})})();(function nativeSupport(){!function(){var t=function(a){var n={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.at,SharedArrayBuffer:A.at,ArrayBufferView:A.aS,DataView:A.bB,Float32Array:A.bC,Float64Array:A.bD,Int16Array:A.bE,Int32Array:A.bF,Int8Array:A.bG,Uint16Array:A.bH,Uint32Array:A.bI,Uint8ClampedArray:A.aT,CanvasPixelArray:A.aT,Uint8Array:A.bJ})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.au.$nativeSuperclassTag="ArrayBufferView"
A.b6.$nativeSuperclassTag="ArrayBufferView"
A.b7.$nativeSuperclassTag="ArrayBufferView"
A.aQ.$nativeSuperclassTag="ArrayBufferView"
A.b8.$nativeSuperclassTag="ArrayBufferView"
A.b9.$nativeSuperclassTag="ArrayBufferView"
A.aR.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$0=function(){return this()}
Function.prototype.$1$1=function(a){return this(a)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.hm
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
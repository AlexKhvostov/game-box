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
if(a[b]!==t){A.hM(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.m(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.dD(b)
return new t(c,this)}:function(){if(t===null)t=A.dD(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.dD(a).prototype
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
dI(a,b,c,d){return{i:a,p:b,e:c,x:d}},
dE(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.dG==null){A.hB()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.c(A.ee("Return interceptor for "+A.t(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.cU
if(p==null)p=$.cU=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.hG(a)
if(q!=null)return q
if(typeof a=="function")return B.I
t=Object.getPrototypeOf(a)
if(t==null)return B.q
if(t===Object.prototype)return B.q
if(typeof r=="function"){p=$.cU
if(p==null)p=$.cU=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.k,enumerable:false,writable:true,configurable:true})
return B.k}return B.k},
dY(a,b){if(a<0||a>4294967295)throw A.c(A.b8(a,0,4294967295,"length",null))
return J.fl(new Array(a),b)},
dZ(a,b){if(a<0)throw A.c(A.c9("Length must be a non-negative integer: "+a))
return A.m(new Array(a),b.i("n<0>"))},
dk(a,b){if(a<0)throw A.c(A.c9("Length must be a non-negative integer: "+a))
return A.m(new Array(a),b.i("n<0>"))},
fl(a,b){var t=A.m(a,b.i("n<0>"))
t.$flags=1
return t},
e_(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
fm(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.e_(s))break;++b}return b},
fn(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.h(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.e_(r))break}return b},
au(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aU.prototype
return J.bH.prototype}if(typeof a=="string")return J.aA.prototype
if(a==null)return J.aV.prototype
if(typeof a=="boolean")return J.bG.prototype
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ab.prototype
if(typeof a=="symbol")return J.aY.prototype
if(typeof a=="bigint")return J.aW.prototype
return a}if(a instanceof A.p)return a
return J.dE(a)},
aM(a){if(typeof a=="string")return J.aA.prototype
if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ab.prototype
if(typeof a=="symbol")return J.aY.prototype
if(typeof a=="bigint")return J.aW.prototype
return a}if(a instanceof A.p)return a
return J.dE(a)},
a1(a){if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ab.prototype
if(typeof a=="symbol")return J.aY.prototype
if(typeof a=="bigint")return J.aW.prototype
return a}if(a instanceof A.p)return a
return J.dE(a)},
hx(a){if(typeof a=="number")return J.az.prototype
if(a==null)return a
if(!(a instanceof A.p))return J.aF.prototype
return a},
z(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.au(a).P(a,b)},
E(a,b){if(typeof b==="number")if(Array.isArray(a)||A.hF(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.a1(a).h(a,b)},
df(a,b,c){return J.a1(a).p(a,b,c)},
dK(a,b){return J.a1(a).R(a,b)},
dL(a,b,c){return J.hx(a).l(a,b,c)},
dM(a,b){return J.a1(a).C(a,b)},
L(a){return J.au(a).gA(a)},
f0(a){return J.aM(a).gD(a)},
f1(a){return J.aM(a).gaJ(a)},
dg(a){return J.a1(a).gu(a)},
Q(a){return J.aM(a).gk(a)},
f2(a){return J.au(a).gt(a)},
f3(a,b,c){return J.a1(a).b6(a,b,c)},
br(a){return J.au(a).j(a)},
bE:function bE(){},
bG:function bG(){},
aV:function aV(){},
aX:function aX(){},
ad:function ad(){},
bT:function bT(){},
aF:function aF(){},
ab:function ab(){},
aW:function aW(){},
aY:function aY(){},
n:function n(a){this.$ti=a},
bF:function bF(){},
cz:function cz(a){this.$ti=a},
ak:function ak(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
az:function az(){},
aU:function aU(){},
bH:function bH(){},
aA:function aA(){}},A={dl:function dl(){},
fp(a){return new A.ac("Field '"+a+"' has not been initialized.")},
b_(a){return new A.ac("Local '"+a+"' has not been initialized.")},
fo(a){return new A.ac("Field '"+a+"' has already been initialized.")},
af(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
dv(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
eC(a,b,c){return a},
dH(a){var t,s
for(t=$.P.length,s=0;s<t;++s)if(a===$.P[s])return!0
return!1},
ec(a,b,c,d){A.ds(b,"start")
if(c!=null){A.ds(c,"end")
if(b>c)A.V(A.b8(b,0,c,"start",null))}return new A.bc(a,b,c,d.i("bc<0>"))},
dX(){return new A.bb("No element")},
ac:function ac(a){this.a=a},
aP:function aP(a){this.a=a},
cN:function cN(){},
aS:function aS(){},
I:function I(){},
bc:function bc(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
a8:function a8(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
S:function S(a,b,c){this.a=a
this.b=b
this.$ti=c},
ap:function ap(a,b,c){this.a=a
this.b=b
this.$ti=c},
bg:function bg(a,b,c){this.a=a
this.b=b
this.$ti=c},
G:function G(){},
be:function be(){},
aG:function aG(){},
eM(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
hF(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
t(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.br(a)
return t},
bU(a){var t,s=$.e7
if(s==null)s=$.e7=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bV(a){var t,s,r,q
if(a instanceof A.p)return A.J(A.aj(a),null)
t=J.au(a)
if(t===B.H||t===B.J||u.o.b(a)){s=B.n(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.J(A.aj(a),null)},
e8(a){var t,s,r
if(a==null||typeof a=="number"||A.d3(a))return J.br(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.F)return a.j(0)
if(a instanceof A.as)return a.aW(!0)
t=$.f_()
for(s=0;s<1;++s){r=t[s].c3(a)
if(r!=null)return r}return"Instance of '"+A.bV(a)+"'"},
fr(){return Date.now()},
fs(){var t,s
if($.cM!==0)return
$.cM=1000
if(typeof window=="undefined")return
t=window
if(t==null)return
if(!!t.dartUseDateNowForTicks)return
s=t.performance
if(s==null)return
if(typeof s.now!="function")return
$.cM=1e6
$.e9=new A.cL(s)},
C(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.c.aV(t,10)|55296)>>>0,t&1023|56320)}throw A.c(A.b8(a,0,1114111,null,null))},
d7(a){throw A.c(A.eB(a))},
h(a,b){if(a==null)J.Q(a)
throw A.c(A.d5(a,b))},
d5(a,b){var t,s="index"
if(!A.ew(b))return new A.a2(!0,b,s,null)
t=J.Q(a)
if(b<0||b>=t)return A.di(b,t,a,s)
return new A.b7(null,null,!0,b,s,"Value not in range")},
eB(a){return new A.a2(!0,a,null,null)},
c(a){return A.y(a,new Error())},
y(a,b){var t
if(a==null)a=new A.bd()
b.dartException=a
t=A.hN
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hN(){return J.br(this.dartException)},
V(a,b){throw A.y(a,b==null?new Error():b)},
aO(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.V(A.h1(a,b,c),t)},
h1(a,b,c){var t,s,r,q,p,o,n,m,l
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
return new A.bf("'"+t+"': Cannot "+p+" "+m+l+o)},
B(a){throw A.c(A.M(a))},
a9(a){var t,s,r,q,p,o
a=A.hL(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.m([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.cQ(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
cR(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
ed(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
dm(a,b){var t=b==null,s=t?null:b.method
return new A.bI(a,s,t?null:b.receiver)},
eN(a){if(a==null)return new A.cJ(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aw(a,a.dartException)
return A.hs(a)},
aw(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
hs(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.c.aV(s,16)&8191)===10)switch(r){case 438:return A.aw(a,A.dm(A.t(t)+" (Error "+r+")",null))
case 445:case 5007:A.t(t)
return A.aw(a,new A.b6())}}if(a instanceof TypeError){q=$.eQ()
p=$.eR()
o=$.eS()
n=$.eT()
m=$.eW()
l=$.eX()
k=$.eV()
$.eU()
j=$.eZ()
i=$.eY()
h=q.E(t)
if(h!=null)return A.aw(a,A.dm(A.ah(t),h))
else{h=p.E(t)
if(h!=null){h.method="call"
return A.aw(a,A.dm(A.ah(t),h))}else if(o.E(t)!=null||n.E(t)!=null||m.E(t)!=null||l.E(t)!=null||k.E(t)!=null||n.E(t)!=null||j.E(t)!=null||i.E(t)!=null){A.ah(t)
return A.aw(a,new A.b6())}}return A.aw(a,new A.c1(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.ba()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.aw(a,new A.a2(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.ba()
return a},
eJ(a){if(a==null)return J.L(a)
if(typeof a=="object")return A.bU(a)
return J.L(a)},
hw(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.p(0,a[t],a[s])}return b},
fa(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bZ().constructor.prototype):Object.create(new A.ay(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.dS(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.f6(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.dS(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
f6(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.c("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.f4)}throw A.c("Error in functionType of tearoff")},
f7(a,b,c,d){var t=A.dR
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
dS(a,b,c,d){if(c)return A.f9(a,b,d)
return A.f7(b.length,d,a,b)},
f8(a,b,c,d){var t=A.dR,s=A.f5
switch(b?-1:a){case 0:throw A.c(new A.bX("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
f9(a,b,c){var t,s
if($.dP==null)$.dP=A.dO("interceptor")
if($.dQ==null)$.dQ=A.dO("receiver")
t=b.length
s=A.f8(t,c,a,b)
return s},
dD(a){return A.fa(a)},
f4(a,b){return A.bq(v.typeUniverse,A.aj(a.a),b)},
dR(a){return a.a},
f5(a){return a.b},
dO(a){var t,s,r,q=new A.ay("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.c(A.c9("Field name "+a+" not found."))},
eE(a){return v.getIsolateTag(a)},
hG(a){var t,s,r,q,p,o=A.ah($.eF.$1(a)),n=$.d6[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.db[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.c7($.eA.$2(a,o))
if(r!=null){n=$.d6[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.db[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.dd(t)
$.d6[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.db[o]=t
return t}if(q==="-"){p=A.dd(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.eK(a,t)
if(q==="*")throw A.c(A.ee(o))
if(v.leafTags[o]===true){p=A.dd(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.eK(a,t)},
eK(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.dI(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
dd(a){return J.dI(a,!1,null,!!a.$iN)},
hI(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.dd(t)
else return J.dI(t,c,null,null)},
hB(){if(!0===$.dG)return
$.dG=!0
A.hC()},
hC(){var t,s,r,q,p,o,n,m
$.d6=Object.create(null)
$.db=Object.create(null)
A.hA()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.eL.$1(p)
if(o!=null){n=A.hI(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
hA(){var t,s,r,q,p,o,n=B.v()
n=A.aL(B.w,A.aL(B.x,A.aL(B.o,A.aL(B.o,A.aL(B.y,A.aL(B.z,A.aL(B.A(B.n),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.eF=new A.d8(q)
$.eA=new A.d9(p)
$.eL=new A.da(o)},
aL(a,b){return a(b)||b},
hu(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
hL(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
aI:function aI(a,b){this.a=a
this.b=b},
aQ:function aQ(){},
aR:function aR(a,b,c){this.a=a
this.b=b
this.$ti=c},
bD:function bD(){},
am:function am(a,b){this.a=a
this.$ti=b},
cL:function cL(a){this.a=a},
b9:function b9(){},
cQ:function cQ(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b6:function b6(){},
bI:function bI(a,b,c){this.a=a
this.b=b
this.c=c},
c1:function c1(a){this.a=a},
cJ:function cJ(a){this.a=a},
F:function F(){},
bu:function bu(){},
bv:function bv(){},
c_:function c_(){},
bZ:function bZ(){},
ay:function ay(a,b){this.a=a
this.b=b},
bX:function bX(a){this.a=a},
a5:function a5(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cA:function cA(a){this.a=a},
cE:function cE(a,b){this.a=a
this.b=b
this.c=null},
a7:function a7(a,b){this.a=a
this.$ti=b},
an:function an(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
a6:function a6(a,b){this.a=a
this.$ti=b},
b0:function b0(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
d8:function d8(a){this.a=a},
d9:function d9(a){this.a=a},
da:function da(a){this.a=a},
as:function as(){},
aH:function aH(){},
hM(a){throw A.y(new A.ac("Field '"+a+"' has been assigned during initialization."),new Error())},
d(){throw A.y(A.fp(""),new Error())},
K(){throw A.y(A.fo(""),new Error())},
cT(){var t=new A.cS()
return t.b=t},
cS:function cS(){this.b=null},
at(a,b,c){if(a>>>0!==a||a>=c)throw A.c(A.d5(b,a))},
aB:function aB(){},
b3:function b3(){},
bK:function bK(){},
aC:function aC(){},
b1:function b1(){},
b2:function b2(){},
bL:function bL(){},
bM:function bM(){},
bN:function bN(){},
bO:function bO(){},
bP:function bP(){},
bQ:function bQ(){},
bR:function bR(){},
b4:function b4(){},
bS:function bS(){},
bi:function bi(){},
bj:function bj(){},
bk:function bk(){},
bl:function bl(){},
dt(a,b){var t=b.c
return t==null?b.c=A.bo(a,"dT",[b.x]):t},
ea(a){var t=a.w
if(t===6||t===7)return A.ea(a.x)
return t===11||t===12},
fw(a){return a.as},
c8(a){return A.d_(v.typeUniverse,a,!1)},
hE(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.ai(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
ai(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.ai(a0,t,a2,a3)
if(s===t)return a1
return A.en(a0,s,!0)
case 7:t=a1.x
s=A.ai(a0,t,a2,a3)
if(s===t)return a1
return A.em(a0,s,!0)
case 8:r=a1.y
q=A.aK(a0,r,a2,a3)
if(q===r)return a1
return A.bo(a0,a1.x,q)
case 9:p=a1.x
o=A.ai(a0,p,a2,a3)
n=a1.y
m=A.aK(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.dy(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.aK(a0,k,a2,a3)
if(j===k)return a1
return A.eo(a0,l,j)
case 11:i=a1.x
h=A.ai(a0,i,a2,a3)
g=a1.y
f=A.hp(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.el(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.aK(a0,e,a2,a3)
p=a1.x
o=A.ai(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.dz(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.c(A.bt("Attempted to substitute unexpected RTI kind "+a))}},
aK(a,b,c,d){var t,s,r,q,p=b.length,o=A.d0(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.ai(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
hq(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.d0(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.ai(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
hp(a,b,c,d){var t,s=b.a,r=A.aK(a,s,c,d),q=b.b,p=A.aK(a,q,c,d),o=b.c,n=A.hq(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.c3()
t.a=r
t.b=p
t.c=n
return t},
m(a,b){a[v.arrayRti]=b
return a},
d4(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.hz(t)
return a.$S()}return null},
hD(a,b){var t
if(A.ea(b))if(a instanceof A.F){t=A.d4(a)
if(t!=null)return t}return A.aj(a)},
aj(a){if(a instanceof A.p)return A.A(a)
if(Array.isArray(a))return A.D(a)
return A.dB(J.au(a))},
D(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
A(a){var t=a.$ti
return t!=null?t:A.dB(a)},
dB(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.h8(a,t)},
h8(a,b){var t=a instanceof A.F?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fT(v.typeUniverse,t.name)
b.$ccache=s
return s},
hz(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.d_(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
hy(a){return A.aa(A.A(a))},
dF(a){var t=A.d4(a)
return A.aa(t==null?A.aj(a):t)},
dC(a){var t
if(a instanceof A.as)return A.hv(a.$r,a.aR())
t=a instanceof A.F?A.d4(a):null
if(t!=null)return t
if(u.k.b(a))return J.f2(a).a
if(Array.isArray(a))return A.D(a)
return A.aj(a)},
aa(a){var t=a.r
return t==null?a.r=new A.cZ(a):t},
hv(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.h(r,0)
t=A.bq(v.typeUniverse,A.dC(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.h(r,s)
t=A.ep(v.typeUniverse,t,A.dC(r[s]))}return A.bq(v.typeUniverse,t,a)},
Y(a){return A.aa(A.d_(v.typeUniverse,a,!1))},
h7(a){var t=this
t.b=A.ho(t)
return t.b(a)},
ho(a){var t,s,r,q,p
if(a===u.K)return A.he
if(A.av(a))return A.hi
t=a.w
if(t===6)return A.h5
if(t===1)return A.ey
if(t===7)return A.h9
s=A.hn(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.av)){a.f="$i"+r
if(r==="i")return A.hc
if(a===u.m)return A.hb
return A.hh}}else if(t===10){q=A.hu(a.x,a.y)
p=q==null?A.ey:q
return p==null?A.es(p):p}return A.h3},
hn(a){if(a.w===8){if(a===u.S)return A.ew
if(a===u.i||a===u.H)return A.hd
if(a===u.N)return A.hg
if(a===u.y)return A.d3}return null},
h6(a){var t=this,s=A.h2
if(A.av(t))s=A.fZ
else if(t===u.K)s=A.es
else if(A.aN(t)){s=A.h4
if(t===u.x)s=A.fW
else if(t===u.w)s=A.c7
else if(t===u.e)s=A.U
else if(t===u.B)s=A.q
else if(t===u.I)s=A.fV
else if(t===u.A)s=A.fY}else if(t===u.S)s=A.d1
else if(t===u.N)s=A.ah
else if(t===u.y)s=A.dA
else if(t===u.H)s=A.v
else if(t===u.i)s=A.a0
else if(t===u.m)s=A.fX
t.a=s
return t.a(a)},
h3(a){var t=this
if(a==null)return A.aN(t)
return A.eG(v.typeUniverse,A.hD(a,t),t)},
h5(a){if(a==null)return!0
return this.x.b(a)},
hh(a){var t,s=this
if(a==null)return A.aN(s)
t=s.f
if(a instanceof A.p)return!!a[t]
return!!J.au(a)[t]},
hc(a){var t,s=this
if(a==null)return A.aN(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.p)return!!a[t]
return!!J.au(a)[t]},
hb(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.p)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
ex(a){if(typeof a=="object"){if(a instanceof A.p)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
h2(a){var t=this
if(a==null){if(A.aN(t))return a}else if(t.b(a))return a
throw A.y(A.et(a,t),new Error())},
h4(a){var t=this
if(a==null||t.b(a))return a
throw A.y(A.et(a,t),new Error())},
et(a,b){return new A.aJ("TypeError: "+A.ef(a,A.J(b,null)))},
eD(a,b,c,d){if(A.eG(v.typeUniverse,a,b))return a
throw A.y(A.fL("The type argument '"+A.J(a,null)+"' is not a subtype of the type variable bound '"+A.J(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
ef(a,b){return A.bA(a)+": type '"+A.J(A.dC(a),null)+"' is not a subtype of type '"+b+"'"},
fL(a){return new A.aJ("TypeError: "+a)},
T(a,b){return new A.aJ("TypeError: "+A.ef(a,b))},
h9(a){var t=this
return t.x.b(a)||A.dt(v.typeUniverse,t).b(a)},
he(a){return a!=null},
es(a){if(a!=null)return a
throw A.y(A.T(a,"Object"),new Error())},
hi(a){return!0},
fZ(a){return a},
ey(a){return!1},
d3(a){return!0===a||!1===a},
dA(a){if(!0===a)return!0
if(!1===a)return!1
throw A.y(A.T(a,"bool"),new Error())},
U(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.y(A.T(a,"bool?"),new Error())},
a0(a){if(typeof a=="number")return a
throw A.y(A.T(a,"double"),new Error())},
fV(a){if(typeof a=="number")return a
if(a==null)return a
throw A.y(A.T(a,"double?"),new Error())},
ew(a){return typeof a=="number"&&Math.floor(a)===a},
d1(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.y(A.T(a,"int"),new Error())},
fW(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.y(A.T(a,"int?"),new Error())},
hd(a){return typeof a=="number"},
v(a){if(typeof a=="number")return a
throw A.y(A.T(a,"num"),new Error())},
q(a){if(typeof a=="number")return a
if(a==null)return a
throw A.y(A.T(a,"num?"),new Error())},
hg(a){return typeof a=="string"},
ah(a){if(typeof a=="string")return a
throw A.y(A.T(a,"String"),new Error())},
c7(a){if(typeof a=="string")return a
if(a==null)return a
throw A.y(A.T(a,"String?"),new Error())},
fX(a){if(A.ex(a))return a
throw A.y(A.T(a,"JSObject"),new Error())},
fY(a){if(a==null)return a
if(A.ex(a))return a
throw A.y(A.T(a,"JSObject?"),new Error())},
ez(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.J(a[r],b)
return t},
hm(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.ez(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.J(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
eu(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.m([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.m(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.h(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.J(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.J(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.J(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.J(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.J(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
J(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.J(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.J(a.x,b)+">"
if(m===8){q=A.hr(a.x)
p=a.y
return p.length>0?q+("<"+A.ez(p,b)+">"):q}if(m===10)return A.hm(a,b)
if(m===11)return A.eu(a,b,null)
if(m===12)return A.eu(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.h(b,o)
return b[o]}return"?"},
hr(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
fU(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fT(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.d_(a,b,!1)
else if(typeof n=="number"){t=n
s=A.bp(a,5,"#")
r=A.d0(t)
for(q=0;q<t;++q)r[q]=s
p=A.bo(a,b,r)
o[b]=p
return p}else return n},
fS(a,b){return A.eq(a.tR,b)},
fR(a,b){return A.eq(a.eT,b)},
d_(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.ej(A.eh(a,null,b,!1))
s.set(b,t)
return t},
bq(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.ej(A.eh(a,b,c,!0))
r.set(c,s)
return s},
ep(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.dy(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
ag(a,b){b.a=A.h6
b.b=A.h7
return b},
bp(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.W(null,null)
t.w=b
t.as=c
s=A.ag(a,t)
a.eC.set(c,s)
return s},
en(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fP(a,b,s,c)
a.eC.set(s,t)
return t},
fP(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.av(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aN(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.W(null,null)
r.w=6
r.x=b
r.as=c
return A.ag(a,r)},
em(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fN(a,b,s,c)
a.eC.set(s,t)
return t},
fN(a,b,c,d){var t,s
if(d){t=b.w
if(A.av(b)||b===u.K)return b
else if(t===1)return A.bo(a,"dT",[b])
else if(b===u.P||b===u.T)return u.Q}s=new A.W(null,null)
s.w=7
s.x=b
s.as=c
return A.ag(a,s)},
fQ(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.W(null,null)
t.w=13
t.x=b
t.as=r
s=A.ag(a,t)
a.eC.set(r,s)
return s},
bn(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fM(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bo(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.bn(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.W(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.ag(a,s)
a.eC.set(q,r)
return r},
dy(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.bn(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.W(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.ag(a,p)
a.eC.set(r,o)
return o},
eo(a,b,c){var t,s,r="+"+(b+"("+A.bn(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.W(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.ag(a,t)
a.eC.set(r,s)
return s},
el(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.bn(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.bn(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fM(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.W(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.ag(a,q)
a.eC.set(s,p)
return p},
dz(a,b,c,d){var t,s=b.as+("<"+A.bn(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fO(a,b,c,s,d)
a.eC.set(s,t)
return t},
fO(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.d0(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.ai(a,b,s,0)
n=A.aK(a,c,s,0)
return A.dz(a,o,n,c!==n)}}m=new A.W(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.ag(a,m)},
eh(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
ej(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.fG(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.ei(a,s,m,l,!1)
else if(r===46)s=A.ei(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.ar(a.u,a.e,l.pop()))
break
case 94:l.push(A.fQ(a.u,l.pop()))
break
case 35:l.push(A.bp(a.u,5,"#"))
break
case 64:l.push(A.bp(a.u,2,"@"))
break
case 126:l.push(A.bp(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.fI(a,l)
break
case 38:A.fH(a,l)
break
case 63:q=a.u
l.push(A.en(q,A.ar(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.em(q,A.ar(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.fF(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.ek(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fK(a.u,a.e,p)
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
return A.ar(a.u,a.e,n)},
fG(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
ei(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fU(t,p.x)[q]
if(o==null)A.V('No "'+q+'" in "'+A.fw(p)+'"')
d.push(A.bq(t,p,o))}else d.push(q)
return n},
fI(a,b){var t,s=a.u,r=A.eg(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bo(s,q,r))
else{t=A.ar(s,a.e,q)
switch(t.w){case 11:b.push(A.dz(s,t,r,a.n))
break
default:b.push(A.dy(s,t,r))
break}}},
fF(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.eg(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.ar(q,a.e,p)
r=new A.c3()
r.a=t
r.b=o
r.c=n
b.push(A.el(q,s,r))
return
case-4:b.push(A.eo(q,b.pop(),t))
return
default:throw A.c(A.bt("Unexpected state under `()`: "+A.t(p)))}},
fH(a,b){var t=b.pop()
if(0===t){b.push(A.bp(a.u,1,"0&"))
return}if(1===t){b.push(A.bp(a.u,4,"1&"))
return}throw A.c(A.bt("Unexpected extended operation "+A.t(t)))},
eg(a,b){var t=b.splice(a.p)
A.ek(a.u,a.e,t)
a.p=b.pop()
return t},
ar(a,b,c){if(typeof c=="string")return A.bo(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.fJ(a,b,c)}else return c},
ek(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.ar(a,b,c[t])},
fK(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.ar(a,b,c[t])},
fJ(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.c(A.bt("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.c(A.bt("Bad index "+c+" for "+b.j(0)))},
eG(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.x(a,b,null,c,null)
s.set(c,t)}return t},
x(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.av(d))return!0
t=b.w
if(t===4)return!0
if(A.av(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.x(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.x(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.x(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.x(a,b.x,c,d,e))return!1
return A.x(a,A.dt(a,b),c,d,e)}if(t===6)return A.x(a,q,c,d,e)&&A.x(a,b.x,c,d,e)
if(r===7){if(A.x(a,b,c,d.x,e))return!0
return A.x(a,b,c,A.dt(a,d),e)}if(r===6)return A.x(a,b,c,q,e)||A.x(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.J)return!0
if(r===12){if(b===u.M)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.x(a,k,c,j,e)||!A.x(a,j,e,k,c))return!1}return A.ev(a,b.x,c,d.x,e)}if(r===11){if(b===u.M)return!0
if(q)return!1
return A.ev(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.ha(a,b,c,d,e)}if(p&&r===10)return A.hf(a,b,c,d,e)
return!1},
ev(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
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
ha(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bq(a,b,s[p])
return A.er(a,q,null,c,d.y,e)}return A.er(a,b.y,null,c,d.y,e)},
er(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.x(a,b[t],d,e[t],f))return!1
return!0},
hf(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.x(a,s[t],c,r[t],e))return!1
return!0},
aN(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.av(a))if(t!==6)s=t===7&&A.aN(a.x)
return s},
av(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
eq(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
d0(a){return a>0?new Array(a):v.typeUniverse.sEA},
W:function W(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
c3:function c3(){this.c=this.b=this.a=null},
cZ:function cZ(a){this.a=a},
c2:function c2(){},
aJ:function aJ(a){this.a=a},
e2(a,b){return new A.a5(a.i("@<0>").K(b).i("a5<1,2>"))},
H(a,b,c){return b.i("@<0>").K(c).i("e1<1,2>").a(A.hw(a,new A.a5(b.i("@<0>").K(c).i("a5<1,2>"))))},
dn(a,b){return new A.a5(a.i("@<0>").K(b).i("a5<1,2>"))},
cG(a){return new A.bh(a.i("bh<0>"))},
dx(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
fE(a,b,c){var t=new A.aq(a,b,c.i("aq<0>"))
t.c=a.e
return t},
fj(a,b){var t=a.a,s=new A.an(t,t.r,t.e,a.$ti.i("an<1>"))
if(s.n())return s.d
return null},
fq(a,b,c){var t=A.e2(b,c)
a.O(0,new A.cF(t,b,c))
return t},
e3(a,b,c){var t=A.e2(b,c)
t.R(0,a)
return t},
dr(a){var t,s
if(A.dH(a))return"{...}"
t=new A.aE("")
try{s={}
B.a.m($.P,a)
t.a+="{"
s.a=!0
a.O(0,new A.cH(s,t))
t.a+="}"}finally{if(0>=$.P.length)return A.h($.P,-1)
$.P.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
bh:function bh(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
c6:function c6(a){this.a=a
this.c=this.b=null},
aq:function aq(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
cF:function cF(a,b,c){this.a=a
this.b=b
this.c=c},
j:function j(){},
O:function O(){},
cH:function cH(a,b){this.a=a
this.b=b},
aD:function aD(){},
bm:function bm(){},
hl(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.eN(s)
r=A.R(String(t))
throw A.c(r)}r=A.d2(q)
return r},
d2(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.c4(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.d2(a[t])
return a},
e0(a,b,c){return new A.aZ(a,b)},
h0(a){return a.a_()},
fC(a,b){return new A.cV(a,[],A.ht())},
fD(a,b,c){var t,s=new A.aE(""),r=A.fC(s,b)
r.ah(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
c4:function c4(a,b){this.a=a
this.b=b
this.c=null},
c5:function c5(a){this.a=a},
bw:function bw(){},
by:function by(){},
aZ:function aZ(a,b){this.a=a
this.b=b},
bJ:function bJ(a,b){this.a=a
this.b=b},
cB:function cB(){},
cD:function cD(a){this.b=a},
cC:function cC(a){this.a=a},
cW:function cW(){},
cX:function cX(a,b){this.a=a
this.b=b},
cV:function cV(a,b,c){this.c=a
this.a=b
this.b=c},
dq(a,b,c,d){var t,s=c?J.dZ(a,d):J.dY(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
e4(a,b,c){var t,s,r=A.m([],c.i("n<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.B)(a),++s)B.a.m(r,c.a(a[s]))
if(b)return r
r.$flags=1
return r},
dp(a,b){var t,s=A.m([],b.i("n<0>"))
for(t=a.gu(a);t.n();)B.a.m(s,t.gq())
return s},
eb(a,b,c){var t=J.dg(b)
if(!t.n())return a
if(c.length===0){do a+=A.t(t.gq())
while(t.n())}else{a+=A.t(t.gq())
while(t.n())a=a+c+A.t(t.gq())}return a},
bA(a){if(typeof a=="number"||A.d3(a)||a==null)return J.br(a)
if(typeof a=="string")return JSON.stringify(a)
return A.e8(a)},
bt(a){return new A.bs(a)},
c9(a){return new A.a2(!1,null,null,a)},
dN(a,b,c){return new A.a2(!0,a,b,c)},
b8(a,b,c,d,e){return new A.b7(b,c,!0,a,d,"Invalid value")},
fu(a,b,c){if(0>a||a>c)throw A.c(A.b8(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.c(A.b8(b,a,c,"end",null))
return b}return c},
ds(a,b){if(a<0)throw A.c(A.b8(a,0,null,b,null))
return a},
di(a,b,c,d){return new A.bC(b,!0,a,d,"Index out of range")},
dw(a){return new A.bf(a)},
ee(a){return new A.c0(a)},
bY(a){return new A.bb(a)},
M(a){return new A.bx(a)},
R(a){return new A.a3(a)},
fk(a,b,c){var t,s
if(A.dH(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.m([],u.s)
B.a.m($.P,a)
try{A.hj(a,t)}finally{if(0>=$.P.length)return A.h($.P,-1)
$.P.pop()}s=A.eb(b,u.R.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
dj(a,b,c){var t,s
if(A.dH(a))return b+"..."+c
t=new A.aE(b)
B.a.m($.P,a)
try{s=t
s.a=A.eb(s.a,a,", ")}finally{if(0>=$.P.length)return A.h($.P,-1)
$.P.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
hj(a,b){var t,s,r,q,p,o,n,m=a.gu(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.n())return
t=A.t(m.gq())
B.a.m(b,t)
l+=t.length+2;++k}if(!m.n()){if(k<=5)return
if(0>=b.length)return A.h(b,-1)
s=b.pop()
if(0>=b.length)return A.h(b,-1)
r=b.pop()}else{q=m.gq();++k
if(!m.n()){if(k<=4){B.a.m(b,A.t(q))
return}s=A.t(q)
if(0>=b.length)return A.h(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gq();++k
for(;m.n();q=p,p=o){o=m.gq();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.h(b,-1)
l-=b.pop().length+2;--k}B.a.m(b,"...")
return}}r=A.t(q)
s=A.t(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.h(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.m(b,n)
B.a.m(b,r)
B.a.m(b,s)},
e6(a,b,c,d){var t
if(B.h===c){t=J.L(a)
b=J.L(b)
return A.dv(A.af(A.af($.de(),t),b))}if(B.h===d){t=J.L(a)
b=J.L(b)
c=J.L(c)
return A.dv(A.af(A.af(A.af($.de(),t),b),c))}t=J.L(a)
b=J.L(b)
c=J.L(c)
d=J.L(d)
d=A.dv(A.af(A.af(A.af(A.af($.de(),t),b),c),d))
return d},
r:function r(){},
bs:function bs(a){this.a=a},
bd:function bd(){},
a2:function a2(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
b7:function b7(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bC:function bC(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bf:function bf(a){this.a=a},
c0:function c0(a){this.a=a},
bb:function bb(a){this.a=a},
bx:function bx(a){this.a=a},
ba:function ba(){},
a3:function a3(a){this.a=a},
e:function e(){},
ao:function ao(a,b,c){this.a=a
this.b=b
this.$ti=c},
b5:function b5(){},
p:function p(){},
cP:function cP(){this.b=this.a=0},
aE:function aE(a){this.a=a},
fb(a){var t,s,r,q,p,o,n,m,l,k,j=null,i=a.h(0,"aspects")
if(i==null)i=a.h(0,"enemyAspects")
if(u.j.b(i)&&J.f1(i)){t=J.f3(i,new A.cb(),u.i)
s=A.dp(t,t.$ti.i("I.E"))}else s=B.p
t=A.q(a.h(0,"areaMultiplier"))
if(t==null)t=j
if(t==null){t=A.q(a.h(0,"enemyAreaMultiplier"))
if(t==null)t=j}if(t==null)t=2
r=A.q(a.h(0,"angleMinDeg"))
if(r==null)r=j
if(r==null)r=30
q=A.q(a.h(0,"angleMaxDeg"))
if(q==null)q=j
if(q==null)q=60
p=A.q(a.h(0,"speedMin"))
if(p==null)p=j
if(p==null)p=75
o=A.q(a.h(0,"speedMax"))
if(o==null)o=j
if(o==null)o=105
n=A.q(a.h(0,"accelMin"))
if(n==null)n=j
if(n==null)n=9
m=A.q(a.h(0,"accelMax"))
if(m==null)m=j
if(m==null)m=15
l=A.U(a.h(0,"collideWithEachOther"))
if(l==null)l=A.U(a.h(0,"enemiesCollide"))
k=A.q(a.h(0,"spinDegPerSec"))
if(k==null)k=j
if(k==null)k=0
return new A.bz(t,s,r,q,p,o,n,m,l===!0,k)},
dU(a1){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null,b="warning",a=A.U(a1.h(0,"startHintEnabled")),a0=A.q(a1.h(0,"idleSpeedMultiplier"))
if(a0==null)a0=c
if(a0==null)a0=0.5
t=A.U(a1.h(0,"idleEnemiesMove"))
s=A.q(a1.h(0,"speedRampSeconds"))
if(s==null)s=c
if(s==null)s=0.5
r=A.U(a1.h(0,"jumpEnabled"))
if(r==null)r=A.U(a1.h(0,"jumpsEnabled"))
q=A.q(a1.h(0,"jumpDurationSec"))
if(q==null)q=c
if(q==null)q=0.38
p=A.q(a1.h(0,"jumpCooldownSec"))
if(p==null)p=c
if(p==null)p=2
o=A.q(a1.h(0,"jumpScale"))
if(o==null)o=c
if(o==null)o=1.32
n=A.U(a1.h(0,"helmetEnabled"))
m=A.q(a1.h(0,"helmetInvulnSec"))
if(m==null)m=c
if(m==null)m=0.3
l=A.q(a1.h(0,"helmetCooldownSec"))
if(l==null)l=c
if(l==null)l=0
k=A.q(a1.h(0,"startInvulnSec"))
if(k==null)k=c
if(k==null)k=1
j=A.U(a1.h(0,"heartbeatHaptic"))
i=A.U(a1.h(0,"timerHaptic"))
h=A.c7(a1.h(0,"timerHapticStyle"))
if(h==null)h=b
g=A.c7(a1.h(0,"timerHapticStyle5"))
if(g==null)g=b
f=A.c7(a1.h(0,"timerHapticStyle10"))
if(f==null)f=b
e=A.q(a1.h(0,"hudSpeedScaleMax"))
if(e==null)e=c
if(e==null)e=400
d=A.U(a1.h(0,"wallsKillPlayer"))
return new A.ci(a!==!1,a0,t!==!1,s,r!==!1,q,p,o,n!==!1,m,l,k,j!==!1,i!==!1,h,g,f,e,d!==!1)},
e5(a,b){if(a==null)return b
if(typeof a!="number"||!isFinite(a)||a<0||a>0.5)throw A.c(B.B)
return a},
cw:function cw(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bz:function bz(a,b,c,d,e,f,g,h,i,j){var _=this
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
cb:function cb(){},
cK:function cK(a,b){this.a=a
this.b=b},
ch:function ch(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ci:function ci(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
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
_.CW=r
_.cx=s},
ca:function ca(){},
cI:function cI(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
fc(a){var t=new A.cd()
t.bk(a)
return t},
cd:function cd(){var _=this
_.y=_.x=_.w=_.r=_.f=_.e=_.d=_.c=_.b=_.a=$
_.as=_.Q=_.z=0
_.at=-100
_.cx=_.CW=_.ch=_.ay=0},
cf:function cf(a){this.a=a},
ce:function ce(a){this.a=a},
dV(a,b){return new A.k(Math.max(a.a,b.a),Math.max(a.b,b.b),Math.min(a.c,b.c),Math.min(a.d,b.d))},
a:function a(a,b){this.a=a
this.b=b},
cO:function cO(a,b){this.a=a
this.b=b},
k:function k(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bB(a,b){var t
if(isFinite(a)&&a>0)t=isFinite(b)&&b>0&&Math.abs(a/b-1)<=0.030000001
else t=!1
return t},
ff(a3,a4,a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
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
if(!A.bB(c,380)||!A.bB(d.b,380))return"world_scale"
if(!A.bB(g,a5.b)||!A.bB(a4.c-f,a4.d-e))return"field_distorted"
t=A.dV(a4,a6)
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
if(A.bB(s,r)){a0=s
if(typeof a0!=="number")return a0.aj()
if(!(a0<0.03)){a=s
if(typeof a!=="number")return a.c9()
a=a>0.25}}if(a)return"hero_scale"
q=(a4.c-f)/c
p=(a4.d-e)/d.b
o=new A.cl(a7)
n=new A.ck(q,p,a3)
f=a7.w
f===$&&A.d()
e=f.a
f=f.b
if(!o.$1(new A.k(e,f,e+b,f+b))||!n.$2(b,b))return"hero_invisible"
g=g.a
f=g.b
e=A.D(f)
d=e.i("ap<1>")
a1=A.dp(new A.ap(f,e.i("u(1)").a(new A.cj()),d),d.i("e.E"))
m=a1
if(J.Q(m)===0)J.dK(m,A.m([1,0.25,0.5,3],u.t))
f=a7.x
if(f.length!==4||J.Q(m)!==4)return"enemy_count"
l=b*b*B.b.l(g.a,0.2,20)
k=0
for(;;){g=k
if(typeof g!=="number")return g.aj()
if(!(g<4))break
j=B.a.h(f,k)
g=l
e=J.E(m,k)
if(typeof g!=="number")return g.W()
i=Math.sqrt(g*e)
e=l
g=J.E(m,k)
if(typeof e!=="number")return e.ai()
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
g===$&&A.d()
if(isFinite(g.a)&&isFinite(g.b))if(isFinite(j.CW))if(o.$1(j.gB())){g=j.c
g===$&&A.d()
g=g.a
e=j.c
e===$&&A.d()
e=e.b
g=!o.$1(new A.k(g,e,g+j.y,e+j.z))||!n.$2(j.y,j.z)}else g=e
else g=e
else g=e}else g=e
if(g)return"enemy_invisible"
g=j.b
if(isFinite(g.a)&&isFinite(g.b)){g=j.d
g===$&&A.d()
g=!(isFinite(g.a)&&isFinite(g.b))||!isFinite(j.ay)||j.ay<0||!isFinite(j.ch)||j.ch<0}else g=!0
if(g)return"enemy_motion"
g=k
if(typeof g!=="number")return g.H()
k=g+1}return null}catch(a2){return"world_not_ready"}},
cl:function cl(a){this.a=a},
ck:function ck(a,b,c){this.a=a
this.b=b
this.c=c},
cj:function cj(){},
dW(a){var t=new A.cx(A.m([],u.U))
t.bl(a)
return t},
cx:function cx(a){var _=this
_.cx=null
_.cy=0
_.a=$
_.b=null
_.r=_.f=_.e=_.d=_.c=$
_.x=_.w=0
_.Q=_.z=_.y=!1
_.as=null
_.ay=_.ax=_.at=0
_.ch=a
_.CW=null},
cy:function cy(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=0
_.e=null},
hH(){var t,s,r={}
r.a=null
t=v.G.globalThis
r=new A.dc(r)
if(typeof r=="function")A.V(A.c9("Attempting to rewrap a JS function."))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.h_,r)
s[$.dJ()]=r
t.untouchKernel=s},
dc:function dc(a){this.a=a},
fv(a){var t,s,r,q
for(t=new A.aP(a),s=u.E,t=new A.a8(t,t.gk(0),s.i("a8<j.E>")),s=s.i("j.E"),r=2166136261;t.n();){q=t.d
r=(r^(q==null?s.a(q):q))>>>0
r=r*403+((r&255)<<24>>>0)>>>0}return r===0?1:r},
bW:function bW(a){this.a=a},
cg:function cg(a,b){this.a=a
this.b=b},
aT:function aT(){},
dh(a,b){var t,s
if(a.a5(b))return 0
t=Math.max(0,Math.max(a.a-b.c,b.a-a.c))
s=Math.max(0,Math.max(a.b-b.d,b.b-a.d))
if(t>0&&s>0)return Math.sqrt(t*t+s*s)
return Math.max(t,s)},
ax:function ax(a,b){this.a=a
this.b=b},
ae:function ae(a){this.a=a
this.b=0},
al:function al(a,b,c,d,e,f,g,h){var _=this
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
cc:function cc(a,b,c){this.a=a
this.b=b
this.c=c},
cm:function cm(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=$
_.x=h
_.y=0
_.z=i
_.at=_.as=_.Q=0
_.ax=j
_.ay=k
_.ch=l
_.CW=m},
ct:function ct(a){this.a=a},
cs:function cs(){},
cu:function cu(){},
cn:function cn(){},
co:function co(){},
cp:function cp(){},
cq:function cq(){},
cr:function cr(a){this.a=a},
cv:function cv(a){this.a=a},
h_(a,b,c){u.Z.a(a)
if(A.d1(c)>=1)return a.$1(b)
return a.$0()},
eI(a,b,c){A.eD(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
eH(a,b,c){A.eD(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.dl.prototype={}
J.bE.prototype={
P(a,b){return a===b},
gA(a){return A.bU(a)},
j(a){return"Instance of '"+A.bV(a)+"'"},
gt(a){return A.aa(A.dB(this))}}
J.bG.prototype={
j(a){return String(a)},
gA(a){return a?519018:218159},
gt(a){return A.aa(u.y)},
$il:1,
$iu:1}
J.aV.prototype={
P(a,b){return null==b},
j(a){return"null"},
gA(a){return 0},
$il:1}
J.aX.prototype={$iw:1}
J.ad.prototype={
gA(a){return 0},
j(a){return String(a)}}
J.bT.prototype={}
J.aF.prototype={}
J.ab.prototype={
j(a){var t=a[$.eO()]
if(t==null)t=a[$.dJ()]
if(t==null)return this.bj(a)
return"JavaScript function for "+J.br(t)},
$ia4:1}
J.aW.prototype={
gA(a){return 0},
j(a){return String(a)}}
J.aY.prototype={
gA(a){return 0},
j(a){return String(a)}}
J.n.prototype={
m(a,b){A.D(a).c.a(b)
a.$flags&1&&A.aO(a,29)
a.push(b)},
bA(a,b,c){var t,s,r,q,p
A.D(a).i("u(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.c(A.M(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
R(a,b){A.D(a).i("e<1>").a(b)
a.$flags&1&&A.aO(a,"addAll",2)
this.bn(a,b)
return},
bn(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.c(A.M(a))
for(s=0;s<t;++s)a.push(b[s])},
v(a){a.$flags&1&&A.aO(a,"clear","clear")
a.length=0},
b6(a,b,c){var t=A.D(a)
return new A.S(a,t.K(c).i("1(2)").a(b),t.i("@<1>").K(c).i("S<1,2>"))},
bQ(a,b){var t,s=A.dq(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.p(s,t,A.t(a[t]))
return s.join(b)},
C(a,b){if(!(b>=0&&b<a.length))return A.h(a,b)
return a[b]},
gN(a){if(a.length>0)return a[0]
throw A.c(A.dX())},
aC(a,b){var t,s
A.D(a).i("u(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.c(A.M(a))}return!1},
bN(a,b){var t,s
A.D(a).i("u(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(!b.$1(a[s]))return!1
if(a.length!==t)throw A.c(A.M(a))}return!0},
aK(a,b){var t,s,r,q
a.$flags&2&&A.aO(a,"shuffle")
t=a.length
while(t>1){s=b.bT(t);--t
r=a.length
if(!(t<r))return A.h(a,t)
q=a[t]
if(!(s>=0&&s<r))return A.h(a,s)
a[t]=a[s]
a[s]=q}},
a4(a,b){var t,s=a.length
if(0>=s)return-1
for(t=0;t<s;++t){if(!(t<a.length))return A.h(a,t)
if(J.z(a[t],b))return t}return-1},
I(a,b){var t
for(t=0;t<a.length;++t)if(J.z(a[t],b))return!0
return!1},
gD(a){return a.length===0},
gaJ(a){return a.length!==0},
j(a){return A.dj(a,"[","]")},
gu(a){return new J.ak(a,a.length,A.D(a).i("ak<1>"))},
gA(a){return A.bU(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.aO(a,"set length","change the length of")
if(b>a.length)A.D(a).c.a(null)
a.length=b},
h(a,b){if(!(b>=0&&b<a.length))throw A.c(A.d5(a,b))
return a[b]},
p(a,b,c){A.D(a).c.a(c)
a.$flags&2&&A.aO(a)
if(!(b>=0&&b<a.length))throw A.c(A.d5(a,b))
a[b]=c},
$ie:1,
$ii:1}
J.bF.prototype={
c3(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bV(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.cz.prototype={}
J.ak.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.B(r)
throw A.c(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$iZ:1}
J.az.prototype={
aE(a,b){var t
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gaI(b)
if(this.gaI(a)===t)return 0
if(this.gaI(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gaI(a){return a===0?1/a<0:a<0},
aD(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.c(A.dw(""+a+".ceil()"))},
aG(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.c(A.dw(""+a+".floor()"))},
bZ(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.c(A.dw(""+a+".round()"))},
l(a,b,c){if(this.aE(b,c)>0)throw A.c(A.eB(b))
if(this.aE(a,b)<0)return b
if(this.aE(a,c)>0)return c
return a},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gA(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
ak(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
aV(a,b){var t
if(a>0)t=this.bB(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
bB(a,b){return b>31?0:a>>>b},
gt(a){return A.aa(u.H)},
$if:1,
$iX:1}
J.aU.prototype={
gt(a){return A.aa(u.S)},
$il:1,
$ib:1}
J.bH.prototype={
gt(a){return A.aa(u.i)},
$il:1}
J.aA.prototype={
ac(a,b,c){return a.substring(b,A.fu(b,c,a.length))},
bc(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.h(q,0)
if(q.charCodeAt(0)===133){t=J.fm(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.h(q,s)
r=q.charCodeAt(s)===133?J.fn(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
j(a){return a},
gA(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gt(a){return A.aa(u.N)},
gk(a){return a.length},
$il:1,
$io:1}
A.ac.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.aP.prototype={
gk(a){return this.a.length},
h(a,b){var t=this.a
if(!(b>=0&&b<t.length))return A.h(t,b)
return t.charCodeAt(b)}}
A.cN.prototype={}
A.aS.prototype={}
A.I.prototype={
gu(a){var t=this
return new A.a8(t,t.gk(t),A.A(t).i("a8<I.E>"))},
gD(a){return this.gk(this)===0},
ag(a,b){var t,s,r,q=this
A.A(q).i("I.E(I.E,I.E)").a(b)
t=q.gk(q)
if(t===0)throw A.c(A.dX())
s=q.C(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.C(0,r))
if(t!==q.gk(q))throw A.c(A.M(q))}return s}}
A.bc.prototype={
gbr(){var t=J.Q(this.a),s=this.c
if(s==null||s>t)return t
return s},
gbD(){var t=J.Q(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.Q(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
C(a,b){var t=this,s=t.gbD()+b
if(b<0||s>=t.gbr())throw A.c(A.di(b,t.gk(0),t,"index"))
return J.dM(t.a,s)},
c2(a,b){var t,s,r,q=this,p=q.b,o=q.a,n=J.aM(o),m=n.gk(o),l=q.c
if(l!=null&&l<m)m=l
t=m-p
if(t<=0){o=q.$ti.c
return b?J.dZ(0,o):J.dY(0,o)}s=A.dq(t,n.C(o,p),b,q.$ti.c)
for(r=1;r<t;++r){B.a.p(s,r,n.C(o,p+r))
if(n.gk(o)<m)throw A.c(A.M(q))}return s},
bb(a){return this.c2(0,!0)}}
A.a8.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=J.aM(r),p=q.gk(r)
if(s.b!==p)throw A.c(A.M(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.C(r,t);++s.c
return!0},
$iZ:1}
A.S.prototype={
gk(a){return J.Q(this.a)},
C(a,b){return this.b.$1(J.dM(this.a,b))}}
A.ap.prototype={
gu(a){return new A.bg(J.dg(this.a),this.b,this.$ti.i("bg<1>"))}}
A.bg.prototype={
n(){var t,s
for(t=this.a,s=this.b;t.n();)if(s.$1(t.gq()))return!0
return!1},
gq(){return this.a.gq()},
$iZ:1}
A.G.prototype={}
A.be.prototype={}
A.aG.prototype={}
A.aI.prototype={$r:"+(1,2)",$s:1}
A.aQ.prototype={
gD(a){return this.gk(this)===0},
j(a){return A.dr(this)},
$ia_:1}
A.aR.prototype={
gk(a){return this.b.length},
gbt(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
M(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.M(b))return null
return this.b[this.a[b]]},
O(a,b){var t,s,r,q
this.$ti.i("~(1,2)").a(b)
t=this.gbt()
s=this.b
for(r=t.length,q=0;q<r;++q)b.$2(t[q],s[q])}}
A.bD.prototype={
P(a,b){if(b==null)return!1
return b instanceof A.am&&this.a.P(0,b.a)&&A.dF(this)===A.dF(b)},
gA(a){return A.e6(this.a,A.dF(this),B.h,B.h)},
j(a){var t=B.a.bQ([A.aa(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.am.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hE(A.d4(this.a),this.$ti)}}
A.cL.prototype={
$0(){return B.b.aG(1000*this.a.now())},
$S:1}
A.b9.prototype={}
A.cQ.prototype={
E(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
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
A.b6.prototype={
j(a){return"Null check operator used on a null value"}}
A.bI.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.c1.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.cJ.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.F.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.eM(s==null?"unknown":s)+"'"},
$ia4:1,
gc8(){return this},
$C:"$1",
$R:1,
$D:null}
A.bu.prototype={$C:"$0",$R:0}
A.bv.prototype={$C:"$2",$R:2}
A.c_.prototype={}
A.bZ.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.eM(t)+"'"}}
A.ay.prototype={
P(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.ay))return!1
return this.$_target===b.$_target&&this.a===b.a},
gA(a){return(A.eJ(this.a)^A.bU(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bV(this.a)+"'")}}
A.bX.prototype={
j(a){return"RuntimeError: "+this.a}}
A.a5.prototype={
gk(a){return this.a},
gD(a){return this.a===0},
gV(){return new A.a7(this,A.A(this).i("a7<1>"))},
M(a){var t=this.b
if(t==null)return!1
return t[a]!=null},
R(a,b){A.A(this).i("a_<1,2>").a(b).O(0,new A.cA(this))},
h(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.bO(b)},
bO(a){var t,s,r=this.d
if(r==null)return null
t=r[this.b1(a)]
s=this.b2(t,a)
if(s<0)return null
return t[s].b},
p(a,b,c){var t,s,r=this,q=A.A(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.aN(t==null?r.b=r.av():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.aN(s==null?r.c=r.av():s,b,c)}else r.bP(b,c)},
bP(a,b){var t,s,r,q,p=this,o=A.A(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.av()
s=p.b1(a)
r=t[s]
if(r==null)t[s]=[p.aw(a,b)]
else{q=p.b2(r,a)
if(q>=0)r[q].b=b
else r.push(p.aw(a,b))}},
v(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.aS()}},
O(a,b){var t,s,r=this
A.A(r).i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.c(A.M(r))
t=t.c}},
aN(a,b,c){var t,s=A.A(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.aw(b,c)
else t.b=c},
aS(){this.r=this.r+1&1073741823},
aw(a,b){var t=this,s=A.A(t),r=new A.cE(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.aS()
return r},
b1(a){return J.L(a)&1073741823},
b2(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.z(a[s].a,b))return s
return-1},
j(a){return A.dr(this)},
av(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$ie1:1}
A.cA.prototype={
$2(a,b){var t=this.a,s=A.A(t)
t.p(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.A(this.a).i("~(1,2)")}}
A.cE.prototype={}
A.a7.prototype={
gk(a){return this.a.a},
gD(a){return this.a.a===0},
gu(a){var t=this.a
return new A.an(t,t.r,t.e,this.$ti.i("an<1>"))},
I(a,b){return this.a.M(b)}}
A.an.prototype={
gq(){return this.d},
n(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.c(A.M(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$iZ:1}
A.a6.prototype={
gk(a){return this.a.a},
gu(a){var t=this.a
return new A.b0(t,t.r,t.e,this.$ti.i("b0<1,2>"))}}
A.b0.prototype={
gq(){var t=this.d
t.toString
return t},
n(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.c(A.M(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=new A.ao(t.a,t.b,s.$ti.i("ao<1,2>"))
s.c=t.c
return!0}},
$iZ:1}
A.d8.prototype={
$1(a){return this.a(a)},
$S:2}
A.d9.prototype={
$2(a,b){return this.a(a,b)},
$S:7}
A.da.prototype={
$1(a){return this.a(A.ah(a))},
$S:8}
A.as.prototype={
j(a){return this.aW(!1)},
aW(a){var t,s,r,q,p,o=this.bs(),n=this.aR(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.h(n,r)
p=n[r]
m=a?m+A.e8(p):m+A.t(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
bs(){var t,s=this.$s
while($.cY.length<=s)B.a.m($.cY,null)
t=$.cY[s]
if(t==null){t=this.bo()
B.a.p($.cY,s,t)}return t},
bo(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=u.K,k=J.dk(m,l)
for(t=0;t<m;++t)k[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.p(k,r,s[t])}}k=A.e4(k,!1,l)
k.$flags=3
return k}}
A.aH.prototype={
aR(){return[this.a,this.b]},
P(a,b){if(b==null)return!1
return b instanceof A.aH&&this.$s===b.$s&&J.z(this.a,b.a)&&J.z(this.b,b.b)},
gA(a){return A.e6(this.$s,this.a,this.b,B.h)}}
A.cS.prototype={
X(){var t=this.b
if(t===this)throw A.c(new A.ac("Local '' has not been initialized."))
return t}}
A.aB.prototype={
gt(a){return B.Q},
$il:1}
A.b3.prototype={}
A.bK.prototype={
gt(a){return B.R},
$il:1}
A.aC.prototype={
gk(a){return a.length},
$iN:1}
A.b1.prototype={
h(a,b){A.at(b,a,a.length)
return a[b]},
$ie:1,
$ii:1}
A.b2.prototype={$ie:1,$ii:1}
A.bL.prototype={
gt(a){return B.S},
$il:1}
A.bM.prototype={
gt(a){return B.T},
$il:1}
A.bN.prototype={
gt(a){return B.U},
h(a,b){A.at(b,a,a.length)
return a[b]},
$il:1}
A.bO.prototype={
gt(a){return B.V},
h(a,b){A.at(b,a,a.length)
return a[b]},
$il:1}
A.bP.prototype={
gt(a){return B.W},
h(a,b){A.at(b,a,a.length)
return a[b]},
$il:1}
A.bQ.prototype={
gt(a){return B.Y},
h(a,b){A.at(b,a,a.length)
return a[b]},
$il:1}
A.bR.prototype={
gt(a){return B.Z},
h(a,b){A.at(b,a,a.length)
return a[b]},
$il:1}
A.b4.prototype={
gt(a){return B.a_},
gk(a){return a.length},
h(a,b){A.at(b,a,a.length)
return a[b]},
$il:1}
A.bS.prototype={
gt(a){return B.a0},
gk(a){return a.length},
h(a,b){A.at(b,a,a.length)
return a[b]},
$il:1}
A.bi.prototype={}
A.bj.prototype={}
A.bk.prototype={}
A.bl.prototype={}
A.W.prototype={
i(a){return A.bq(v.typeUniverse,this,a)},
K(a){return A.ep(v.typeUniverse,this,a)}}
A.c3.prototype={}
A.cZ.prototype={
j(a){return A.J(this.a,null)}}
A.c2.prototype={
j(a){return this.a}}
A.aJ.prototype={}
A.bh.prototype={
gu(a){var t=this,s=new A.aq(t,t.r,t.$ti.i("aq<1>"))
s.c=t.e
return s},
gk(a){return this.a},
I(a,b){var t
if((b&1073741823)===b){t=this.c
if(t==null)return!1
return u.g.a(t[b])!=null}else return this.bq(b)},
bq(a){var t=this.d
if(t==null)return!1
return this.au(t[B.c.gA(a)&1073741823],a)>=0},
m(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.aO(t==null?r.b=A.dx():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.aO(s==null?r.c=A.dx():s,b)}else return r.bm(b)},
bm(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.dx()
s=J.L(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.ao(a)]
else{if(q.au(r,a)>=0)return!1
r.push(q.ao(a))}return!0},
Z(a,b){var t=this
if(typeof b=="string"&&b!=="__proto__")return t.aU(t.b,b)
else if(typeof b=="number"&&(b&1073741823)===b)return t.aU(t.c,b)
else return t.bz(b)},
bz(a){var t,s,r,q,p=this.d
if(p==null)return!1
t=J.L(a)&1073741823
s=p[t]
r=this.au(s,a)
if(r<0)return!1
q=s.splice(r,1)[0]
if(0===s.length)delete p[t]
this.aX(q)
return!0},
v(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.an()}},
aO(a,b){this.$ti.c.a(b)
if(u.g.a(a[b])!=null)return!1
a[b]=this.ao(b)
return!0},
aU(a,b){var t
if(a==null)return!1
t=u.g.a(a[b])
if(t==null)return!1
this.aX(t)
delete a[b]
return!0},
an(){this.r=this.r+1&1073741823},
ao(a){var t,s=this,r=new A.c6(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.an()
return r},
aX(a){var t=this,s=a.c,r=a.b
if(s==null)t.e=r
else s.b=r
if(r==null)t.f=s
else r.c=s;--t.a
t.an()},
au(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.z(a[s].a,b))return s
return-1}}
A.c6.prototype={}
A.aq.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.c(A.M(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.i("1?").a(s.a)
t.c=s.b
return!0}},
$iZ:1}
A.cF.prototype={
$2(a,b){this.a.p(0,this.b.a(a),this.c.a(b))},
$S:9}
A.j.prototype={
gu(a){return new A.a8(a,this.gk(a),A.aj(a).i("a8<j.E>"))},
C(a,b){return this.h(a,b)},
gD(a){return this.gk(a)===0},
gaJ(a){return this.gk(a)!==0},
aC(a,b){var t,s
A.aj(a).i("u(j.E)").a(b)
t=this.gk(a)
for(s=0;s<t;++s){if(b.$1(this.h(a,s)))return!0
if(t!==this.gk(a))throw A.c(A.M(a))}return!1},
b6(a,b,c){var t=A.aj(a)
return new A.S(a,t.K(c).i("1(j.E)").a(b),t.i("@<j.E>").K(c).i("S<1,2>"))},
j(a){return A.dj(a,"[","]")},
$ie:1,
$ii:1}
A.O.prototype={
O(a,b){var t,s,r,q=A.A(this)
q.i("~(O.K,O.V)").a(b)
for(t=this.gV(),t=t.gu(t),q=q.i("O.V");t.n();){s=t.gq()
r=this.h(0,s)
b.$2(s,r==null?q.a(r):r)}},
M(a){return this.gV().I(0,a)},
gk(a){var t=this.gV()
return t.gk(t)},
gD(a){var t=this.gV()
return t.gD(t)},
j(a){return A.dr(this)},
$ia_:1}
A.cH.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.t(a)
s.a=(s.a+=t)+": "
t=A.t(b)
s.a+=t},
$S:3}
A.aD.prototype={
R(a,b){var t,s,r
this.$ti.i("e<1>").a(b)
for(t=A.fE(b,b.r,b.$ti.c),s=t.$ti.c;t.n();){r=t.d
this.m(0,r==null?s.a(r):r)}},
j(a){return A.dj(this,"{","}")},
$ie:1,
$idu:1}
A.bm.prototype={}
A.c4.prototype={
h(a,b){var t,s=this.b
if(s==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.bw(b):t}},
gk(a){return this.b==null?this.c.a:this.ae().length},
gD(a){return this.gk(0)===0},
gV(){if(this.b==null){var t=this.c
return new A.a7(t,A.A(t).i("a7<1>"))}return new A.c5(this)},
M(a){if(this.b==null)return this.c.M(a)
return Object.prototype.hasOwnProperty.call(this.a,a)},
O(a,b){var t,s,r,q,p=this
u.D.a(b)
if(p.b==null)return p.c.O(0,b)
t=p.ae()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.d2(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.c(A.M(p))}},
ae(){var t=u.d.a(this.c)
if(t==null)t=this.c=A.m(Object.keys(this.a),u.s)
return t},
bw(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.d2(this.a[a])
return this.b[a]=t}}
A.c5.prototype={
gk(a){return this.a.gk(0)},
C(a,b){var t=this.a
if(t.b==null)t=t.gV().C(0,b)
else{t=t.ae()
if(!(b>=0&&b<t.length))return A.h(t,b)
t=t[b]}return t},
gu(a){var t=this.a
if(t.b==null){t=t.gV()
t=t.gu(t)}else{t=t.ae()
t=new J.ak(t,t.length,A.D(t).i("ak<1>"))}return t},
I(a,b){return this.a.M(b)}}
A.bw.prototype={}
A.by.prototype={}
A.aZ.prototype={
j(a){var t=A.bA(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.bJ.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.cB.prototype={
bJ(a,b){var t=A.hl(a,this.gbK().a)
return t},
a2(a,b){var t=A.fD(a,this.gbL().b,null)
return t},
gbL(){return B.L},
gbK(){return B.K}}
A.cD.prototype={}
A.cC.prototype={}
A.cW.prototype={
be(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.e.ac(a,s,r)
s=r+1
p=A.C(92)
t.a+=p
p=A.C(117)
t.a+=p
p=A.C(100)
t.a+=p
p=q>>>8&15
p=A.C(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.C(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.C(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.e.ac(a,s,r)
s=r+1
p=A.C(92)
t.a+=p
switch(q){case 8:p=A.C(98)
t.a+=p
break
case 9:p=A.C(116)
t.a+=p
break
case 10:p=A.C(110)
t.a+=p
break
case 12:p=A.C(102)
t.a+=p
break
case 13:p=A.C(114)
t.a+=p
break
default:p=A.C(117)
t.a+=p
p=A.C(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.C(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.C(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.e.ac(a,s,r)
s=r+1
p=A.C(92)
t.a+=p
p=A.C(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.e.ac(a,s,n)},
am(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.c(new A.bJ(a,null))}B.a.m(t,a)},
ah(a){var t,s,r,q,p=this
if(p.bd(a))return
p.am(a)
try{t=p.b.$1(a)
if(!p.bd(t)){r=A.e0(a,null,p.gaT())
throw A.c(r)}r=p.a
if(0>=r.length)return A.h(r,-1)
r.pop()}catch(q){s=A.eN(q)
r=A.e0(a,s,p.gaT())
throw A.c(r)}},
bd(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.be(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.am(a)
r.c6(a)
t=r.a
if(0>=t.length)return A.h(t,-1)
t.pop()
return!0}else if(u.f.b(a)){r.am(a)
s=r.c7(a)
t=r.a
if(0>=t.length)return A.h(t,-1)
t.pop()
return s}else return!1},
c6(a){var t,s,r=this.c
r.a+="["
t=J.aM(a)
if(t.gaJ(a)){this.ah(t.h(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.ah(t.h(a,s))}}r.a+="]"},
c7(a){var t,s,r,q,p,o,n=this,m={}
if(a.gD(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.dq(t,null,!1,u.X)
r=m.a=0
m.b=!0
a.O(0,new A.cX(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.be(A.ah(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.h(s,o)
n.ah(s[o])}q.a+="}"
return!0}}
A.cX.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.p(t,s.a++,a)
B.a.p(t,s.a++,b)},
$S:3}
A.cV.prototype={
gaT(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.r.prototype={}
A.bs.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bA(t)
return"Assertion failed"}}
A.bd.prototype={}
A.a2.prototype={
gaq(){return"Invalid argument"+(!this.a?"(s)":"")},
gap(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+A.t(q),o=t.gaq()+r+p
if(!t.a)return o
return o+t.gap()+": "+A.bA(t.gaH())},
gaH(){return this.b}}
A.b7.prototype={
gaH(){return A.q(this.b)},
gaq(){return"RangeError"},
gap(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.t(r):""
else if(r==null)t=": Not greater than or equal to "+A.t(s)
else if(r>s)t=": Not in inclusive range "+A.t(s)+".."+A.t(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.t(s)
return t}}
A.bC.prototype={
gaH(){return A.d1(this.b)},
gaq(){return"RangeError"},
gap(){if(A.d1(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.bf.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.c0.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.bb.prototype={
j(a){return"Bad state: "+this.a}}
A.bx.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bA(t)+"."}}
A.ba.prototype={
j(a){return"Stack Overflow"},
$ir:1}
A.a3.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.e.prototype={
gk(a){var t,s=this.gu(this)
for(t=0;s.n();)++t
return t},
C(a,b){var t,s
A.ds(b,"index")
t=this.gu(this)
for(s=b;t.n();){if(s===0)return t.gq();--s}throw A.c(A.di(b,b-s,this,"index"))},
j(a){return A.fk(this,"(",")")}}
A.ao.prototype={
j(a){return"MapEntry("+A.t(this.a)+": "+A.t(this.b)+")"}}
A.b5.prototype={
gA(a){return A.p.prototype.gA.call(this,0)},
j(a){return"null"}}
A.p.prototype={$ip:1,
P(a,b){return this===b},
gA(a){return A.bU(this)},
j(a){return"Instance of '"+A.bV(this)+"'"},
gt(a){return A.hy(this)},
toString(){return this.j(this)}}
A.cP.prototype={}
A.aE.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$ifx:1}
A.cw.prototype={}
A.bz.prototype={
a_(){var t=this
return A.H(["areaMultiplier",t.a,"aspects",t.b,"angleMinDeg",t.c,"angleMaxDeg",t.d,"speedMin",t.e,"speedMax",t.f,"accelMin",t.r,"accelMax",t.w,"collideWithEachOther",t.x,"spinDegPerSec",t.y],u.N,u.z)}}
A.cb.prototype={
$1(a){return A.v(a)},
$S:10}
A.cK.prototype={
a_(){return A.H(["size",this.a,"showFace",this.b],u.N,u.z)}}
A.ch.prototype={
a_(){var t,s=this,r=A.dn(u.N,u.z)
r.p(0,"borderWidth",s.a)
r.p(0,"brightness",s.b)
r.p(0,"shadowBrightness",s.c)
t=s.d
if(t!=null&&t.length!==0)r.p(0,"color",t)
return r}}
A.ci.prototype={
a_(){var t=this
return A.H(["startHintEnabled",t.a,"idleSpeedMultiplier",t.b,"idleEnemiesMove",t.c,"speedRampSeconds",t.d,"jumpEnabled",t.e,"jumpDurationSec",t.f,"jumpCooldownSec",t.r,"jumpScale",t.w,"helmetEnabled",t.x,"helmetInvulnSec",t.y,"helmetCooldownSec",t.z,"startInvulnSec",t.Q,"heartbeatHaptic",t.as,"timerHaptic",t.at,"timerHapticStyle",t.ax,"timerHapticStyle5",t.ay,"timerHapticStyle10",t.ch,"hudSpeedScaleMax",t.CW,"wallsKillPlayer",t.cx],u.N,u.z)}}
A.ca.prototype={
a_(){return A.H(["sfxMobWall",!0,"sfxMobCollide",!0,"sfxHeroMob",!0,"sfxHeroWall",!0,"sfxNearMiss",!0,"sfxHelmet",!0,"sfxJump",!0,"sfxBrake",!0,"sfxStart",!0,"music",!0,"sfxVolume",1,"musicVolume",0.08],u.N,u.z)}}
A.cI.prototype={}
A.cd.prototype={
bk(a){var t=this,s=u.f.b(a)?a:B.M,r=new A.cf(s),q=new A.ce(s),p=A.dA(q.$1("brakeEnabled"))
t.a!==$&&A.K()
t.a=p
q=A.dA(q.$1("speedBarEnabled"))
t.b!==$&&A.K()
t.b=q
q=A.a0(r.$4("initialSpeed",0,0,150))
t.c!==$&&A.K()
t.c=q
q=A.a0(r.$4("growthMultiplier",70,0,200))
t.d!==$&&A.K()
t.d=q
q=A.a0(r.$4("growthExponent",0.2,0.01,1))
t.e!==$&&A.K()
t.e=q
q=A.a0(r.$4("startSmoothingSec",3,0.01,60))
t.f!==$&&A.K()
t.f=q
q=A.a0(r.$4("initialCompensation",1,0,10))
t.r!==$&&A.K()
t.r=q
q=A.a0(r.$4("brakeCooldownSec",6,0.1,120))
t.w!==$&&A.K()
t.w=q
q=A.a0(r.$4("brakeFirstReadySec",6,0.1,120))
t.x!==$&&A.K()
t.x=q
r=A.a0(r.$4("brakeRewindSec",6,0,120))
t.y!==$&&A.K()
t.y=r
t.as=q},
al(a){var t,s,r,q,p=this,o=p.c
o===$&&A.d()
t=p.d
t===$&&A.d()
s=Math.max(0,a)
r=p.f
r===$&&A.d()
q=p.e
q===$&&A.d()
q=Math.pow(s+r,q)
r=p.r
r===$&&A.d()
return Math.max(0,o+t*(q-r))},
gab(){var t=this
return t.al(t.Q)+t.ay*B.b.l(1-(t.z-t.at)/0.18,0,1)},
ga7(){var t=this.a
t===$&&A.d()
return t&&this.z+1e-9>=this.as},
bV(){var t,s,r=this
if(!r.ga7())return!1
r.ch=r.gab()
t=r.Q
s=r.y
s===$&&A.d()
s=Math.max(0,t-s)
r.Q=s
s=r.al(s)
r.CW=s
r.ay=Math.max(0,r.ch-s)
s=r.z
r.at=s
t=r.w
t===$&&A.d()
r.as=s+t;++r.cx
return!0},
bW(a,b,c,d,e,f){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this.a
g===$&&A.d()
if(!g||!this.ga7()||!c)return!1
t=d/2
for(g=u.t,g=[A.m([a+t,e+t],g),A.m([b+t,f+t],g)],s=190-d,r=190+d,q=0,p=1,o=0;o<2;++o){n=g[o]
if(1>=n.length)return A.h(n,1)
m=n[1]
l=n[0]
k=m-l
if(Math.abs(k)<1e-9){if(l<=s||l>=r)return!1}else{j=(s-l)/k
i=(r-l)/k
if(j>i){h=i
i=j
j=h}q=Math.max(q,j)
p=Math.min(p,i)}}return q<=p&&this.bV()}}
A.cf.prototype={
$4(a,b,c,d){var t=this.a.h(0,a)
if(t==null)t=b
if(typeof t!="number"||!isFinite(t)||t<c||t>d)throw A.c(A.R("enemy_pace_"+a))
return t},
$S:11}
A.ce.prototype={
$1(a){var t=this.a,s=!t.M(a)||t.h(0,a)
if(!A.d3(s))throw A.c(A.R("enemy_pace_"+a))
return s},
$S:12}
A.a.prototype={
H(a,b){return new A.a(this.a+b.a,this.b+b.b)},
a0(a,b){return new A.a(this.a-b.a,this.b-b.b)},
W(a,b){return new A.a(this.a*b,this.b*b)},
ai(a,b){return new A.a(this.a/b,this.b/b)},
gaZ(){var t=this.a,s=this.b
return Math.sqrt(t*t+s*s)}}
A.cO.prototype={}
A.k.prototype={
gL(){var t=this
return new A.a((t.a+t.c)/2,(t.b+t.d)/2)},
a5(a){var t=this
return t.a<a.c&&t.c>a.a&&t.b<a.d&&t.d>a.b},
b0(a){var t=this
return new A.k(t.a-a,t.b-a,t.c+a,t.d+a)}}
A.cl.prototype={
$1(a){var t,s,r,q=a.a,p=a.b
if(isFinite(q)&&isFinite(p)){s=a.c-q
r=a.d-p
r=!(isFinite(s)&&s>0&&isFinite(r)&&r>0)
s=r}else s=!0
if(s)return!1
s=this.a.b
t=A.dV(a,new A.k(0,0,0+s.a,0+s.b))
s=t
if(!(s.c-s.a<=0||s.d-s.b<=0)){s=t
r=t
p=(s.c-s.a)*(r.d-r.b)/((a.c-q)*(a.d-p))>=0.97
q=p}else q=!1
return q},
$S:13}
A.ck.prototype={
$2(a,b){return Math.min(a*this.a,b*this.b)*this.c>=8},
$S:14}
A.cj.prototype={
$1(a){A.a0(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.cx.prototype={
a3(a){var t,s=this,r=s.e
r===$&&A.d()
t=r.c
s.aM(a)
if(!t&&r.c)s.cx=s.x},
ga8(){var t,s,r,q,p=this,o=u.N,n=A.e3(A.aT.prototype.ga8.call(p),o,u.z),m=p.e
m===$&&A.d()
t=m.b
s=m.gb9()
if(m.c)r=1
else r=t>0&&m.e!=null?B.b.l(1-m.gb9()/t,0,1):0
q=p.cx
q=q==null?null:p.x-q
n.p(0,"helmetCharge",A.H(["equipped",m.a,"cooldownMs",t,"remainingMs",s,"progress",r,"readyAgeMs",q,"breaks",p.cy],o,u.X))
return n}}
A.cy.prototype={
bG(a){var t,s=this
if(!isFinite(a)||a<s.d)throw A.c(A.dN(a,"nowMs",null))
s.d=a
t=!1
if(!s.c)if(s.a){t=s.e
t=t!=null&&a>=t}if(t){s.c=!0
s.e=null
return!0}return!1},
bI(){var t,s=this
if(!s.c)return!1
s.c=!1
t=s.b
s.e=t>0?s.d+t:null
return!0},
gb9(){var t=this.e
return t==null?0:Math.max(0,t-this.d)}}
A.dc.prototype={
$1(a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=null,a5="events",a6="startPose"
A.ah(a7)
try{j=u.c
t=j.a(B.d.bJ(a7,a4))
s=J.E(t,"op")
if(J.z(s,"verify")){r=J.E(t,"proof")
k=!0
if(u.f.b(r))if(B.a.I(A.m([3,4,5],u.Y),r.h(0,"version"))){k=u.j
k=!k.b(r.h(0,a5))||J.Q(k.a(r.h(0,a5)))>6e5||!k.b(r.h(0,a6))}if(k){q=A.R("proof")
throw A.c(q)}k=u.N
j=u.z
q=A.e3(t,k,j)
J.df(q,"proofVersion",r.h(0,"version"))
J.df(q,a6,r.h(0,a6))
p=A.dW(q)
p.aL()
for(q=J.dg(u.R.a(r.h(0,a5))),i=u.j;q.n();){o=q.gq()
if(!i.b(o)||J.f0(o)){q=A.R("event")
throw A.c(q)}if(J.z(J.E(o,0),2)){if(J.Q(o)!==1){q=A.R("jump")
throw A.c(q)}n=p.ay
p.b3()
h=p.ay
g=n
if(typeof g!=="number")return g.H()
if(h!==g+1){q=A.R("jump")
throw A.c(q)}}else{if(!(J.z(J.E(o,0),0)&&J.Q(o)!==2))h=J.z(J.E(o,0),1)&&J.Q(o)!==3
else h=!0
if(h){q=A.R("event")
throw A.c(q)}h=p
g=h.e
g===$&&A.d()
f=g.c
h.aM(o)
if(!f&&g.c)h.cx=h.x}}if(!p.z){q=A.R("unfinished")
throw A.c(q)}m=p.ga8()
e=B.d.a2(A.H(["ok",!0,"timeMs",J.E(m,"timeMs"),"runDistance",J.E(m,"runDistance"),"riskCount",J.E(m,"riskCount")],k,j),a4)
return e}if(J.z(s,"rewardFrame")){q=A.v(J.E(t,"p"))
k=J.z(J.E(t,"reduced"),!0)
l=new A.cg(B.b.l(q,0,1),k)
k=l.a
q=B.b.l(l.a/0.1125,0,1)
j=l.gU()
i=l.gb_()
h=l
if(h.b)h=1
else{g=B.b.l(h.a/0.1125,0,1)-1
h=(0.82+0.18*(1+2.70158*Math.pow(g,3)+1.70158*Math.pow(g,2)))*(1-0.78*h.gb_())}g=l
d=B.b.l(g.a/0.1125,0,1)
g=B.b.l((g.gU()-0.76)/0.24,0,1)
c=l
b=c.a
c=c.b
a=c?0.5:0.8
c=c?0.5:0.2
c=Math.pow(1-B.b.l((b-a)/c,0,1),3)
a=l
b=a.b?0:Math.sin(3.141592653589793*B.b.l((a.a-0.83)/0.17,0,1))
e=B.d.a2(A.H(["ok",!0,"p",k,"appearance",q,"flight",j,"fly",i,"scale",h,"opacity",d*(1-g),"roll",1-c,"hit",b],u.N,u.K),a4)
return e}if(J.z(s,"create")){q=this.a
q.a=A.dW(t)}else{q=this.a
i=q.a
if(i==null){q=A.bY("session_missing")
throw A.c(q)}switch(s){case"idle":j=A.v(J.E(t,"ms"))
if(i.y||i.z||!isFinite(j)||j<=0||j>50)A.V(A.bY("idle"))
h=i.d
h===$&&A.d()
a0=h.c_(j/1000)
i.at=a0.a
i.ax=a0.b
break
case"start":i.aL()
break
case"tick":i.a3([0,J.E(t,"ms")])
break
case"move":j=A.v(J.E(t,"dx"))
h=A.v(J.E(t,"dy"))
if(!i.y)A.V(A.bY("move"))
if(i.x===0)i.a3([0,1])
if(!i.z)i.a3([1,j,h])
break
case"jump":i.b3()
break
case"snapshot":break
case"proof":q=i.a
q===$&&A.d()
k=u.N
e=B.d.a2(A.H(["ok",!0,"proof",A.H(["version",q,"events",i.ch,"startPose",i.CW],k,u.z)],k,u.K),a4)
return e
case"guard":q=j.a(t)
k=u.j
a1=k.a(q.h(0,"field"))
a2=k.a(q.h(0,"visible"))
i=i.d
i===$&&A.d()
k=J.a1(a1)
j=A.v(k.h(a1,0))
h=A.v(k.h(a1,1))
g=A.v(k.h(a1,2))
k=A.v(k.h(a1,3))
d=J.a1(a2)
c=A.v(d.h(a2,0))
b=A.v(d.h(a2,1))
a=A.v(d.h(a2,2))
d=A.v(d.h(a2,3))
e=B.d.a2(A.H(["ok",!0,"issue",A.ff(A.v(q.h(0,"dpr")),new A.k(j,h,j+g,h+k),B.r,new A.k(c,b,c+a,b+d),i)],u.N,u.X),a4)
return e
default:q=A.R("unknown_operation")
throw A.c(q)}}k=A.dn(u.N,u.z)
J.df(k,"ok",!0)
J.dK(k,q.a.ga8())
e=B.d.a2(k,a4)
return e}catch(a3){return'{"ok":false,"error":"invalid_kernel_operation"}'}},
$S:15}
A.bW.prototype={
bv(){var t=this.a
t^=t<<13
t^=t>>>17
return this.a=(t^t<<5)>>>0},
F(){var t=this.a
t^=t<<13
t^=t>>>17
t=(t^t<<5)>>>0
this.a=t
return t/4294967296},
bT(a){if(a<=0)throw A.c(A.dN(a,null,null))
return B.b.aG(this.bv()/4294967296*a)},
$ift:1}
A.cg.prototype={
gU(){return this.b?0:B.b.l((this.a-0.4)/0.4,0,1)},
gb_(){var t=this
return t.gU()<0.5?4*t.gU()*t.gU()*t.gU():1-Math.pow(-2*t.gU()+2,3)/2}}
A.aT.prototype={
bl(a8){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=this,a5="proofVersion",a6=null,a7="startPose"
if(J.z(a8.h(0,a5),5))t=5
else t=J.z(a8.h(0,a5),4)?4:3
a4.a!==$&&A.K()
a4.a=t
s=u.c
r=s.a(a8.h(0,"config"))
a4.b=A.fc(r.h(0,"enemyPace"))
q=A.fb(s.a(r.h(0,"enemies")))
p=s.a(r.h(0,"player"))
o=A.q(p.h(0,"size"))
if(o==null)o=a6
if(o==null){o=A.q(p.h(0,"playerSize"))
if(o==null)o=a6}if(o==null)o=36
n=A.U(p.h(0,"showFace"))
p=n==null?A.U(p.h(0,"playerShowFace")):n
n=s.a(r.h(0,"field"))
m=n.h(0,"color")
l=m==null?n.h(0,"colorHex"):m
if(l==null)l=n.h(0,"surfaceColor")
k=typeof l=="string"&&B.e.bc(l).length!==0?B.e.bc(l):a6
m=A.q(n.h(0,"borderWidth"))
if(m==null)m=a6
if(m==null)m=3
j=A.q(n.h(0,"brightness"))
if(j==null)j=a6
if(j==null){j=A.q(n.h(0,"fieldBrightness"))
if(j==null)j=a6}if(j==null)j=1
n=A.q(n.h(0,"shadowBrightness"))
if(n==null)n=a6
if(n==null)n=1
i=A.dU(s.a(r.h(0,"game")))
s=s.a(r.h(0,"mobileEnemies"))
h=s.h(0,"startSpeedSteps")
g=s.h(0,"accelerationSteps")
if(typeof h!="number"||typeof g!="number"||!isFinite(h)||!isFinite(g)||h<0.01||h>250||g<0||g>50)A.V(B.E)
f=A.e5(s.h(0,"speedVariation"),0.05)
s=A.e5(s.h(0,"accelerationVariation"),0.08)
e=o*1.2
d=Math.max(0.000001,(e===0?36:e)*0.1)
c=h*d
b=g*d
a=i.a_()
a.p(0,"speedRampSeconds",0)
i=A.dU(a)
s=new A.cw(new A.bz(q.a,q.b,q.c,q.d,c*(1-f),c*(1+f),b*(1-s),b*(1+s),q.x,q.y),new A.cK(o,p===!0),new A.ch(m,j,n,k),i,B.u,new A.cI(h,g,f,s),a6)
a4.c!==$&&A.K()
a4.c=s
f=A.fv(A.ah(a8.h(0,"requestId")))
m/=2
n=B.b.l(m+0.5,0.5,12)
j=A.dn(u.V,u.n)
p=A.m([],u.v)
o=new A.cP()
$.eP()
a0=$.e9.$0()
o.a=a0
o.b=null
a0=A.m([],u.l)
a1=u.S
a2=A.cG(a1)
a3=A.cG(a1)
a1=A.cG(a1)
t=new A.cm(s,B.r,new A.bW(f),t<4,t>=5,j,n+m,p,o,a0,a2,a3,a1)
e=(380-e)/2
t.w=new A.a(e,e)
B.a.v(a0)
a2.v(0)
a3.v(0)
a1.v(0)
j.v(0)
B.a.v(p)
B.a.R(p,t.bC())
a4.d!==$&&A.K()
a4.d=t
p=J.z(a8.h(0,"hadHelmet"),!0)
j=i.z
s=isFinite(j)&&j>0?B.b.l(j,0,3600)*1000:0
a4.e!==$&&A.K()
a4.e=new A.cy(p,s,p)
p=J.z(a8.h(0,"hadJump"),!0)
a4.f!==$&&A.K()
a4.f=p
if(a8.h(0,a7)!=null)t.bY(a8.h(0,a7))
a4.r=Math.max(0,i.Q)},
gaf(){var t=this.r
t===$&&A.d()
return t>0||this.w>0},
aL(){var t,s=this
if(s.y||s.z)throw A.c(A.bY("start"))
t=s.d
t===$&&A.d()
t.bg()
s.CW=t.gbh()
s.ax=s.at=0
s.y=!0},
bH(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
if(e.gaf())return
t=e.d
t===$&&A.d()
s=t.a.d.cx&&t.b8()
r=!s
if(r&&!t.bU())return
e.Q=s
q=t.w
q===$&&A.d()
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
i=m}}else{h=new A.k(p,q,p+o,q+o)
q=t.x
p=q.length
o=u.V
g=0
for(;;){if(!(g<q.length)){j=l
i=m
break}f=q[g]
n=t.f
if(f===A.fj(new A.a7(n,A.A(n).i("a7<1>")),o)||h.a5(f.gB())){q=f.gB()
i=(m+(q.a+q.c)/2)/2
q=f.gB()
j=(l+(q.b+q.d)/2)/2
break}q.length===p||(0,A.B)(q);++g}}e.as=A.H(["x",i,"y",j],u.N,u.i)
q=e.e
q===$&&A.d()
if(q.c){q.bI()
q=e.c
q===$&&A.d()
e.w=Math.max(0,q.d.y)
if(r)t.bX()}else{e.z=!0
e.y=!1}},
b3(){var t,s=this,r=!0
if(s.y){t=s.f
t===$&&A.d()
if(t){r=s.d
r===$&&A.d()
r=!r.c4(s.x)}}if(r)return;++s.ay
B.a.m(s.ch,A.m([2],u.a))},
a3(a){var t,s,r,q,p,o,n,m,l,k,j=this,i=j.d
i===$&&A.d()
t=i.w
t===$&&A.d()
if(!j.y||j.z||j.ch.length>=6e5)throw A.c(A.bY("event"))
s=J.a1(a)
if(J.z(s.h(a,0),0)){r=A.v(s.h(a,1))
if(!isFinite(r)||r<=0||r>50||j.x+r>36e5)throw A.c(A.R("tick"))
B.a.m(j.ch,A.m([0,r],u.a))
s=j.x+=r
q=j.e
q===$&&A.d()
q.bG(s)
p=r/1000
s=j.b
if(s!=null){s.z+=p
s.Q+=p}i.c0(p)
s=j.x
q=j.gaf()
o=j.b
o=o==null?null:o.gab()*(i.a.b.a*1.2)*0.1
n=i.c1(p,s/1000,!q,o)
j.at=n.a
j.ax=n.b
o=j.r
o===$&&A.d()
j.r=Math.max(0,o-p)
j.w=Math.max(0,j.w-p)}else if(J.z(s.h(a,0),1)){m=A.v(s.h(a,1))
l=A.v(s.h(a,2))
if(!isFinite(m)||!isFinite(l)||Math.abs(m)>2000||Math.abs(l)>2000)throw A.c(A.R("move"))
B.a.m(j.ch,A.m([1,m,l],u.a))
i.bR(new A.a(m,l),!j.gaf())}else throw A.c(A.R("event"))
if(!i.a.d.cx&&i.b8())i.aY()
s=j.e
s===$&&A.d()
k=s.c
j.bi()
if(k&&!s.c){++j.cy
j.cx=null}if(!j.z){s=j.b
if(s!=null){q=i.w
q===$&&A.d()
s.bW(t.a,t.b,!(i.y>0),i.a.b.a*1.2,q.a,q.b)}}},
ga8(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=this,a8=a7.b
if(a8==null)a8=null
else{t=a8.a
t===$&&A.d()
s=a8.b
s===$&&A.d()
r=a8.Q
q=a8.gab()
p=a8.al(a8.Q)
if(!t)o=0
else if(a8.ga7())o=1
else{o=a8.z
n=a8.cx===0
m=n?0:a8.at
if(n){n=a8.x
n===$&&A.d()}else{n=a8.w
n===$&&A.d()}n=B.b.l((o-m)/n,0,1)
o=n}n=a8.ga7()
m=a8.cx
l=m===0?-1:(a8.z-a8.at)*1000
k=a8.ga7()?(a8.z-a8.as)*1000:-1
a8=A.H(["enabled",t,"speedBarEnabled",s,"effectiveSec",r,"speed",q,"targetSpeed",p,"charge",o,"ready",n,"presses",m,"pressAgeMs",l,"readyAgeMs",k,"beforeSpeed",a8.ch,"afterSpeed",a8.CW],u.N,u.z)}t=a7.y
s=a7.z
r=B.b.aG(a7.x)
q=a7.d
q===$&&A.d()
p=B.b.bZ(Math.max(0,q.as/Math.max(0.000001,q.a.b.a*1.2*0.1)))
o=q.at
n=a7.e
n===$&&A.d()
n=n.c
m=a7.gaf()
l=q.b4(a7.x)
k=a7.ay
j=a7.f
j===$&&A.d()
if(j){j=a7.c
j===$&&A.d()
j=j.d.e}else j=!1
i=q.y
h=q.w
h===$&&A.d()
g=u.N
f=u.i
h=A.H(["x",h.a,"y",h.b,"size",q.a.b.a*1.2,"visualScale",q.gc5(),"jumpLift",q.gb5()],g,f)
e=u.O
d=A.m([],e)
for(c=q.x,b=c.length,a=0;a<c.length;c.length===b||(0,A.B)(c),++a){a0=c[a]
a1=a0.a
a2=a0.CW
a3=a7.b
a3=a3==null?a0.ay+a0.ch*(a7.x/1000):a3.gab()*(q.a.b.a*1.2)*0.1
d.push(A.H(["x",a1.a,"y",a1.b,"w",a0.y,"h",a0.z,"angle",a2,"speed",a3],g,f))}c=a7.at
b=a7.ax
a1=a7.Q
a2=a7.as
a3=q.gbM()
e=A.m([],e)
for(q=q.ax,a4=q.length,a=0;a<q.length;q.length===a4||(0,A.B)(q),++a){a5=q[a]
a6=a5.a
e.push(A.H(["x",a6.a,"y",a6.b,"age",a5.b],g,f))}return A.H(["brake",a8,"playing",t,"dead",s,"timeMs",r,"runDistance",p,"riskCount",o,"helmet",n,"invulnerable",m,"jumpCooldownMs",l,"jumpCount",k,"jumpEnabled",j,"jumpRemainingMs",i*1000,"player",h,"enemies",d,"wallBounces",c,"enemyBounces",b,"againstWall",a1,"impactOrigin",a2,"startled",a3,"nearMissFx",e],g,u.z)}}
A.ax.prototype={}
A.ae.prototype={}
A.al.prototype={
gL(){var t=this.a
return new A.a(t.a+this.y*0.5,t.b+this.z*0.5)},
bf(a){this.a=new A.a(a.a-this.y*0.5,a.b-this.z*0.5)},
gS(){var t=this.CW*3.141592653589793/180
return new A.a(Math.cos(t),Math.sin(t))},
gT(){var t=this.CW*3.141592653589793/180
return new A.a(-Math.sin(t),Math.cos(t))},
gaF(){var t=this,s=t.y*0.5,r=t.z*0.5,q=new A.cc(t.gL(),t.gS(),t.gT()),p=-s,o=-r
return A.m([q.$2(p,o),q.$2(s,o),q.$2(s,r),q.$2(p,r)],u.L)},
gB(){var t,s,r,q,p=this.gaF(),o=B.a.gN(p).a,n=B.a.gN(p).a,m=B.a.gN(p).b,l=B.a.gN(p).b
for(t=0;t<4;++t){s=p[t]
r=s.a
if(r<o)o=r
if(r>n)n=r
q=s.b
if(q<m)m=q
if(q>l)l=q}return new A.k(o,m,n,l)},
a6(a){var t=this,s=t.gL(),r=t.gS(),q=t.gT(),p=a.a,o=a.b,n=s.a*p+s.b*o,m=t.y*0.5*Math.abs(p*r.a+o*r.b)+t.z*0.5*Math.abs(p*q.a+o*q.b)
return new A.aI(n-m,n+m)},
aa(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=a.b0(b)
for(t=[B.f,B.i,this.gS(),this.gT()],s=c.a,r=c.c,q=(s+r)/2,p=c.b,o=c.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,m=1/0,l=null,k=0;k<4;++k){j=t[k]
i=this.a6(j)
r=j.a
o=j.b
h=q*r+n*o
g=s*Math.abs(r)+p*Math.abs(o)
f=h+g-i.a
e=i.b-h+g
if(f<=0||e<=0)return null
d=Math.min(f,e)
if(d<m){l=f<e?j:new A.a(-r,-o)
m=d}}return l==null?null:l.W(0,m+0.000001)},
a9(a){return this.aa(a,2.5)},
J(a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
for(t=[B.f,B.i,this.gS(),this.gT()],s=a1.a,r=a1.c,q=(s+r)/2,p=a1.b,o=a1.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,o=a2.a,r=a2.b,m=0,l=1,k=0;k<4;++k){j=t[k]
i=this.a6(j)
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
b7(a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[B.f,B.i,b.gS(),b.gT()],a0=a3.gL(),a1=(a3.c-a3.a)*0.5,a2=(a3.d-a3.b)*0.5
for(t=a0.a,s=a0.b,r=b.y*0.5,q=b.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.a(l,k)
g=b.a6(h)
f=t*l+s*k
e=a1*Math.abs(l)+a2*Math.abs(k)
d=Math.min(g.b,f+e)-Math.max(g.a,f-e)
if(d<=0)return null
if(d<p){c=b.a
o=(c.a+r-t)*l+(c.b+q-s)*k>=0?h:new A.a(-l,-k)
p=d}}if(o==null)return null
return o.W(0,p+0.5)},
bS(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[b.gS(),b.gT(),a0.gS(),a0.gT()]
for(t=b.y*0.5,s=a0.y*0.5,r=b.z*0.5,q=a0.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.a(l,k)
g=b.a6(h)
f=a0.a6(h)
e=Math.min(g.b,f.b)-Math.max(g.a,f.a)
if(e<=0)return null
if(e<p){d=b.a
c=a0.a
o=(d.a+t-(c.a+s))*l+(d.b+r-(c.b+q))*k>=0?h:new A.a(-l,-k)
p=e}}if(o==null)return null
return o.W(0,p+0.5)},
G(a){var t,s,r,q,p,o=a.a,n=a.b,m=o*o+n*n
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
this.b=new A.a(n-p*s,o-p*r)}}
A.cc.prototype={
$2(a,b){var t=this.a,s=this.b,r=this.c
return new A.a(t.a+s.a*a+r.a*b,t.b+s.b*a+r.b*b)},
$S:16}
A.cm.prototype={
gaA(){var t,s,r=this.w
r===$&&A.d()
t=r.a
r=r.b
s=this.a.b.a*1.2
return new A.k(t,r,t+s,r+s)},
by(a,b){var t,s=this
s.f.p(0,a,b)
t=B.a.a4(s.x,a)
s.ay.Z(0,t)
s.CW.m(0,t)},
b4(a){var t=this.Q
return Math.max(0,t-a)},
gbM(){var t,s,r=this.w
r===$&&A.d()
t=r.a
r=r.b
s=this.a.b.a*1.2
return B.a.aC(this.x,new A.ct(new A.k(t,r,t+s,r+s)))},
gb5(){var t=this.y
if(!(t>0))return 0
return Math.sin(3.141592653589793*B.b.l(1-t/Math.max(0.05,this.a.d.f),0,1))},
gc5(){if(!(this.y>0))return 1
return 1+(B.b.l(this.a.d.w,1.05,1.8)-1)*this.gb5()},
c4(a){var t,s,r=this
if(!isFinite(a)||!r.a.d.e||r.y>0||r.b4(a)>0)return!1
t=r.a.d
r.y=Math.max(0.12,t.f)
s=t.r
t=isFinite(s)?s:2
r.Q=a+Math.max(0,t)*1000
r.ch.v(0)
r.ay.v(0)
if(r.d)r.ar()
else r.ad()
return!0},
c0(a){var t,s,r=this
if(r.y<=0)return
t=r.d
if(!t)r.ad()
s=Math.max(0,r.y-a)
r.y=s
if(s>0){if(t)r.ar()}else r.ch.v(0)},
bC(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=a9.a,b1=b0.a,b2=A.e4(b1.b,!0,u.i),b3=A.D(b2),b4=b3.i("ap<1>"),b5=A.dp(new A.ap(b2,b3.i("u(1)").a(new A.cs()),b4),b4.i("e.E"))
if(b5.length===0)B.a.R(b5,B.p)
t=b5.length
s=Math.max(t,4)
b2=u.S
b3=J.dk(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.ak(r,4)
b4=a9.c
B.a.aK(b3,b4)
q=A.ec(b3,0,A.eC(t,"count",b2),A.D(b3).c).bb(0)
b3=J.dk(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.ak(r,4)
B.a.aK(b3,b4)
p=A.ec(b3,0,A.eC(t,"count",b2),A.D(b3).c).bb(0)
o=A.m([],u.v)
for(b2=b1.e,b3=b1.f,n=b1.r,m=b1.w,l=b1.y,b0=b0.b.a*1.2,b0*=b0,k=b1.a,j=b1.c,b1=b1.d,r=0;r<t;++r){if(!(r<b5.length))return A.h(b5,r)
i=b5[r]
if(!(r<q.length))return A.h(q,r)
h=q[r]
if(!(r<p.length))return A.h(p,r)
g=p[r]
f=Math.max(1,b0)*B.b.l(k,0.2,20)
e=B.b.l(i,0.05,50)
d=Math.sqrt(f/e)
c=Math.sqrt(f*e)
b=a9.bx(g,d,c)
a=Math.min(j,b1)
a0=Math.max(j,b1)
a1=a+b4.F()*(a0-a)+90*h
a2=(a1>=360?a1-360:a1)*3.141592653589793/180
a3=Math.min(b2,b3)
a4=Math.max(b2,b3)
a5=a3+b4.F()*(a4-a3)
a3=Math.min(n,m)
a4=Math.max(n,m)
i=b4.F()
h=Math.cos(a2)
g=Math.sin(a2)
a6=Math.abs(l)>0.01
a7=a6?b4.F()*360:0
a8=new A.al(b,new A.a(h*a5,g*a5),c,d,a5,a3+i*(a4-a3),a7,l)
if(a6)a9.az(a8)
a8.c=a8.a
a8.d=a8.b
a8.w=b4.F()*3.141592653589793*2
a8.x=b4.F()*3.141592653589793*2
a8.f=1.15+b4.F()*0.85
a8.r=0.85+b4.F()*0.85
B.a.m(o,a8)}return o},
c_(a){var t,s,r,q,p,o,n,m,l,k,j,i=this,h=B.b.l(a,0,0.05),g=i.a,f=g.d
if(!f.c)return i.bE(h)
t=B.b.l(f.b,0.05,1)
for(f=i.x,s=f.length,r=0,q=0;q<f.length;f.length===s||(0,A.B)(f),++q){p=f[q]
o=B.b.l(p.ay*t,0,2000)
n=p.b
m=n.a
n=n.b
l=Math.sqrt(m*m+n*n)
if(l<0.000001)k=B.j
else{n=p.b
k=new A.a(n.a/l,n.b/l)}n=k.a*o
m=k.b*o
p.b=new A.a(n,m)
j=p.a
p.a=new A.a(j.a+n*h,j.b+m*h)
n=p.cx
if(Math.abs(n)>0.01)p.CW=p.CW+n*h
if(i.a1(p))++r}return new A.ax(r,g.a.x?i.aB():0)},
bg(){var t,s,r,q,p,o,n,m
for(t=this.x,s=t.length,r=0;r<t.length;t.length===s||(0,A.B)(t),++r){q=t[r]
p=q.b
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.b
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
m=new A.a(o/n,p/n)}else{p=q.d
p===$&&A.d()
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.d
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
n=new A.a(o/n,p/n)
m=n}else m=B.f}p=q.ay
q.b=new A.a(m.a*p,m.b*p)}},
gbh(){var t,s,r,q,p,o,n,m=A.m([],u.q)
for(t=this.x,s=t.length,r=u.t,q=0;q<t.length;t.length===s||(0,A.B)(t),++q){p=t[q]
o=p.a
n=p.b
m.push(A.m([o.a,o.b,n.a,n.b,p.CW],r))}return m},
bY(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=u.j
if(!f.b(a)||J.Q(a)!==this.x.length)throw A.c(B.D)
for(t=this.x,s=J.a1(a),r=this.b,q=r.a+0.0001,r=r.b+0.0001,p=0;p<t.length;++p){o=s.h(a,p)
if(f.b(o)){n=J.aM(o)
n=n.gk(o)!==5||n.aC(o,new A.cu())}else n=!0
if(n)throw A.c(B.C)
if(!(p<t.length))return A.h(t,p)
m=t[p]
n=J.a1(o)
l=A.v(n.h(o,0))
k=A.v(n.h(o,1))
j=A.v(n.h(o,2))
i=A.v(n.h(o,3))
h=A.v(n.h(o,4))
n=m.ay
if(Math.abs(Math.sqrt(j*j+i*i)-n)>Math.max(0.0001,n*0.000001)||Math.abs(h)>1e9)throw A.c(B.G)
m.a=new A.a(l,k)
m.b=new A.a(j,i)
m.CW=h
g=m.gB()
if(g.a<-0.0001||g.b<-0.0001||g.c>q||g.d>r)throw A.c(B.F)}},
bE(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.x,s=t.length,r=0;r<t.length;t.length===s||(0,A.B)(t),++r){q=t[r]
q.e+=a
p=Math.min(q.y,q.z)*0.5
o=q.d
o===$&&A.d()
n=o.a
o=o.b
m=Math.sqrt(n*n+o*o)
if(m<0.000001)l=B.f
else{o=q.d
l=new A.a(o.a/m,o.b/m)}o=l.b
n=l.a
k=Math.cos(q.e*q.f+q.w)*p
j=Math.sin(q.e*q.r+q.x)*p*0.35
i=n*k+-o*j
n=o*k+n*j
h=new A.a(i,n)
o=i*i+n*n
if(Math.sqrt(o)>p&&Math.sqrt(o)>0.000001){o=p/Math.sqrt(o)
h=new A.a(i*o,n*o)}o=q.c
o===$&&A.d()
q.a=new A.a(o.a+h.a,o.b+h.b)
o=q.cx
if(Math.abs(o)>0.01)q.CW=q.CW+o*a*0.35
this.az(q)}return B.t},
az(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.r,s=this.b,r=s.a-t,q=s.b-t,p=0;p<3;++p){o=a.gaF()
s=A.D(o)
n=s.i("f(1)")
s=s.i("S<1,f>")
m=new A.S(o,n.a(new A.cn()),s).ag(0,B.l)
l=new A.S(o,n.a(new A.co()),s).ag(0,B.m)
k=new A.S(o,n.a(new A.cp()),s).ag(0,B.l)
j=new A.S(o,n.a(new A.cq()),s).ag(0,B.m)
if(m<t)i=t-m
else i=l>r?r-l:0
if(k<t)h=t-k
else h=j>q?q-j:0
if(i===0&&h===0)break
s=a.a
a.a=new A.a(s.a+i,s.b+h)}},
c1(b0,b1,b2,b3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this
if(a9.e)return a9.bF(b0,b1,b2,b3,1)
t=B.b.l(b0,0,0.05)
s=B.c.l(1,0,2)
r=B.b.l(b1,0,3600)
for(q=a9.x,p=q.length,o=!a9.d,n=!b2,m=a9.a,l=m.b.a*1.2,k=a9.CW,j=b3==null,i=0,h=0;h<q.length;q.length===p||(0,A.B)(q),++h){g=q[h]
f=B.b.l((j?g.ay+g.ch*r:b3)*s,0,4000)
e=g.b
d=e.a
e=e.b
c=Math.sqrt(d*d+e*e)
if(c<0.000001)b=B.j
else{e=g.b
b=new A.a(e.a/c,e.b/c)}g.b=new A.a(b.a*f,b.b*f)
e=g.cx
d=Math.abs(e)
a=Math.max(1,B.b.aD(d*t/5))
for(d=d>0.01,a0=t/a,e=e*t/a,a1=0;a1<a;++a1){a2=g.b
a3=a2.a*a0
a2=a2.b*a0
if(d)g.CW+=e
a4=!1
if(o)if(!(a9.y>0))if(n){a4=a9.w
a4===$&&A.d()
a5=a4.a
a4=a4.b
a4=g.J(new A.k(a5,a4,a5+l,a4+l),new A.a(-a3,-a2))!=null}if(a4)k.m(0,B.a.a4(q,g))
if(b2&&!(a9.y>0)){a4=a9.w
a4===$&&A.d()
a5=a4.a
a4=a4.b
a6=g.J(new A.k(a5,a4,a5+l,a4+l),new A.a(-a3,-a2))}else a6=null
a4=g.a
a5=a6==null
if(a5)a7=1
else a7=a6===0?0:Math.min(1,a6+1e-7)
g.a=new A.a(a4.a+a3*a7,a4.b+a2*a7)
if(a9.a1(g))++i
if(!a5)break}}a8=m.a.x?a9.aB():0
a9.ba(t)
return new A.ax(i,a8)},
bp(a){var t=a.aa(this.gaA(),2.501)
return t==null?a.gL().a0(0,this.gaA().gL()):t},
Y(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
if(e.y>0)return!0
for(t=e.x,s=e.f,r=e.ay,q=e.CW,p=e.a.b.a*1.2,o=0;o<24;++o){for(n=t.length,m=!1,l=0;l<t.length;t.length===n||(0,A.B)(t),++l){k=t[l]
j=e.w
j===$&&A.d()
i=j.a
j=j.b
h=k.a9(new A.k(i,j,i+p,j+p))
if(h==null)continue
s.p(0,k,h)
g=B.a.a4(t,k)
r.Z(0,g)
q.m(0,g)
j=k.a
k.a=new A.a(j.a+h.a,j.b+h.b)
e.az(k)
j=e.w
i=j.a
j=j.b
f=k.a9(new A.k(i,j,i+p,j+p))
if(f!=null){j=e.w
e.w=new A.a(j.a-f.a,j.b-f.b)
e.aY()}m=!0}if(!m)return!0}return B.a.bN(t,new A.cr(e))},
bu(a4,a5){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=this
a3.Y()
if(!a5){for(t=a3.x,s=t.length,r=a3.a.b.a*1.2,q=1,p=null,o=0;o<t.length;t.length===s||(0,A.B)(t),++o){n=t[o]
m=a3.w
m===$&&A.d()
l=m.a
m=m.b
k=n.J(new A.k(l-2.5,m-2.5,l+r+2.5,m+r+2.5),a4)
if(k!=null&&k<=q){q=Math.max(0,k-1e-7)
p=n}}t=a3.w
t===$&&A.d()
a3.w=t.H(0,a4.W(0,q))
if(p!=null)a3.by(p,a3.bp(p))
return}t=a3.a.b.a*1.2
j=Math.min(8,t/4)
for(s=a3.x,r=s.length,o=0;o<r;++o){n=s[o]
j=Math.min(j,Math.min(n.y,n.z)/4)}i=Math.max(1,B.b.aD(a4.gaZ()/Math.max(0.25,j)))
h=a4.ai(0,i)
for(r=h.a,m=h.b,l=u.L,g=0;g<i;++g){f=a3.w
f===$&&A.d()
e=A.m([],l)
for(d=s.length,o=0;c=s.length,o<c;s.length===d||(0,A.B)(s),++o)e.push(s[o].a)
for(b=null,q=1,o=0;o<s.length;s.length===c||(0,A.B)(s),++o){n=s[o]
d=a3.w
a=d.a
d=d.b
k=n.J(new A.k(a-2.5,d-2.5,a+t+2.5,d+t+2.5),h)
if(k!=null&&k<=q){q=k
b=n}}d=a3.w
c=d.a+r
d=d.b+m
a3.w=new A.a(c,d)
if(b!=null&&b.a9(new A.k(c,d,c+t,d+t))==null){l=Math.max(0,q-1e-7)
e=f.a+r*l
l=f.b+m*l
a3.w=new A.a(e,l)
l=b.aa(new A.k(e,l,e+t,l+t),2.501)
if(l==null){r=b.a
m=b.y
l=b.z
f=a3.w
e=f.a
f=f.b
f=new A.a(r.a+m*0.5-(e+(e+t))/2,r.b+l*0.5-(f+(f+t))/2)
t=f}else t=l
a3.f.p(0,b,t)
a0=B.a.a4(s,b)
a3.ay.Z(0,a0)
a3.CW.m(0,a0)
break}if(!a3.Y()){a3.w=f
for(a1=0;a1<s.length;++a1){t=s[a1]
if(!(a1<e.length))return A.h(e,a1)
t.a=e[a1]}break}e=a3.w
d=e.a-f.a
f=e.b-f.b
if(Math.sqrt(d*d+f*f)<1e-7)break}for(t=a3.f,t=new A.a6(t,A.A(t).i("a6<1,2>")).gu(0);t.n();){a2=t.d
a2.a.G(a2.b)}},
bF(b6,b7,b8,b9,c0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4=this,b5=b4.f
b5.v(0)
t=B.b.l(b6,0,0.05)
s=B.c.l(c0,0,2)
r=B.b.l(b7,0,3600)
b4.Y()
q=b4.w
q===$&&A.d()
p=A.m([],u.W)
for(o=b4.x,n=o.length,m=0;l=o.length,m<l;o.length===n||(0,A.B)(o),++m){k=o[m]
p.push(new A.aI(k.a,k.CW))}for(n=b4.a,j=n.b.a*1.2,i=b4.ay,h=b4.CW,g=b9==null,f=0,m=0;m<o.length;o.length===l||(0,A.B)(o),++m){e=o[m]
d=B.b.l((g?e.ay+e.ch*r:b9)*s,0,4000)
c=e.b
b=c.a
c=c.b
a=Math.sqrt(b*b+c*c)
if(a<0.000001)c=B.j
else{c=e.b
c=new A.a(c.a/a,c.b/a)}e.b=new A.a(c.a*d,c.b*d)
c=e.cx
b=Math.abs(c)
a0=Math.max(1,B.b.aD(b*t/5))
for(b=b>0.01,a1=t/a0,c=c*t/a0,a2=e.y*0.5,a3=e.z*0.5,a4=0;a4<a0;++a4){a5=e.b
a6=a5.a*a1
a5=a5.b*a1
if(b)e.CW+=c
if(b4.y>0)a7=null
else{a8=b4.w
a9=a8.a
a8=a8.b
a7=e.J(new A.k(a9-2.5,a8-2.5,a9+j+2.5,a8+j+2.5),new A.a(-a6,-a5))}a8=e.a
a9=a7==null
b0=a9?1:Math.max(0,a7-1e-7)
e.a=new A.a(a8.a+a6*b0,a8.b+a5*b0)
a5=!a9
if(a5){a6=b4.w
a8=a6.a
a6=a6.b
a6=e.aa(new A.k(a8,a6,a8+j,a6+j),2.501)
if(a6==null){a6=e.a
a8=b4.w
a9=a8.a
a8=a8.b
a8=new A.a(a6.a+a2-(a9+(a9+j))/2,a6.b+a3-(a8+(a8+j))/2)
a6=a8}b5.p(0,e,a6)
b1=B.a.a4(o,e)
i.Z(0,b1)
h.m(0,b1)}if(b4.a1(e))++f
b4.Y()
if(a5)break}}b2=n.a.x?b4.aB():0
if(!b4.Y()){b4.w=q
for(a4=0;a4<o.length;++a4){q=o[a4]
n=p.length
if(!(a4<n))return A.h(p,a4)
l=p[a4]
q.a=l.a
if(!(a4<n))return A.h(p,a4)
q.CW=l.b}}if(!b8)for(b5=new A.a6(b5,A.A(b5).i("a6<1,2>")).gu(0);b5.n();){b3=b5.d
b3.a.G(b3.b)}b4.ba(t)
return new A.ax(f,b2)},
bR(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=a.a,e=!0
if(isFinite(f)){t=a.b
if(isFinite(t))f=f===0&&t===0
else f=e}else f=e
if(f)return
f=g.w
f===$&&A.d()
e=g.e
if(e)g.f.v(0)
s=g.w.H(0,a)
t=g.a
if(!t.d.cx){r=g.r
q=g.b
p=t.b.a*1.2
s=new A.a(B.b.l(s.a,r,Math.max(r,q.a-r-p)),B.b.l(s.b,r,Math.max(r,q.b-r-p)))}o=s.a0(0,f)
r=g.w
q=r.a
r=r.b
t=t.b.a*1.2
n=new A.k(q,r,q+t,r+t)
if(e&&!(g.y>0))g.bu(o,!b)
else{m=1
if(b&&!(g.y>0))for(e=g.x,t=e.length,l=0;l<e.length;e.length===t||(0,A.B)(e),++l){k=e[l].J(n,o)
if(k!=null){r=k===0?0:k+1e-7
m=Math.min(m,r)}}g.w=f.H(0,o.W(0,Math.min(1,m)))}j=g.w.a0(0,f).gaZ()
if(j===0)return
g.as+=j
if(g.y>0)if(g.d){for(f=g.x,i=0;i<f.length;++i)if(f[i].J(n,o)!=null)g.aP(i)}else g.ad()
else{if(!g.d)for(e=g.x,t=f.a,f=f.b,r=g.ay,q=g.CW,i=0;i<e.length;++i){p=e[i]
h=g.w
if(p.J(n,new A.a(h.a-t,h.b-f))!=null){r.Z(0,i)
q.m(0,i)}}g.aQ()}},
ba(a){var t=this,s=t.ax,r=A.D(s).i("u(1)").a(new A.cv(a))
s.$flags&1&&A.aO(s,16)
B.a.bA(s,r,!0)
if(t.y>0)if(t.d)t.ar()
else t.ad()
else t.aQ()},
ad(){var t,s,r,q,p,o=this
o.ay.v(0)
t=o.w
t===$&&A.d()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.k(s,t,s+r,t+r)
for(t=o.x,s=o.CW,p=0;p<t.length;++p)if(A.dh(q,t[p].gB())<22)s.m(0,p)},
ar(){var t,s,r,q,p,o=this
if(!(o.y>0))return
t=o.w
t===$&&A.d()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.k(s,t,s+r,t+r)
for(t=o.x,s=o.ch,p=0;p<t.length;++p){if(s.I(0,p))continue
if(!(p<t.length))return A.h(t,p)
if(!q.a5(t[p].gB()))continue
o.aP(p)}},
aP(a){var t,s,r,q=this
if(!q.ch.m(0,a))return;++q.at
t=q.w
t===$&&A.d()
s=q.a.b.a*1.2/2
r=t.H(0,new A.a(s,s))
s=q.x
if(!(a<s.length))return A.h(s,a)
B.a.m(q.ax,new A.ae(r.H(0,s[a].gB().gL()).ai(0,2)))},
aQ(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this
if(g.y>0)return
t=g.w
t===$&&A.d()
s=t.a
t=t.b
r=g.a.b.a*1.2
q=s+r
r=t+r
p=new A.k(s,t,q,r)
o=A.cG(u.S)
for(n=g.x,m=g.ay,l=!g.d,k=g.CW,q=(s+q)/2,r=(t+r)/2,t=g.ax,j=0;j<n.length;++j){i=A.dh(p,n[j].gB())
if(l&&k.I(0,j)){if(i>=22)k.Z(0,j)
continue}if(i<=0)continue
if(i<=14){m.m(0,j)
o.m(0,j)}else if(i>=22&&m.I(0,j)){++g.at
if(!(j<n.length))return A.h(n,j)
s=n[j].gB()
if(!(j<n.length))return A.h(n,j)
h=n[j].gB()
B.a.m(t,new A.ae(new A.a((q+(s.a+s.c)/2)/2,(r+(h.b+h.d)/2)/2)))}else if(m.I(0,j))o.m(0,j)}m.v(0)
m.R(0,o)},
aY(){var t=this,s=t.a.b.a*1.2,r=t.r,q=t.b,p=Math.max(r,q.a-r-s),o=Math.max(r,q.b-r-s)
q=t.w
q===$&&A.d()
t.w=new A.a(B.b.l(q.a,r,p),B.b.l(t.w.b,r,o))},
b8(){var t,s,r,q,p=this,o=p.w
o===$&&A.d()
t=o.a
s=p.r
r=!0
if(!(t<=s)){o=o.b
if(!(o<=s)){r=p.a.b.a*1.2
q=p.b
o=t+r>=q.a-s||o+r>=q.b-s}else o=r}else o=r
return o},
bU(){var t,s,r,q,p,o=this
if(o.y>0)return!1
if(o.e&&o.f.a!==0)return!0
t=o.w
t===$&&A.d()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.k(s,t,s+r,t+r)
for(t=o.x,s=t.length,p=0;p<t.length;t.length===s||(0,A.B)(t),++p)if(t[p].b7(q)!=null)return!0
return!1},
bX(){var t,s,r,q,p,o,n,m,l,k,j=this
if(j.e){j.Y()
t=j.f
s=A.fq(t,u.V,u.n)
for(r=new A.a6(s,A.A(s).i("a6<1,2>")).gu(0);r.n();){q=r.d
q.a.G(q.b)}t.v(0)
return s.a}t=j.w
t===$&&A.d()
r=t.a
t=t.b
p=j.a.b.a*1.2
o=new A.k(r,t,r+p,t+p)
for(t=j.x,r=t.length,n=0,m=0;m<t.length;t.length===r||(0,A.B)(t),++m){l=t[m]
k=l.b7(o)
if(k==null)continue
p=l.a
l.a=new A.a(p.a+k.a,p.b+k.b)
l.G(k);++n}return n},
bx(a0,a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this,d=Math.max(8,e.r+2),c=e.b,b=c.a,a=b/2
c=c.b
t=c/2
s=A.cT()
r=A.cT()
q=A.cT()
p=A.cT()
switch(B.c.ak(a0,4)){case 0:s.b=d
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
p.b=c-a1-d}o=r.X()
n=s.X()
if(typeof o!=="number")return o.aj()
if(typeof n!=="number")return A.d7(n)
if(o<n){s.b=d
r.b=Math.max(d,b-a2-d)}o=p.X()
n=q.X()
if(typeof o!=="number")return o.aj()
if(typeof n!=="number")return A.d7(n)
if(o<n){q.b=d
p.b=Math.max(d,c-a1-d)}o=e.w
o===$&&A.d()
n=o.a
o=o.b
m=e.a.b.a*1.2
l=new A.k(n,o,n+m,o+m).b0(m*0.6)
for(o=e.c,k=0;k<12;++k){n=s.b
if(n===s)A.V(A.b_(""))
m=o.F()
j=r.b
if(j===r)A.V(A.b_(""))
i=s.b
if(i===s)A.V(A.b_(""))
if(typeof j!=="number")return j.a0()
if(typeof i!=="number")return A.d7(i)
j=Math.max(1,j-i)
if(typeof n!=="number")return n.H()
h=n+m*j
n=q.b
if(n===q)A.V(A.b_(""))
m=o.F()
j=p.b
if(j===p)A.V(A.b_(""))
i=q.b
if(i===q)A.V(A.b_(""))
if(typeof j!=="number")return j.a0()
if(typeof i!=="number")return A.d7(i)
j=Math.max(1,j-i)
if(typeof n!=="number")return n.H()
g=n+m*j
f=new A.a(h,g)
if(!new A.k(h,g,h+a2,g+a1).a5(l))return f}return new A.a(J.dL(s.X(),d,b-a2-d),J.dL(q.X(),d,c-a1-d))},
a1(a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=a2.gL()
for(t=this.r,s=this.b,r=s.a-t,q=s.b-t,s=a2.y*0.5,p=a2.z*0.5,o=!1,n=0;n<3;++n){m=a1.a
l=a1.b
a2.a=new A.a(m-s,l-p)
k=a2.gaF()
j=B.a.gN(k).a
i=B.a.gN(k).a
h=B.a.gN(k).b
g=B.a.gN(k).b
for(f=0;f<4;++f){e=k[f]
d=e.a
if(d<j)j=d
if(d>i)i=d
c=e.b
if(c<h)h=c
if(c>g)g=c}b=!0
if(j<t){a=t-j
a2.G(B.f)
o=b}else if(i>r){a=r-i
a2.G(B.P)
o=b}else a=0
if(h<t){a0=t-h
a2.G(B.i)
o=b}else if(g>q){a0=q-g
a2.G(B.O)
o=b}else a0=0
if(a===0&&a0===0)break
a1=new A.a(m+a,l+a0)}a2.bf(a1)
return o},
aB(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f
for(t=this.x,s=0,r=0;r<t.length;r=q)for(q=r+1,p=q;o=t.length,p<o;++p){if(!(r<o))return A.h(t,r)
n=t[r]
m=t[p]
if(!n.gB().a5(m.gB()))continue
l=n.bS(m)
if(l==null)continue;++s
o=l.a
k=o*0.5
j=l.b
i=j*0.5
h=n.a
g=n.y*0.5
f=n.z*0.5
n.a=new A.a(h.a+g+k-g,h.b+f+i-f)
f=m.a
h=m.y*0.5
g=m.z*0.5
m.a=new A.a(f.a+h-k-h,f.b+g-i-g)
n.G(l)
m.G(new A.a(-o,-j))
this.a1(n)
this.a1(m)}return s}}
A.ct.prototype={
$1(a){return A.dh(this.a,u.V.a(a).gB())<=14},
$S:5}
A.cs.prototype={
$1(a){A.a0(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.cu.prototype={
$1(a){return typeof a!="number"||!isFinite(a)},
$S:17}
A.cn.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.co.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.cp.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cq.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cr.prototype={
$1(a){return u.V.a(a).a9(this.a.gaA())==null},
$S:5}
A.cv.prototype={
$1(a){return!((u._.a(a).b+=this.a)<0.42)},
$S:18};(function aliases(){var t=J.ad.prototype
t.bj=t.j
t=A.aT.prototype
t.bi=t.bH
t.aM=t.a3})();(function installTearOffs(){var t=hunkHelpers._static_0,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(A,"hk","fr",1)
s(A,"ht","h0",2)
r(A,"hK",2,null,["$1$2","$2"],["eI",function(a,b){return A.eI(a,b,u.H)}],6,0)
r(A,"hJ",2,null,["$1$2","$2"],["eH",function(a,b){return A.eH(a,b,u.H)}],6,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.p,null)
r(A.p,[A.dl,J.bE,A.b9,J.ak,A.r,A.j,A.cN,A.e,A.a8,A.bg,A.G,A.be,A.as,A.aQ,A.F,A.cQ,A.cJ,A.O,A.cE,A.an,A.b0,A.cS,A.W,A.c3,A.cZ,A.aD,A.c6,A.aq,A.bw,A.by,A.cW,A.ba,A.a3,A.ao,A.b5,A.cP,A.aE,A.cw,A.bz,A.cK,A.ch,A.ci,A.ca,A.cI,A.cd,A.a,A.cO,A.k,A.aT,A.cy,A.bW,A.cg,A.ax,A.ae,A.al,A.cm])
r(J.bE,[J.bG,J.aV,J.aX,J.aW,J.aY,J.az,J.aA])
r(J.aX,[J.ad,J.n,A.aB,A.b3])
r(J.ad,[J.bT,J.aF,J.ab])
s(J.bF,A.b9)
s(J.cz,J.n)
r(J.az,[J.aU,J.bH])
r(A.r,[A.ac,A.bd,A.bI,A.c1,A.bX,A.c2,A.aZ,A.bs,A.a2,A.bf,A.c0,A.bb,A.bx])
s(A.aG,A.j)
s(A.aP,A.aG)
r(A.e,[A.aS,A.ap])
r(A.aS,[A.I,A.a7,A.a6])
r(A.I,[A.bc,A.S,A.c5])
s(A.aH,A.as)
s(A.aI,A.aH)
s(A.aR,A.aQ)
r(A.F,[A.bD,A.bu,A.bv,A.c_,A.d8,A.da,A.cb,A.cf,A.ce,A.cl,A.cj,A.dc,A.ct,A.cs,A.cu,A.cn,A.co,A.cp,A.cq,A.cr,A.cv])
s(A.am,A.bD)
s(A.cL,A.bu)
s(A.b6,A.bd)
r(A.c_,[A.bZ,A.ay])
r(A.O,[A.a5,A.c4])
r(A.bv,[A.cA,A.d9,A.cF,A.cH,A.cX,A.ck,A.cc])
r(A.b3,[A.bK,A.aC])
r(A.aC,[A.bi,A.bk])
s(A.bj,A.bi)
s(A.b1,A.bj)
s(A.bl,A.bk)
s(A.b2,A.bl)
r(A.b1,[A.bL,A.bM])
r(A.b2,[A.bN,A.bO,A.bP,A.bQ,A.bR,A.b4,A.bS])
s(A.aJ,A.c2)
s(A.bm,A.aD)
s(A.bh,A.bm)
s(A.bJ,A.aZ)
s(A.cB,A.bw)
r(A.by,[A.cD,A.cC])
s(A.cV,A.cW)
r(A.a2,[A.b7,A.bC])
s(A.cx,A.aT)
t(A.aG,A.be)
t(A.bi,A.j)
t(A.bj,A.G)
t(A.bk,A.j)
t(A.bl,A.G)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{b:"int",f:"double",X:"num",o:"String",u:"bool",b5:"Null",i:"List",p:"Object",a_:"Map",w:"JSObject"},mangledNames:{},types:["f(a)","b()","@(@)","~(p?,p?)","u(f)","u(al)","0^(0^,0^)<X>","@(@,o)","@(o)","~(@,@)","f(@)","f(o,f,f,f)","u(o)","u(k)","u(f,f)","o(o)","a(f,f)","u(@)","u(ae)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.aI&&a.b(c.a)&&b.b(c.b)}}
A.fS(v.typeUniverse,JSON.parse('{"ab":"ad","bT":"ad","aF":"ad","hS":"aB","bG":{"u":[],"l":[]},"aV":{"l":[]},"aX":{"w":[]},"ad":{"w":[]},"n":{"i":["1"],"w":[],"e":["1"]},"bF":{"b9":[]},"cz":{"n":["1"],"i":["1"],"w":[],"e":["1"]},"ak":{"Z":["1"]},"az":{"f":[],"X":[]},"aU":{"f":[],"b":[],"X":[],"l":[]},"bH":{"f":[],"X":[],"l":[]},"aA":{"o":[],"l":[]},"ac":{"r":[]},"aP":{"j":["b"],"be":["b"],"i":["b"],"e":["b"],"j.E":"b"},"aS":{"e":["1"]},"I":{"e":["1"]},"bc":{"I":["1"],"e":["1"],"e.E":"1","I.E":"1"},"a8":{"Z":["1"]},"S":{"I":["2"],"e":["2"],"e.E":"2","I.E":"2"},"ap":{"e":["1"],"e.E":"1"},"bg":{"Z":["1"]},"aG":{"j":["1"],"be":["1"],"i":["1"],"e":["1"]},"aI":{"aH":[],"as":[]},"aQ":{"a_":["1","2"]},"aR":{"aQ":["1","2"],"a_":["1","2"]},"bD":{"F":[],"a4":[]},"am":{"F":[],"a4":[]},"b6":{"r":[]},"bI":{"r":[]},"c1":{"r":[]},"F":{"a4":[]},"bu":{"F":[],"a4":[]},"bv":{"F":[],"a4":[]},"c_":{"F":[],"a4":[]},"bZ":{"F":[],"a4":[]},"ay":{"F":[],"a4":[]},"bX":{"r":[]},"a5":{"O":["1","2"],"e1":["1","2"],"a_":["1","2"],"O.K":"1","O.V":"2"},"a7":{"e":["1"],"e.E":"1"},"an":{"Z":["1"]},"a6":{"e":["ao<1,2>"],"e.E":"ao<1,2>"},"b0":{"Z":["ao<1,2>"]},"aH":{"as":[]},"aB":{"w":[],"l":[]},"b3":{"w":[]},"bK":{"w":[],"l":[]},"aC":{"N":["1"],"w":[]},"b1":{"j":["f"],"i":["f"],"N":["f"],"w":[],"e":["f"],"G":["f"]},"b2":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"]},"bL":{"j":["f"],"i":["f"],"N":["f"],"w":[],"e":["f"],"G":["f"],"l":[],"j.E":"f"},"bM":{"j":["f"],"i":["f"],"N":["f"],"w":[],"e":["f"],"G":["f"],"l":[],"j.E":"f"},"bN":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"],"l":[],"j.E":"b"},"bO":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"],"l":[],"j.E":"b"},"bP":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"],"l":[],"j.E":"b"},"bQ":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"],"l":[],"j.E":"b"},"bR":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"],"l":[],"j.E":"b"},"b4":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"],"l":[],"j.E":"b"},"bS":{"j":["b"],"i":["b"],"N":["b"],"w":[],"e":["b"],"G":["b"],"l":[],"j.E":"b"},"c2":{"r":[]},"aJ":{"r":[]},"bh":{"aD":["1"],"du":["1"],"e":["1"]},"aq":{"Z":["1"]},"j":{"i":["1"],"e":["1"]},"O":{"a_":["1","2"]},"aD":{"du":["1"],"e":["1"]},"bm":{"aD":["1"],"du":["1"],"e":["1"]},"c4":{"O":["o","@"],"a_":["o","@"],"O.K":"o","O.V":"@"},"c5":{"I":["o"],"e":["o"],"e.E":"o","I.E":"o"},"aZ":{"r":[]},"bJ":{"r":[]},"f":{"X":[]},"b":{"X":[]},"i":{"e":["1"]},"bs":{"r":[]},"bd":{"r":[]},"a2":{"r":[]},"b7":{"r":[]},"bC":{"r":[]},"bf":{"r":[]},"c0":{"r":[]},"bb":{"r":[]},"bx":{"r":[]},"ba":{"r":[]},"aE":{"fx":[]},"bW":{"ft":[]},"fi":{"i":["b"],"e":["b"]},"fB":{"i":["b"],"e":["b"]},"fA":{"i":["b"],"e":["b"]},"fg":{"i":["b"],"e":["b"]},"fy":{"i":["b"],"e":["b"]},"fh":{"i":["b"],"e":["b"]},"fz":{"i":["b"],"e":["b"]},"fd":{"i":["f"],"e":["f"]},"fe":{"i":["f"],"e":["f"]}}'))
A.fR(v.typeUniverse,JSON.parse('{"aS":1,"aG":1,"aC":1,"bm":1,"bw":2,"by":2}'))
var u=(function rtii(){var t=A.c8
return{E:t("aP"),V:t("al"),C:t("r"),Z:t("a4"),u:t("am<f>"),R:t("e<@>"),v:t("n<al>"),q:t("n<i<f>>"),U:t("n<i<X>>"),O:t("n<a_<o,f>>"),l:t("n<ae>"),L:t("n<a>"),W:t("n<+(a,f)>"),s:t("n<o>"),t:t("n<f>"),b:t("n<@>"),Y:t("n<b>"),a:t("n<X>"),T:t("aV"),m:t("w"),M:t("ab"),p:t("N<@>"),j:t("i<@>"),c:t("a_<o,@>"),f:t("a_<@,@>"),_:t("ae"),P:t("b5"),K:t("p"),n:t("a"),J:t("hT"),F:t("+()"),N:t("o"),k:t("l"),o:t("aF"),y:t("u"),i:t("f"),z:t("@"),S:t("b"),Q:t("dT<b5>?"),A:t("w?"),d:t("i<@>?"),X:t("p?"),w:t("o?"),g:t("c6?"),e:t("u?"),I:t("f?"),x:t("b?"),B:t("X?"),H:t("X"),D:t("~(o,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.H=J.bE.prototype
B.a=J.n.prototype
B.c=J.aU.prototype
B.b=J.az.prototype
B.e=J.aA.prototype
B.I=J.ab.prototype
B.J=J.aX.prototype
B.q=J.bT.prototype
B.k=J.aF.prototype
B.t=new A.ax(0,0)
B.m=new A.am(A.hJ(),u.u)
B.l=new A.am(A.hK(),u.u)
B.u=new A.ca()
B.n=function getTagFallback(o) {
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
B.o=function(hooks) { return hooks; }

B.d=new A.cB()
B.h=new A.cN()
B.B=new A.a3("Invalid mobile enemy variation")
B.C=new A.a3("start pose values")
B.D=new A.a3("start pose count")
B.E=new A.a3("Invalid mobile enemy pace")
B.F=new A.a3("start pose bounds")
B.G=new A.a3("start pose speed")
B.K=new A.cC(null)
B.L=new A.cD(null)
B.p=t([1,0.25,0.5,3],u.t)
B.N={}
B.M=new A.aR(B.N,[],A.c8("aR<@,@>"))
B.i=new A.a(0,1)
B.O=new A.a(0,-1)
B.f=new A.a(1,0)
B.j=new A.a(1,1)
B.P=new A.a(-1,0)
B.r=new A.cO(380,380)
B.Q=A.Y("hO")
B.R=A.Y("hP")
B.S=A.Y("fd")
B.T=A.Y("fe")
B.U=A.Y("fg")
B.V=A.Y("fh")
B.W=A.Y("fi")
B.X=A.Y("p")
B.Y=A.Y("fy")
B.Z=A.Y("fz")
B.a_=A.Y("fA")
B.a0=A.Y("fB")})();(function staticFields(){$.cU=null
$.P=A.m([],A.c8("n<p>"))
$.e7=null
$.cM=0
$.e9=A.hk()
$.dQ=null
$.dP=null
$.eF=null
$.eA=null
$.eL=null
$.d6=null
$.db=null
$.dG=null
$.cY=A.m([],A.c8("n<i<p>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hR","eO",()=>A.eE("_$dart_dartClosure"))
t($,"hQ","dJ",()=>A.eE("_$dart_dartClosure_dartJSInterop"))
t($,"i5","f_",()=>A.m([new J.bF()],A.c8("n<b9>")))
t($,"hV","eQ",()=>A.a9(A.cR({
toString:function(){return"$receiver$"}})))
t($,"hW","eR",()=>A.a9(A.cR({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hX","eS",()=>A.a9(A.cR(null)))
t($,"hY","eT",()=>A.a9(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"i0","eW",()=>A.a9(A.cR(void 0)))
t($,"i1","eX",()=>A.a9(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"i_","eV",()=>A.a9(A.ed(null)))
t($,"hZ","eU",()=>A.a9(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"i3","eZ",()=>A.a9(A.ed(void 0)))
t($,"i2","eY",()=>A.a9(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"i4","de",()=>A.eJ(B.X))
t($,"hU","eP",()=>{A.fs()
return $.cM})})();(function nativeSupport(){!function(){var t=function(a){var n={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.aB,SharedArrayBuffer:A.aB,ArrayBufferView:A.b3,DataView:A.bK,Float32Array:A.bL,Float64Array:A.bM,Int16Array:A.bN,Int32Array:A.bO,Int8Array:A.bP,Uint16Array:A.bQ,Uint32Array:A.bR,Uint8ClampedArray:A.b4,CanvasPixelArray:A.b4,Uint8Array:A.bS})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.aC.$nativeSuperclassTag="ArrayBufferView"
A.bi.$nativeSuperclassTag="ArrayBufferView"
A.bj.$nativeSuperclassTag="ArrayBufferView"
A.b1.$nativeSuperclassTag="ArrayBufferView"
A.bk.$nativeSuperclassTag="ArrayBufferView"
A.bl.$nativeSuperclassTag="ArrayBufferView"
A.b2.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$0=function(){return this()}
Function.prototype.$1$1=function(a){return this(a)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.hH
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
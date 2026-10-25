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
if(a[b]!==t){A.hu(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.n(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.dm(b)
return new t(c,this)}:function(){if(t===null)t=A.dm(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.dm(a).prototype
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
ds(a,b,c,d){return{i:a,p:b,e:c,x:d}},
dn(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.dq==null){A.hj()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.b(A.dX("Return interceptor for "+A.r(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.cH
if(p==null)p=$.cH=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.ho(a)
if(q!=null)return q
if(typeof a=="function")return B.K
t=Object.getPrototypeOf(a)
if(t==null)return B.r
if(t===Object.prototype)return B.r
if(typeof r=="function"){p=$.cH
if(p==null)p=$.cH=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.i,enumerable:false,writable:true,configurable:true})
return B.i}return B.i},
dG(a,b){if(a<0||a>4294967295)throw A.b(A.b1(a,0,4294967295,"length",null))
return J.f2(new Array(a),b)},
dH(a,b){if(a<0)throw A.b(A.c2("Length must be a non-negative integer: "+a))
return A.n(new Array(a),b.i("l<0>"))},
d5(a,b){if(a<0)throw A.b(A.c2("Length must be a non-negative integer: "+a))
return A.n(new Array(a),b.i("l<0>"))},
f2(a,b){var t=A.n(a,b.i("l<0>"))
t.$flags=1
return t},
dI(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
f3(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.dI(s))break;++b}return b},
f4(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.j(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.dI(r))break}return b},
an(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aN.prototype
return J.bB.prototype}if(typeof a=="string")return J.au.prototype
if(a==null)return J.aO.prototype
if(typeof a=="boolean")return J.bA.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a6.prototype
if(typeof a=="symbol")return J.aR.prototype
if(typeof a=="bigint")return J.aP.prototype
return a}if(a instanceof A.o)return a
return J.dn(a)},
aF(a){if(typeof a=="string")return J.au.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a6.prototype
if(typeof a=="symbol")return J.aR.prototype
if(typeof a=="bigint")return J.aP.prototype
return a}if(a instanceof A.o)return a
return J.dn(a)},
ao(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a6.prototype
if(typeof a=="symbol")return J.aR.prototype
if(typeof a=="bigint")return J.aP.prototype
return a}if(a instanceof A.o)return a
return J.dn(a)},
hf(a){if(typeof a=="number")return J.at.prototype
if(a==null)return a
if(!(a instanceof A.o))return J.az.prototype
return a},
O(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.an(a).K(a,b)},
ar(a,b){if(typeof b==="number")if(Array.isArray(a)||A.hn(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.ao(a).h(a,b)},
eJ(a,b,c){return J.ao(a).u(a,b,c)},
du(a,b,c){return J.hf(a).p(a,b,c)},
dv(a,b){return J.ao(a).A(a,b)},
K(a){return J.an(a).gt(a)},
eK(a){return J.aF(a).gC(a)},
eL(a){return J.aF(a).gam(a)},
d2(a){return J.ao(a).gv(a)},
T(a){return J.aF(a).gk(a)},
eM(a){return J.an(a).gn(a)},
eN(a,b,c){return J.ao(a).aH(a,b,c)},
bm(a){return J.an(a).j(a)},
by:function by(){},
bA:function bA(){},
aO:function aO(){},
aQ:function aQ(){},
a8:function a8(){},
bN:function bN(){},
az:function az(){},
a6:function a6(){},
aP:function aP(){},
aR:function aR(){},
l:function l(a){this.$ti=a},
bz:function bz(){},
co:function co(a){this.$ti=a},
af:function af(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
at:function at(){},
aN:function aN(){},
bB:function bB(){},
au:function au(){}},A={d6:function d6(){},
f6(a){return new A.a7("Field '"+a+"' has not been initialized.")},
aT(a){return new A.a7("Local '"+a+"' has not been initialized.")},
f5(a){return new A.a7("Field '"+a+"' has already been initialized.")},
aa(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
de(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
ek(a,b,c){return a},
dr(a){var t,s
for(t=$.J.length,s=0;s<t;++s)if(a===$.J[s])return!0
return!1},
dV(a,b,c,d){A.db(b,"start")
if(c!=null){A.db(c,"end")
if(b>c)A.D(A.b1(b,0,c,"start",null))}return new A.b5(a,b,c,d.i("b5<0>"))},
dF(){return new A.b4("No element")},
a7:function a7(a){this.a=a},
aI:function aI(a){this.a=a},
cA:function cA(){},
aL:function aL(){},
A:function A(){},
b5:function b5(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
a_:function a_(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
L:function L(a,b,c){this.a=a
this.b=b
this.$ti=c},
b9:function b9(a,b,c){this.a=a
this.b=b
this.$ti=c},
ba:function ba(a,b,c){this.a=a
this.b=b
this.$ti=c},
z:function z(){},
b7:function b7(){},
aA:function aA(){},
eu(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
hn(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
r(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.bm(a)
return t},
bO(a){var t,s=$.dP
if(s==null)s=$.dP=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bP(a){var t,s,r,q
if(a instanceof A.o)return A.C(A.ae(a),null)
t=J.an(a)
if(t===B.J||t===B.L||u.o.b(a)){s=B.l(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.C(A.ae(a),null)},
dQ(a){var t,s,r
if(a==null||typeof a=="number"||A.cR(a))return J.bm(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.y)return a.j(0)
if(a instanceof A.al)return a.aB(!0)
t=$.eI()
for(s=0;s<1;++s){r=t[s].bC(a)
if(r!=null)return r}return"Instance of '"+A.bP(a)+"'"},
f9(){return Date.now()},
fa(){var t,s
if($.cz!==0)return
$.cz=1000
if(typeof window=="undefined")return
t=window
if(t==null)return
if(!!t.dartUseDateNowForTicks)return
s=t.performance
if(s==null)return
if(typeof s.now!="function")return
$.cz=1e6
$.dR=new A.cy(s)},
x(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.c.aA(t,10)|55296)>>>0,t&1023|56320)}throw A.b(A.b1(a,0,1114111,null,null))},
cV(a){throw A.b(A.ej(a))},
j(a,b){if(a==null)J.T(a)
throw A.b(A.cT(a,b))},
cT(a,b){var t,s="index"
if(!A.ee(b))return new A.X(!0,b,s,null)
t=J.T(a)
if(b<0||b>=t)return A.d3(b,t,a,s)
return new A.b0(null,null,!0,b,s,"Value not in range")},
ej(a){return new A.X(!0,a,null,null)},
b(a){return A.v(a,new Error())},
v(a,b){var t
if(a==null)a=new A.b6()
b.dartException=a
t=A.hv
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hv(){return J.bm(this.dartException)},
D(a,b){throw A.v(a,b==null?new Error():b)},
aH(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.D(A.fK(a,b,c),t)},
fK(a,b,c){var t,s,r,q,p,o,n,m,l
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
return new A.b8("'"+t+"': Cannot "+p+" "+m+l+o)},
W(a){throw A.b(A.P(a))},
a0(a){var t,s,r,q,p,o
a=A.ht(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.n([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.cD(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
cE(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
dW(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
d7(a,b){var t=b==null,s=t?null:b.method
return new A.bC(a,s,t?null:b.receiver)},
ev(a){if(a==null)return new A.cw(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aq(a,a.dartException)
return A.ha(a)},
aq(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
ha(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.c.aA(s,16)&8191)===10)switch(r){case 438:return A.aq(a,A.d7(A.r(t)+" (Error "+r+")",null))
case 445:case 5007:A.r(t)
return A.aq(a,new A.b_())}}if(a instanceof TypeError){q=$.ey()
p=$.ez()
o=$.eA()
n=$.eB()
m=$.eE()
l=$.eF()
k=$.eD()
$.eC()
j=$.eH()
i=$.eG()
h=q.D(t)
if(h!=null)return A.aq(a,A.d7(A.ac(t),h))
else{h=p.D(t)
if(h!=null){h.method="call"
return A.aq(a,A.d7(A.ac(t),h))}else if(o.D(t)!=null||n.D(t)!=null||m.D(t)!=null||l.D(t)!=null||k.D(t)!=null||n.D(t)!=null||j.D(t)!=null||i.D(t)!=null){A.ac(t)
return A.aq(a,new A.b_())}}return A.aq(a,new A.bV(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.b3()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.aq(a,new A.X(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.b3()
return a},
er(a){if(a==null)return J.K(a)
if(typeof a=="object")return A.bO(a)
return J.K(a)},
he(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.u(0,a[t],a[s])}return b},
eU(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bS().constructor.prototype):Object.create(new A.as(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.dB(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.eQ(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.dB(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
eQ(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.b("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.eO)}throw A.b("Error in functionType of tearoff")},
eR(a,b,c,d){var t=A.dA
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
dB(a,b,c,d){if(c)return A.eT(a,b,d)
return A.eR(b.length,d,a,b)},
eS(a,b,c,d){var t=A.dA,s=A.eP
switch(b?-1:a){case 0:throw A.b(new A.bR("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
eT(a,b,c){var t,s
if($.dy==null)$.dy=A.dx("interceptor")
if($.dz==null)$.dz=A.dx("receiver")
t=b.length
s=A.eS(t,c,a,b)
return s},
dm(a){return A.eU(a)},
eO(a,b){return A.bl(v.typeUniverse,A.ae(a.a),b)},
dA(a){return a.a},
eP(a){return a.b},
dx(a){var t,s,r,q=new A.as("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.b(A.c2("Field name "+a+" not found."))},
em(a){return v.getIsolateTag(a)},
ho(a){var t,s,r,q,p,o=A.ac($.en.$1(a)),n=$.cU[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cZ[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.c0($.ei.$2(a,o))
if(r!=null){n=$.cU[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cZ[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.d0(t)
$.cU[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.cZ[o]=t
return t}if(q==="-"){p=A.d0(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.es(a,t)
if(q==="*")throw A.b(A.dX(o))
if(v.leafTags[o]===true){p=A.d0(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.es(a,t)},
es(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.ds(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
d0(a){return J.ds(a,!1,null,!!a.$iG)},
hq(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.d0(t)
else return J.ds(t,c,null,null)},
hj(){if(!0===$.dq)return
$.dq=!0
A.hk()},
hk(){var t,s,r,q,p,o,n,m
$.cU=Object.create(null)
$.cZ=Object.create(null)
A.hi()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.et.$1(p)
if(o!=null){n=A.hq(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
hi(){var t,s,r,q,p,o,n=B.u()
n=A.aE(B.v,A.aE(B.w,A.aE(B.m,A.aE(B.m,A.aE(B.x,A.aE(B.y,A.aE(B.z(B.l),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.en=new A.cW(q)
$.ei=new A.cX(p)
$.et=new A.cY(o)},
aE(a,b){return a(b)||b},
hc(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
ht(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
bg:function bg(a,b){this.a=a
this.b=b},
aJ:function aJ(){},
aK:function aK(a,b,c){this.a=a
this.b=b
this.$ti=c},
bx:function bx(){},
ah:function ah(a,b){this.a=a
this.$ti=b},
cy:function cy(a){this.a=a},
b2:function b2(){},
cD:function cD(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b_:function b_(){},
bC:function bC(a,b,c){this.a=a
this.b=b
this.c=c},
bV:function bV(a){this.a=a},
cw:function cw(a){this.a=a},
y:function y(){},
bp:function bp(){},
bq:function bq(){},
bT:function bT(){},
bS:function bS(){},
as:function as(a,b){this.a=a
this.b=b},
bR:function bR(a){this.a=a},
Z:function Z(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cp:function cp(a){this.a=a},
ct:function ct(a,b){this.a=a
this.b=b
this.c=null},
ai:function ai(a,b){this.a=a
this.$ti=b},
aU:function aU(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
cW:function cW(a){this.a=a},
cX:function cX(a){this.a=a},
cY:function cY(a){this.a=a},
al:function al(){},
aB:function aB(){},
hu(a){throw A.v(new A.a7("Field '"+a+"' has been assigned during initialization."),new Error())},
f(){throw A.v(A.f6(""),new Error())},
a4(){throw A.v(A.f5(""),new Error())},
cG(){var t=new A.cF()
return t.b=t},
cF:function cF(){this.b=null},
am(a,b,c){if(a>>>0!==a||a>=c)throw A.b(A.cT(b,a))},
av:function av(){},
aX:function aX(){},
bE:function bE(){},
aw:function aw(){},
aV:function aV(){},
aW:function aW(){},
bF:function bF(){},
bG:function bG(){},
bH:function bH(){},
bI:function bI(){},
bJ:function bJ(){},
bK:function bK(){},
bL:function bL(){},
aY:function aY(){},
bM:function bM(){},
bc:function bc(){},
bd:function bd(){},
be:function be(){},
bf:function bf(){},
dc(a,b){var t=b.c
return t==null?b.c=A.bj(a,"dC",[b.x]):t},
dS(a){var t=a.w
if(t===6||t===7)return A.dS(a.x)
return t===11||t===12},
fe(a){return a.as},
c1(a){return A.cN(v.typeUniverse,a,!1)},
hm(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.ad(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
ad(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.ad(a0,t,a2,a3)
if(s===t)return a1
return A.e5(a0,s,!0)
case 7:t=a1.x
s=A.ad(a0,t,a2,a3)
if(s===t)return a1
return A.e4(a0,s,!0)
case 8:r=a1.y
q=A.aD(a0,r,a2,a3)
if(q===r)return a1
return A.bj(a0,a1.x,q)
case 9:p=a1.x
o=A.ad(a0,p,a2,a3)
n=a1.y
m=A.aD(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.dh(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.aD(a0,k,a2,a3)
if(j===k)return a1
return A.e6(a0,l,j)
case 11:i=a1.x
h=A.ad(a0,i,a2,a3)
g=a1.y
f=A.h7(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.e3(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.aD(a0,e,a2,a3)
p=a1.x
o=A.ad(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.di(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.b(A.bo("Attempted to substitute unexpected RTI kind "+a))}},
aD(a,b,c,d){var t,s,r,q,p=b.length,o=A.cO(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.ad(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
h8(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.cO(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.ad(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
h7(a,b,c,d){var t,s=b.a,r=A.aD(a,s,c,d),q=b.b,p=A.aD(a,q,c,d),o=b.c,n=A.h8(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.bX()
t.a=r
t.b=p
t.c=n
return t},
n(a,b){a[v.arrayRti]=b
return a},
cS(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.hh(t)
return a.$S()}return null},
hl(a,b){var t
if(A.dS(b))if(a instanceof A.y){t=A.cS(a)
if(t!=null)return t}return A.ae(a)},
ae(a){if(a instanceof A.o)return A.E(a)
if(Array.isArray(a))return A.B(a)
return A.dk(J.an(a))},
B(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
E(a){var t=a.$ti
return t!=null?t:A.dk(a)},
dk(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.fR(a,t)},
fR(a,b){var t=a instanceof A.y?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fB(v.typeUniverse,t.name)
b.$ccache=s
return s},
hh(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.cN(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
hg(a){return A.a3(A.E(a))},
dp(a){var t=A.cS(a)
return A.a3(t==null?A.ae(a):t)},
dl(a){var t
if(a instanceof A.al)return A.hd(a.$r,a.av())
t=a instanceof A.y?A.cS(a):null
if(t!=null)return t
if(u.k.b(a))return J.eM(a).a
if(Array.isArray(a))return A.B(a)
return A.ae(a)},
a3(a){var t=a.r
return t==null?a.r=new A.cM(a):t},
hd(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.j(r,0)
t=A.bl(v.typeUniverse,A.dl(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.j(r,s)
t=A.e7(v.typeUniverse,t,A.dl(r[s]))}return A.bl(v.typeUniverse,t,a)},
S(a){return A.a3(A.cN(v.typeUniverse,a,!1))},
fQ(a){var t=this
t.b=A.h6(t)
return t.b(a)},
h6(a){var t,s,r,q,p
if(a===u.K)return A.fX
if(A.ap(a))return A.h0
t=a.w
if(t===6)return A.fO
if(t===1)return A.eg
if(t===7)return A.fS
s=A.h5(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.ap)){a.f="$i"+r
if(r==="h")return A.fV
if(a===u.m)return A.fU
return A.h_}}else if(t===10){q=A.hc(a.x,a.y)
p=q==null?A.eg:q
return p==null?A.ea(p):p}return A.fM},
h5(a){if(a.w===8){if(a===u.S)return A.ee
if(a===u.i||a===u.H)return A.fW
if(a===u.N)return A.fZ
if(a===u.y)return A.cR}return null},
fP(a){var t=this,s=A.fL
if(A.ap(t))s=A.fH
else if(t===u.K)s=A.ea
else if(A.aG(t)){s=A.fN
if(t===u.x)s=A.fE
else if(t===u.w)s=A.c0
else if(t===u.d)s=A.N
else if(t===u.B)s=A.p
else if(t===u.I)s=A.fD
else if(t===u.A)s=A.fG}else if(t===u.S)s=A.cP
else if(t===u.N)s=A.ac
else if(t===u.y)s=A.dj
else if(t===u.H)s=A.a2
else if(t===u.i)s=A.a1
else if(t===u.m)s=A.fF
t.a=s
return t.a(a)},
fM(a){var t=this
if(a==null)return A.aG(t)
return A.eo(v.typeUniverse,A.hl(a,t),t)},
fO(a){if(a==null)return!0
return this.x.b(a)},
h_(a){var t,s=this
if(a==null)return A.aG(s)
t=s.f
if(a instanceof A.o)return!!a[t]
return!!J.an(a)[t]},
fV(a){var t,s=this
if(a==null)return A.aG(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.o)return!!a[t]
return!!J.an(a)[t]},
fU(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.o)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
ef(a){if(typeof a=="object"){if(a instanceof A.o)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
fL(a){var t=this
if(a==null){if(A.aG(t))return a}else if(t.b(a))return a
throw A.v(A.eb(a,t),new Error())},
fN(a){var t=this
if(a==null||t.b(a))return a
throw A.v(A.eb(a,t),new Error())},
eb(a,b){return new A.aC("TypeError: "+A.dY(a,A.C(b,null)))},
el(a,b,c,d){if(A.eo(v.typeUniverse,a,b))return a
throw A.v(A.ft("The type argument '"+A.C(a,null)+"' is not a subtype of the type variable bound '"+A.C(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
dY(a,b){return A.bv(a)+": type '"+A.C(A.dl(a),null)+"' is not a subtype of type '"+b+"'"},
ft(a){return new A.aC("TypeError: "+a)},
M(a,b){return new A.aC("TypeError: "+A.dY(a,b))},
fS(a){var t=this
return t.x.b(a)||A.dc(v.typeUniverse,t).b(a)},
fX(a){return a!=null},
ea(a){if(a!=null)return a
throw A.v(A.M(a,"Object"),new Error())},
h0(a){return!0},
fH(a){return a},
eg(a){return!1},
cR(a){return!0===a||!1===a},
dj(a){if(!0===a)return!0
if(!1===a)return!1
throw A.v(A.M(a,"bool"),new Error())},
N(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.v(A.M(a,"bool?"),new Error())},
a1(a){if(typeof a=="number")return a
throw A.v(A.M(a,"double"),new Error())},
fD(a){if(typeof a=="number")return a
if(a==null)return a
throw A.v(A.M(a,"double?"),new Error())},
ee(a){return typeof a=="number"&&Math.floor(a)===a},
cP(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.v(A.M(a,"int"),new Error())},
fE(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.v(A.M(a,"int?"),new Error())},
fW(a){return typeof a=="number"},
a2(a){if(typeof a=="number")return a
throw A.v(A.M(a,"num"),new Error())},
p(a){if(typeof a=="number")return a
if(a==null)return a
throw A.v(A.M(a,"num?"),new Error())},
fZ(a){return typeof a=="string"},
ac(a){if(typeof a=="string")return a
throw A.v(A.M(a,"String"),new Error())},
c0(a){if(typeof a=="string")return a
if(a==null)return a
throw A.v(A.M(a,"String?"),new Error())},
fF(a){if(A.ef(a))return a
throw A.v(A.M(a,"JSObject"),new Error())},
fG(a){if(a==null)return a
if(A.ef(a))return a
throw A.v(A.M(a,"JSObject?"),new Error())},
eh(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.C(a[r],b)
return t},
h4(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.eh(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.C(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
ec(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.n([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.l(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.j(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.C(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.C(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.C(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.C(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.C(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
C(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.C(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.C(a.x,b)+">"
if(m===8){q=A.h9(a.x)
p=a.y
return p.length>0?q+("<"+A.eh(p,b)+">"):q}if(m===10)return A.h4(a,b)
if(m===11)return A.ec(a,b,null)
if(m===12)return A.ec(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.j(b,o)
return b[o]}return"?"},
h9(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
fC(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fB(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.cN(a,b,!1)
else if(typeof n=="number"){t=n
s=A.bk(a,5,"#")
r=A.cO(t)
for(q=0;q<t;++q)r[q]=s
p=A.bj(a,b,r)
o[b]=p
return p}else return n},
fA(a,b){return A.e8(a.tR,b)},
fz(a,b){return A.e8(a.eT,b)},
cN(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.e1(A.e_(a,null,b,!1))
s.set(b,t)
return t},
bl(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.e1(A.e_(a,b,c,!0))
r.set(c,s)
return s},
e7(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.dh(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
ab(a,b){b.a=A.fP
b.b=A.fQ
return b},
bk(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.Q(null,null)
t.w=b
t.as=c
s=A.ab(a,t)
a.eC.set(c,s)
return s},
e5(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fx(a,b,s,c)
a.eC.set(s,t)
return t},
fx(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.ap(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aG(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.Q(null,null)
r.w=6
r.x=b
r.as=c
return A.ab(a,r)},
e4(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fv(a,b,s,c)
a.eC.set(s,t)
return t},
fv(a,b,c,d){var t,s
if(d){t=b.w
if(A.ap(b)||b===u.K)return b
else if(t===1)return A.bj(a,"dC",[b])
else if(b===u.P||b===u.T)return u.Q}s=new A.Q(null,null)
s.w=7
s.x=b
s.as=c
return A.ab(a,s)},
fy(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.Q(null,null)
t.w=13
t.x=b
t.as=r
s=A.ab(a,t)
a.eC.set(r,s)
return s},
bi(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fu(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bj(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.bi(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.Q(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.ab(a,s)
a.eC.set(q,r)
return r},
dh(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.bi(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.Q(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.ab(a,p)
a.eC.set(r,o)
return o},
e6(a,b,c){var t,s,r="+"+(b+"("+A.bi(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.Q(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.ab(a,t)
a.eC.set(r,s)
return s},
e3(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.bi(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.bi(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fu(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.Q(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.ab(a,q)
a.eC.set(s,p)
return p},
di(a,b,c,d){var t,s=b.as+("<"+A.bi(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fw(a,b,c,s,d)
a.eC.set(s,t)
return t},
fw(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.cO(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.ad(a,b,s,0)
n=A.aD(a,c,s,0)
return A.di(a,o,n,c!==n)}}m=new A.Q(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.ab(a,m)},
e_(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
e1(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.fo(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.e0(a,s,m,l,!1)
else if(r===46)s=A.e0(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.ak(a.u,a.e,l.pop()))
break
case 94:l.push(A.fy(a.u,l.pop()))
break
case 35:l.push(A.bk(a.u,5,"#"))
break
case 64:l.push(A.bk(a.u,2,"@"))
break
case 126:l.push(A.bk(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.fq(a,l)
break
case 38:A.fp(a,l)
break
case 63:q=a.u
l.push(A.e5(q,A.ak(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.e4(q,A.ak(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.fn(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.e2(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fs(a.u,a.e,p)
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
return A.ak(a.u,a.e,n)},
fo(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
e0(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fC(t,p.x)[q]
if(o==null)A.D('No "'+q+'" in "'+A.fe(p)+'"')
d.push(A.bl(t,p,o))}else d.push(q)
return n},
fq(a,b){var t,s=a.u,r=A.dZ(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bj(s,q,r))
else{t=A.ak(s,a.e,q)
switch(t.w){case 11:b.push(A.di(s,t,r,a.n))
break
default:b.push(A.dh(s,t,r))
break}}},
fn(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.dZ(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.ak(q,a.e,p)
r=new A.bX()
r.a=t
r.b=o
r.c=n
b.push(A.e3(q,s,r))
return
case-4:b.push(A.e6(q,b.pop(),t))
return
default:throw A.b(A.bo("Unexpected state under `()`: "+A.r(p)))}},
fp(a,b){var t=b.pop()
if(0===t){b.push(A.bk(a.u,1,"0&"))
return}if(1===t){b.push(A.bk(a.u,4,"1&"))
return}throw A.b(A.bo("Unexpected extended operation "+A.r(t)))},
dZ(a,b){var t=b.splice(a.p)
A.e2(a.u,a.e,t)
a.p=b.pop()
return t},
ak(a,b,c){if(typeof c=="string")return A.bj(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.fr(a,b,c)}else return c},
e2(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.ak(a,b,c[t])},
fs(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.ak(a,b,c[t])},
fr(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.b(A.bo("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.b(A.bo("Bad index "+c+" for "+b.j(0)))},
eo(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.u(a,b,null,c,null)
s.set(c,t)}return t},
u(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.ap(d))return!0
t=b.w
if(t===4)return!0
if(A.ap(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.u(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.u(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.u(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.u(a,b.x,c,d,e))return!1
return A.u(a,A.dc(a,b),c,d,e)}if(t===6)return A.u(a,q,c,d,e)&&A.u(a,b.x,c,d,e)
if(r===7){if(A.u(a,b,c,d.x,e))return!0
return A.u(a,b,c,A.dc(a,d),e)}if(r===6)return A.u(a,b,c,q,e)||A.u(a,b,c,d.x,e)
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
if(!A.u(a,k,c,j,e)||!A.u(a,j,e,k,c))return!1}return A.ed(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.ed(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.fT(a,b,c,d,e)}if(p&&r===10)return A.fY(a,b,c,d,e)
return!1},
ed(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.u(a2,a3.x,a4,a5.x,a6))return!1
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
if(!A.u(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.u(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.u(a2,l[i],a6,h,a4))return!1}g=t.c
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
if(!A.u(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
fT(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bl(a,b,s[p])
return A.e9(a,q,null,c,d.y,e)}return A.e9(a,b.y,null,c,d.y,e)},
e9(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.u(a,b[t],d,e[t],f))return!1
return!0},
fY(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.u(a,s[t],c,r[t],e))return!1
return!0},
aG(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.ap(a))if(t!==6)s=t===7&&A.aG(a.x)
return s},
ap(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
e8(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
cO(a){return a>0?new Array(a):v.typeUniverse.sEA},
Q:function Q(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
bX:function bX(){this.c=this.b=this.a=null},
cM:function cM(a){this.a=a},
bW:function bW(){},
aC:function aC(a){this.a=a},
f7(a,b){return new A.Z(a.i("@<0>").G(b).i("Z<1,2>"))},
U(a,b,c){return b.i("@<0>").G(c).i("dK<1,2>").a(A.he(a,new A.Z(b.i("@<0>").G(c).i("Z<1,2>"))))},
f8(a,b){return new A.Z(a.i("@<0>").G(b).i("Z<1,2>"))},
d8(a){return new A.bb(a.i("bb<0>"))},
dg(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
fm(a,b,c){var t=new A.aj(a,b,c.i("aj<0>"))
t.c=a.e
return t},
da(a){var t,s
if(A.dr(a))return"{...}"
t=new A.ay("")
try{s={}
B.a.l($.J,a)
t.a+="{"
s.a=!0
a.L(0,new A.cu(s,t))
t.a+="}"}finally{if(0>=$.J.length)return A.j($.J,-1)
$.J.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
bb:function bb(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
c_:function c_(a){this.a=a
this.c=this.b=null},
aj:function aj(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
i:function i(){},
H:function H(){},
cu:function cu(a,b){this.a=a
this.b=b},
ax:function ax(){},
bh:function bh(){},
h3(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.ev(s)
r=A.aM(String(t))
throw A.b(r)}r=A.cQ(q)
return r},
cQ(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.bY(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.cQ(a[t])
return a},
dJ(a,b,c){return new A.aS(a,b)},
fJ(a){return a.V()},
fk(a,b){return new A.cI(a,[],A.hb())},
fl(a,b,c){var t,s=new A.ay(""),r=A.fk(s,b)
r.a3(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
bY:function bY(a,b){this.a=a
this.b=b
this.c=null},
bZ:function bZ(a){this.a=a},
br:function br(){},
bt:function bt(){},
aS:function aS(a,b){this.a=a
this.b=b},
bD:function bD(a,b){this.a=a
this.b=b},
cq:function cq(){},
cs:function cs(a){this.b=a},
cr:function cr(a){this.a=a},
cJ:function cJ(){},
cK:function cK(a,b){this.a=a
this.b=b},
cI:function cI(a,b,c){this.c=a
this.a=b
this.b=c},
d9(a,b,c,d){var t,s=c?J.dH(a,d):J.dG(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
dM(a,b,c){var t,s,r=A.n([],c.i("l<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.W)(a),++s)B.a.l(r,c.a(a[s]))
if(b)return r
r.$flags=1
return r},
dL(a,b){var t,s=A.n([],b.i("l<0>"))
for(t=a.gv(a);t.m();)B.a.l(s,t.gq())
return s},
dU(a,b,c){var t=J.d2(b)
if(!t.m())return a
if(c.length===0){do a+=A.r(t.gq())
while(t.m())}else{a+=A.r(t.gq())
while(t.m())a=a+c+A.r(t.gq())}return a},
bv(a){if(typeof a=="number"||A.cR(a)||a==null)return J.bm(a)
if(typeof a=="string")return JSON.stringify(a)
return A.dQ(a)},
bo(a){return new A.bn(a)},
c2(a){return new A.X(!1,null,null,a)},
dw(a,b,c){return new A.X(!0,a,b,c)},
b1(a,b,c,d,e){return new A.b0(b,c,!0,a,d,"Invalid value")},
fc(a,b,c){if(0>a||a>c)throw A.b(A.b1(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.b(A.b1(b,a,c,"end",null))
return b}return c},
db(a,b){if(a<0)throw A.b(A.b1(a,0,null,b,null))
return a},
d3(a,b,c,d){return new A.bw(b,!0,a,d,"Index out of range")},
df(a){return new A.b8(a)},
dX(a){return new A.bU(a)},
dT(a){return new A.b4(a)},
P(a){return new A.bs(a)},
aM(a){return new A.F(a)},
f1(a,b,c){var t,s
if(A.dr(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.n([],u.s)
B.a.l($.J,a)
try{A.h1(a,t)}finally{if(0>=$.J.length)return A.j($.J,-1)
$.J.pop()}s=A.dU(b,u.R.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
d4(a,b,c){var t,s
if(A.dr(a))return b+"..."+c
t=new A.ay(b)
B.a.l($.J,a)
try{s=t
s.a=A.dU(s.a,a,", ")}finally{if(0>=$.J.length)return A.j($.J,-1)
$.J.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
h1(a,b){var t,s,r,q,p,o,n,m=a.gv(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.m())return
t=A.r(m.gq())
B.a.l(b,t)
l+=t.length+2;++k}if(!m.m()){if(k<=5)return
if(0>=b.length)return A.j(b,-1)
s=b.pop()
if(0>=b.length)return A.j(b,-1)
r=b.pop()}else{q=m.gq();++k
if(!m.m()){if(k<=4){B.a.l(b,A.r(q))
return}s=A.r(q)
if(0>=b.length)return A.j(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gq();++k
for(;m.m();q=p,p=o){o=m.gq();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.j(b,-1)
l-=b.pop().length+2;--k}B.a.l(b,"...")
return}}r=A.r(q)
s=A.r(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.j(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.l(b,n)
B.a.l(b,r)
B.a.l(b,s)},
dO(a,b,c,d){var t
if(B.e===c){t=J.K(a)
b=J.K(b)
return A.de(A.aa(A.aa($.d1(),t),b))}if(B.e===d){t=J.K(a)
b=J.K(b)
c=J.K(c)
return A.de(A.aa(A.aa(A.aa($.d1(),t),b),c))}t=J.K(a)
b=J.K(b)
c=J.K(c)
d=J.K(d)
d=A.de(A.aa(A.aa(A.aa(A.aa($.d1(),t),b),c),d))
return d},
q:function q(){},
bn:function bn(a){this.a=a},
b6:function b6(){},
X:function X(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
b0:function b0(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bw:function bw(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
b8:function b8(a){this.a=a},
bU:function bU(a){this.a=a},
b4:function b4(a){this.a=a},
bs:function bs(a){this.a=a},
b3:function b3(){},
F:function F(a){this.a=a},
c:function c(){},
aZ:function aZ(){},
o:function o(){},
cC:function cC(){this.b=this.a=0},
ay:function ay(a){this.a=a},
eV(a){var t,s,r,q,p,o,n,m,l,k,j=null,i=a.h(0,"aspects")
if(i==null)i=a.h(0,"enemyAspects")
if(u.j.b(i)&&J.eL(i)){t=J.eN(i,new A.c5(),u.i)
s=A.dL(t,t.$ti.i("A.E"))}else s=B.q
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
return new A.bu(t,s,r,q,p,o,n,m,l===!0,k)},
dD(a1){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=null,b="warning",a=A.N(a1.h(0,"startHintEnabled")),a0=A.p(a1.h(0,"idleSpeedMultiplier"))
if(a0==null)a0=c
if(a0==null)a0=0.5
t=A.N(a1.h(0,"idleEnemiesMove"))
s=A.p(a1.h(0,"speedRampSeconds"))
if(s==null)s=c
if(s==null)s=0.5
r=A.N(a1.h(0,"jumpEnabled"))
if(r==null)r=A.N(a1.h(0,"jumpsEnabled"))
q=A.p(a1.h(0,"jumpDurationSec"))
if(q==null)q=c
if(q==null)q=0.38
p=A.p(a1.h(0,"jumpCooldownSec"))
if(p==null)p=c
if(p==null)p=2
o=A.p(a1.h(0,"jumpScale"))
if(o==null)o=c
if(o==null)o=1.32
n=A.N(a1.h(0,"helmetEnabled"))
m=A.p(a1.h(0,"helmetInvulnSec"))
if(m==null)m=c
if(m==null)m=0.3
l=A.p(a1.h(0,"helmetCooldownSec"))
if(l==null)l=c
if(l==null)l=0
k=A.p(a1.h(0,"startInvulnSec"))
if(k==null)k=c
if(k==null)k=1
j=A.N(a1.h(0,"heartbeatHaptic"))
i=A.N(a1.h(0,"timerHaptic"))
h=A.c0(a1.h(0,"timerHapticStyle"))
if(h==null)h=b
g=A.c0(a1.h(0,"timerHapticStyle5"))
if(g==null)g=b
f=A.c0(a1.h(0,"timerHapticStyle10"))
if(f==null)f=b
e=A.p(a1.h(0,"hudSpeedScaleMax"))
if(e==null)e=c
if(e==null)e=400
d=A.N(a1.h(0,"wallsKillPlayer"))
return new A.cb(a!==!1,a0,t!==!1,s,r!==!1,q,p,o,n!==!1,m,l,k,j!==!1,i!==!1,h,g,f,e,d!==!1)},
dN(a,b){if(a==null)return b
if(typeof a!="number"||!isFinite(a)||a<0||a>0.5)throw A.b(B.B)
return a},
cl:function cl(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bu:function bu(a,b,c,d,e,f,g,h,i,j){var _=this
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
c5:function c5(){},
cx:function cx(a,b){this.a=a
this.b=b},
ca:function ca(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cb:function cb(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s){var _=this
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
c3:function c3(){},
cv:function cv(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eW(a){var t=new A.c7()
t.aV(a)
return t},
c7:function c7(){var _=this
_.y=_.x=_.w=_.r=_.f=_.e=_.d=_.c=_.b=_.a=$
_.as=_.Q=_.z=0
_.at=-100
_.cx=_.CW=_.ch=_.ay=0},
c9:function c9(a){this.a=a},
c8:function c8(a){this.a=a},
d:function d(a,b){this.a=a
this.b=b},
cB:function cB(){},
I:function I(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cm:function cm(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=0
_.e=null},
hp(){var t,s=v.G.globalThis,r=new A.d_()
if(typeof r=="function")A.D(A.c2("Attempting to rewrap a JS function."))
t=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.fI,r)
t[$.dt()]=r
s.untouchHelmetReplay=t},
d_:function d_(){},
fd(a){var t,s,r,q
for(t=new A.aI(a),s=u.V,t=new A.a_(t,t.gk(0),s.i("a_<i.E>")),s=s.i("i.E"),r=2166136261;t.m();){q=t.d
r=(r^(q==null?s.a(q):q))>>>0
r=r*403+((r&255)<<24>>>0)>>>0}return r===0?1:r},
bQ:function bQ(a){this.a=a},
cn:function cn(a){var _=this
_.a=null
_.f=_.e=_.d=_.c=_.b=$
_.w=_.r=0
_.z=_.y=_.x=!1
_.Q=null
_.ax=_.at=_.as=0
_.ay=a},
dE(a,b){var t,s
if(a.W(b))return 0
t=Math.max(0,Math.max(a.a-b.c,b.a-a.c))
s=Math.max(0,Math.max(a.b-b.d,b.b-a.d))
if(t>0&&s>0)return Math.sqrt(t*t+s*s)
return Math.max(t,s)},
c4:function c4(a,b){this.a=a
this.b=b},
a9:function a9(a){this.a=a
this.b=0},
ag:function ag(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.d=$
_.y=c
_.z=d
_.ay=e
_.ch=f
_.CW=g
_.cx=h},
c6:function c6(a,b,c){this.a=a
this.b=b
this.c=c},
cc:function cc(a,b,c,d,e,f,g,h,i){var _=this
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
ci:function ci(a){this.a=a},
ch:function ch(){},
cj:function cj(){},
cd:function cd(){},
ce:function ce(){},
cf:function cf(){},
cg:function cg(){},
ck:function ck(a){this.a=a},
fI(a,b,c){u.Z.a(a)
if(A.cP(c)>=1)return a.$1(b)
return a.$0()},
eq(a,b,c){A.el(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
ep(a,b,c){A.el(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.d6.prototype={}
J.by.prototype={
K(a,b){return a===b},
gt(a){return A.bO(a)},
j(a){return"Instance of '"+A.bP(a)+"'"},
gn(a){return A.a3(A.dk(this))}}
J.bA.prototype={
j(a){return String(a)},
gt(a){return a?519018:218159},
gn(a){return A.a3(u.y)},
$ik:1,
$iw:1}
J.aO.prototype={
K(a,b){return null==b},
j(a){return"null"},
gt(a){return 0},
$ik:1}
J.aQ.prototype={$it:1}
J.a8.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.bN.prototype={}
J.az.prototype={}
J.a6.prototype={
j(a){var t=a[$.ew()]
if(t==null)t=a[$.dt()]
if(t==null)return this.aU(a)
return"JavaScript function for "+J.bm(t)},
$iY:1}
J.aP.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.aR.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.l.prototype={
l(a,b){A.B(a).c.a(b)
a.$flags&1&&A.aH(a,29)
a.push(b)},
b6(a,b,c){var t,s,r,q,p
A.B(a).i("w(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.b(A.P(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
P(a,b){A.B(a).i("c<1>").a(b)
a.$flags&1&&A.aH(a,"addAll",2)
this.aX(a,b)
return},
aX(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.b(A.P(a))
for(s=0;s<t;++s)a.push(b[s])},
F(a){a.$flags&1&&A.aH(a,"clear","clear")
a.length=0},
aH(a,b,c){var t=A.B(a)
return new A.L(a,t.G(c).i("1(2)").a(b),t.i("@<1>").G(c).i("L<1,2>"))},
bn(a,b){var t,s=A.d9(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.u(s,t,A.r(a[t]))
return s.join(b)},
A(a,b){if(!(b>=0&&b<a.length))return A.j(a,b)
return a[b]},
gI(a){if(a.length>0)return a[0]
throw A.b(A.dF())},
ag(a,b){var t,s
A.B(a).i("w(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.b(A.P(a))}return!1},
an(a,b){var t,s,r,q
a.$flags&2&&A.aH(a,"shuffle")
t=a.length
while(t>1){s=b.br(t);--t
r=a.length
if(!(t<r))return A.j(a,t)
q=a[t]
if(!(s>=0&&s<r))return A.j(a,s)
a[t]=a[s]
a[s]=q}},
gC(a){return a.length===0},
gam(a){return a.length!==0},
j(a){return A.d4(a,"[","]")},
gv(a){return new J.af(a,a.length,A.B(a).i("af<1>"))},
gt(a){return A.bO(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.aH(a,"set length","change the length of")
if(b>a.length)A.B(a).c.a(null)
a.length=b},
h(a,b){if(!(b>=0&&b<a.length))throw A.b(A.cT(a,b))
return a[b]},
u(a,b,c){A.B(a).c.a(c)
a.$flags&2&&A.aH(a)
if(!(b>=0&&b<a.length))throw A.b(A.cT(a,b))
a[b]=c},
$ic:1,
$ih:1}
J.bz.prototype={
bC(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bP(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.co.prototype={}
J.af.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.W(r)
throw A.b(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$ia5:1}
J.at.prototype={
ah(a,b){var t
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gal(b)
if(this.gal(a)===t)return 0
if(this.gal(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gal(a){return a===0?1/a<0:a<0},
bc(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.b(A.df(""+a+".ceil()"))},
aj(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.b(A.df(""+a+".floor()"))},
bx(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.b(A.df(""+a+".round()"))},
p(a,b,c){if(this.ah(b,c)>0)throw A.b(A.ej(b))
if(this.ah(a,b)<0)return b
if(this.ah(a,c)>0)return c
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
a4(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
aA(a,b){var t
if(a>0)t=this.b8(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
b8(a,b){return b>31?0:a>>>b},
gn(a){return A.a3(u.H)},
$ie:1,
$iR:1}
J.aN.prototype={
gn(a){return A.a3(u.S)},
$ik:1,
$ia:1}
J.bB.prototype={
gn(a){return A.a3(u.i)},
$ik:1}
J.au.prototype={
a_(a,b,c){return a.substring(b,A.fc(b,c,a.length))},
aL(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.j(q,0)
if(q.charCodeAt(0)===133){t=J.f3(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.j(q,s)
r=q.charCodeAt(s)===133?J.f4(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
j(a){return a},
gt(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gn(a){return A.a3(u.N)},
gk(a){return a.length},
$ik:1,
$im:1}
A.a7.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.aI.prototype={
gk(a){return this.a.length},
h(a,b){var t=this.a
if(!(b>=0&&b<t.length))return A.j(t,b)
return t.charCodeAt(b)}}
A.cA.prototype={}
A.aL.prototype={}
A.A.prototype={
gv(a){var t=this
return new A.a_(t,t.gk(t),A.E(t).i("a_<A.E>"))},
gC(a){return this.gk(this)===0},
a2(a,b){var t,s,r,q=this
A.E(q).i("A.E(A.E,A.E)").a(b)
t=q.gk(q)
if(t===0)throw A.b(A.dF())
s=q.A(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.A(0,r))
if(t!==q.gk(q))throw A.b(A.P(q))}return s}}
A.b5.prototype={
gb_(){var t=J.T(this.a),s=this.c
if(s==null||s>t)return t
return s},
gba(){var t=J.T(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.T(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
A(a,b){var t=this,s=t.gba()+b
if(b<0||s>=t.gb_())throw A.b(A.d3(b,t.gk(0),t,"index"))
return J.dv(t.a,s)},
bB(a,b){var t,s,r,q=this,p=q.b,o=q.a,n=J.aF(o),m=n.gk(o),l=q.c
if(l!=null&&l<m)m=l
t=m-p
if(t<=0){o=q.$ti.c
return b?J.dH(0,o):J.dG(0,o)}s=A.d9(t,n.A(o,p),b,q.$ti.c)
for(r=1;r<t;++r){B.a.u(s,r,n.A(o,p+r))
if(n.gk(o)<m)throw A.b(A.P(q))}return s},
aK(a){return this.bB(0,!0)}}
A.a_.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t,s=this,r=s.a,q=J.aF(r),p=q.gk(r)
if(s.b!==p)throw A.b(A.P(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.A(r,t);++s.c
return!0},
$ia5:1}
A.L.prototype={
gk(a){return J.T(this.a)},
A(a,b){return this.b.$1(J.dv(this.a,b))}}
A.b9.prototype={
gv(a){return new A.ba(J.d2(this.a),this.b,this.$ti.i("ba<1>"))}}
A.ba.prototype={
m(){var t,s
for(t=this.a,s=this.b;t.m();)if(s.$1(t.gq()))return!0
return!1},
gq(){return this.a.gq()},
$ia5:1}
A.z.prototype={}
A.b7.prototype={}
A.aA.prototype={}
A.bg.prototype={$r:"+(1,2)",$s:1}
A.aJ.prototype={
gC(a){return this.gk(this)===0},
j(a){return A.da(this)},
$iV:1}
A.aK.prototype={
gk(a){return this.b.length},
gb1(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
H(a){if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.H(b))return null
return this.b[this.a[b]]},
L(a,b){var t,s,r,q
this.$ti.i("~(1,2)").a(b)
t=this.gb1()
s=this.b
for(r=t.length,q=0;q<r;++q)b.$2(t[q],s[q])}}
A.bx.prototype={
K(a,b){if(b==null)return!1
return b instanceof A.ah&&this.a.K(0,b.a)&&A.dp(this)===A.dp(b)},
gt(a){return A.dO(this.a,A.dp(this),B.e,B.e)},
j(a){var t=B.a.bn([A.a3(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.ah.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hm(A.cS(this.a),this.$ti)}}
A.cy.prototype={
$0(){return B.b.aj(1000*this.a.now())},
$S:1}
A.b2.prototype={}
A.cD.prototype={
D(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
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
A.b_.prototype={
j(a){return"Null check operator used on a null value"}}
A.bC.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bV.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.cw.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.y.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.eu(s==null?"unknown":s)+"'"},
$iY:1,
gbH(){return this},
$C:"$1",
$R:1,
$D:null}
A.bp.prototype={$C:"$0",$R:0}
A.bq.prototype={$C:"$2",$R:2}
A.bT.prototype={}
A.bS.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.eu(t)+"'"}}
A.as.prototype={
K(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.as))return!1
return this.$_target===b.$_target&&this.a===b.a},
gt(a){return(A.er(this.a)^A.bO(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bP(this.a)+"'")}}
A.bR.prototype={
j(a){return"RuntimeError: "+this.a}}
A.Z.prototype={
gk(a){return this.a},
gC(a){return this.a===0},
gM(){return new A.ai(this,A.E(this).i("ai<1>"))},
H(a){var t=this.b
if(t==null)return!1
return t[a]!=null},
P(a,b){A.E(this).i("V<1,2>").a(b).L(0,new A.cp(this))},
h(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.bl(b)},
bl(a){var t,s,r=this.d
if(r==null)return null
t=r[this.aC(a)]
s=this.aD(t,a)
if(s<0)return null
return t[s].b},
u(a,b,c){var t,s,r=this,q=A.E(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.ao(t==null?r.b=r.ae():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.ao(s==null?r.c=r.ae():s,b,c)}else r.bm(b,c)},
bm(a,b){var t,s,r,q,p=this,o=A.E(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.ae()
s=p.aC(a)
r=t[s]
if(r==null)t[s]=[p.a8(a,b)]
else{q=p.aD(r,a)
if(q>=0)r[q].b=b
else r.push(p.a8(a,b))}},
L(a,b){var t,s,r=this
A.E(r).i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.b(A.P(r))
t=t.c}},
ao(a,b,c){var t,s=A.E(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.a8(b,c)
else t.b=c},
a8(a,b){var t=this,s=A.E(t),r=new A.ct(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
aC(a){return J.K(a)&1073741823},
aD(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.O(a[s].a,b))return s
return-1},
j(a){return A.da(this)},
ae(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$idK:1}
A.cp.prototype={
$2(a,b){var t=this.a,s=A.E(t)
t.u(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.E(this.a).i("~(1,2)")}}
A.ct.prototype={}
A.ai.prototype={
gk(a){return this.a.a},
gC(a){return this.a.a===0},
gv(a){var t=this.a
return new A.aU(t,t.r,t.e,this.$ti.i("aU<1>"))},
U(a,b){return this.a.H(b)}}
A.aU.prototype={
gq(){return this.d},
m(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.b(A.P(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$ia5:1}
A.cW.prototype={
$1(a){return this.a(a)},
$S:2}
A.cX.prototype={
$2(a,b){return this.a(a,b)},
$S:5}
A.cY.prototype={
$1(a){return this.a(A.ac(a))},
$S:6}
A.al.prototype={
j(a){return this.aB(!1)},
aB(a){var t,s,r,q,p,o=this.b0(),n=this.av(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.j(n,r)
p=n[r]
m=a?m+A.dQ(p):m+A.r(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
b0(){var t,s=this.$s
while($.cL.length<=s)B.a.l($.cL,null)
t=$.cL[s]
if(t==null){t=this.aY()
B.a.u($.cL,s,t)}return t},
aY(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=u.K,k=J.d5(m,l)
for(t=0;t<m;++t)k[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.u(k,r,s[t])}}k=A.dM(k,!1,l)
k.$flags=3
return k}}
A.aB.prototype={
av(){return[this.a,this.b]},
K(a,b){if(b==null)return!1
return b instanceof A.aB&&this.$s===b.$s&&J.O(this.a,b.a)&&J.O(this.b,b.b)},
gt(a){return A.dO(this.$s,this.a,this.b,B.e)}}
A.cF.prototype={
O(){var t=this.b
if(t===this)throw A.b(new A.a7("Local '' has not been initialized."))
return t}}
A.av.prototype={
gn(a){return B.T},
$ik:1}
A.aX.prototype={}
A.bE.prototype={
gn(a){return B.U},
$ik:1}
A.aw.prototype={
gk(a){return a.length},
$iG:1}
A.aV.prototype={
h(a,b){A.am(b,a,a.length)
return a[b]},
$ic:1,
$ih:1}
A.aW.prototype={$ic:1,$ih:1}
A.bF.prototype={
gn(a){return B.V},
$ik:1}
A.bG.prototype={
gn(a){return B.W},
$ik:1}
A.bH.prototype={
gn(a){return B.X},
h(a,b){A.am(b,a,a.length)
return a[b]},
$ik:1}
A.bI.prototype={
gn(a){return B.Y},
h(a,b){A.am(b,a,a.length)
return a[b]},
$ik:1}
A.bJ.prototype={
gn(a){return B.Z},
h(a,b){A.am(b,a,a.length)
return a[b]},
$ik:1}
A.bK.prototype={
gn(a){return B.a0},
h(a,b){A.am(b,a,a.length)
return a[b]},
$ik:1}
A.bL.prototype={
gn(a){return B.a1},
h(a,b){A.am(b,a,a.length)
return a[b]},
$ik:1}
A.aY.prototype={
gn(a){return B.a2},
gk(a){return a.length},
h(a,b){A.am(b,a,a.length)
return a[b]},
$ik:1}
A.bM.prototype={
gn(a){return B.a3},
gk(a){return a.length},
h(a,b){A.am(b,a,a.length)
return a[b]},
$ik:1}
A.bc.prototype={}
A.bd.prototype={}
A.be.prototype={}
A.bf.prototype={}
A.Q.prototype={
i(a){return A.bl(v.typeUniverse,this,a)},
G(a){return A.e7(v.typeUniverse,this,a)}}
A.bX.prototype={}
A.cM.prototype={
j(a){return A.C(this.a,null)}}
A.bW.prototype={
j(a){return this.a}}
A.aC.prototype={}
A.bb.prototype={
gv(a){var t=this,s=new A.aj(t,t.r,t.$ti.i("aj<1>"))
s.c=t.e
return s},
gk(a){return this.a},
U(a,b){var t
if((b&1073741823)===b){t=this.c
if(t==null)return!1
return u.L.a(t[b])!=null}else return this.aZ(b)},
aZ(a){var t=this.d
if(t==null)return!1
return this.au(t[B.c.gt(a)&1073741823],a)>=0},
l(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.ap(t==null?r.b=A.dg():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.ap(s==null?r.c=A.dg():s,b)}else return r.aW(b)},
aW(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.dg()
s=J.K(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.af(a)]
else{if(q.au(r,a)>=0)return!1
r.push(q.af(a))}return!0},
F(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.aw()}},
ap(a,b){this.$ti.c.a(b)
if(u.L.a(a[b])!=null)return!1
a[b]=this.af(b)
return!0},
aw(){this.r=this.r+1&1073741823},
af(a){var t,s=this,r=new A.c_(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.aw()
return r},
au(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.O(a[s].a,b))return s
return-1}}
A.c_.prototype={}
A.aj.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.b(A.P(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.i("1?").a(s.a)
t.c=s.b
return!0}},
$ia5:1}
A.i.prototype={
gv(a){return new A.a_(a,this.gk(a),A.ae(a).i("a_<i.E>"))},
A(a,b){return this.h(a,b)},
gC(a){return this.gk(a)===0},
gam(a){return this.gk(a)!==0},
ag(a,b){var t,s
A.ae(a).i("w(i.E)").a(b)
t=this.gk(a)
for(s=0;s<t;++s){if(b.$1(this.h(a,s)))return!0
if(t!==this.gk(a))throw A.b(A.P(a))}return!1},
aH(a,b,c){var t=A.ae(a)
return new A.L(a,t.G(c).i("1(i.E)").a(b),t.i("@<i.E>").G(c).i("L<1,2>"))},
j(a){return A.d4(a,"[","]")},
$ic:1,
$ih:1}
A.H.prototype={
L(a,b){var t,s,r,q=A.E(this)
q.i("~(H.K,H.V)").a(b)
for(t=this.gM(),t=t.gv(t),q=q.i("H.V");t.m();){s=t.gq()
r=this.h(0,s)
b.$2(s,r==null?q.a(r):r)}},
H(a){return this.gM().U(0,a)},
gk(a){var t=this.gM()
return t.gk(t)},
gC(a){var t=this.gM()
return t.gC(t)},
j(a){return A.da(this)},
$iV:1}
A.cu.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.r(a)
s.a=(s.a+=t)+": "
t=A.r(b)
s.a+=t},
$S:3}
A.ax.prototype={
P(a,b){var t,s,r
this.$ti.i("c<1>").a(b)
for(t=A.fm(b,b.r,b.$ti.c),s=t.$ti.c;t.m();){r=t.d
this.l(0,r==null?s.a(r):r)}},
j(a){return A.d4(this,"{","}")},
$ic:1,
$idd:1}
A.bh.prototype={}
A.bY.prototype={
h(a,b){var t,s=this.b
if(s==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.b4(b):t}},
gk(a){return this.b==null?this.c.a:this.a0().length},
gC(a){return this.gk(0)===0},
gM(){if(this.b==null){var t=this.c
return new A.ai(t,A.E(t).i("ai<1>"))}return new A.bZ(this)},
H(a){if(this.b==null)return this.c.H(a)
return Object.prototype.hasOwnProperty.call(this.a,a)},
L(a,b){var t,s,r,q,p=this
u.D.a(b)
if(p.b==null)return p.c.L(0,b)
t=p.a0()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.cQ(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.b(A.P(p))}},
a0(){var t=u._.a(this.c)
if(t==null)t=this.c=A.n(Object.keys(this.a),u.s)
return t},
b4(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.cQ(this.a[a])
return this.b[a]=t}}
A.bZ.prototype={
gk(a){return this.a.gk(0)},
A(a,b){var t=this.a
if(t.b==null)t=t.gM().A(0,b)
else{t=t.a0()
if(!(b>=0&&b<t.length))return A.j(t,b)
t=t[b]}return t},
gv(a){var t=this.a
if(t.b==null){t=t.gM()
t=t.gv(t)}else{t=t.a0()
t=new J.af(t,t.length,A.B(t).i("af<1>"))}return t},
U(a,b){return this.a.H(b)}}
A.br.prototype={}
A.bt.prototype={}
A.aS.prototype={
j(a){var t=A.bv(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.bD.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.cq.prototype={
bf(a,b){var t=A.h3(a,this.gbg().a)
return t},
bi(a,b){var t=A.fl(a,this.gbj().b,null)
return t},
gbj(){return B.N},
gbg(){return B.M}}
A.cs.prototype={}
A.cr.prototype={}
A.cJ.prototype={
aN(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.d.a_(a,s,r)
s=r+1
p=A.x(92)
t.a+=p
p=A.x(117)
t.a+=p
p=A.x(100)
t.a+=p
p=q>>>8&15
p=A.x(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.x(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.x(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.d.a_(a,s,r)
s=r+1
p=A.x(92)
t.a+=p
switch(q){case 8:p=A.x(98)
t.a+=p
break
case 9:p=A.x(116)
t.a+=p
break
case 10:p=A.x(110)
t.a+=p
break
case 12:p=A.x(102)
t.a+=p
break
case 13:p=A.x(114)
t.a+=p
break
default:p=A.x(117)
t.a+=p
p=A.x(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.x(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.x(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.d.a_(a,s,r)
s=r+1
p=A.x(92)
t.a+=p
p=A.x(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.d.a_(a,s,n)},
aa(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.b(new A.bD(a,null))}B.a.l(t,a)},
a3(a){var t,s,r,q,p=this
if(p.aM(a))return
p.aa(a)
try{t=p.b.$1(a)
if(!p.aM(t)){r=A.dJ(a,null,p.gaz())
throw A.b(r)}r=p.a
if(0>=r.length)return A.j(r,-1)
r.pop()}catch(q){s=A.ev(q)
r=A.dJ(a,s,p.gaz())
throw A.b(r)}},
aM(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.aN(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.aa(a)
r.bF(a)
t=r.a
if(0>=t.length)return A.j(t,-1)
t.pop()
return!0}else if(u.f.b(a)){r.aa(a)
s=r.bG(a)
t=r.a
if(0>=t.length)return A.j(t,-1)
t.pop()
return s}else return!1},
bF(a){var t,s,r=this.c
r.a+="["
t=J.aF(a)
if(t.gam(a)){this.a3(t.h(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.a3(t.h(a,s))}}r.a+="]"},
bG(a){var t,s,r,q,p,o,n=this,m={}
if(a.gC(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.d9(t,null,!1,u.X)
r=m.a=0
m.b=!0
a.L(0,new A.cK(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.aN(A.ac(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.j(s,o)
n.a3(s[o])}q.a+="}"
return!0}}
A.cK.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.u(t,s.a++,a)
B.a.u(t,s.a++,b)},
$S:3}
A.cI.prototype={
gaz(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.q.prototype={}
A.bn.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bv(t)
return"Assertion failed"}}
A.b6.prototype={}
A.X.prototype={
gac(){return"Invalid argument"+(!this.a?"(s)":"")},
gab(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+A.r(q),o=t.gac()+r+p
if(!t.a)return o
return o+t.gab()+": "+A.bv(t.gak())},
gak(){return this.b}}
A.b0.prototype={
gak(){return A.p(this.b)},
gac(){return"RangeError"},
gab(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.r(r):""
else if(r==null)t=": Not greater than or equal to "+A.r(s)
else if(r>s)t=": Not in inclusive range "+A.r(s)+".."+A.r(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.r(s)
return t}}
A.bw.prototype={
gak(){return A.cP(this.b)},
gac(){return"RangeError"},
gab(){if(A.cP(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.b8.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bU.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.b4.prototype={
j(a){return"Bad state: "+this.a}}
A.bs.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bv(t)+"."}}
A.b3.prototype={
j(a){return"Stack Overflow"},
$iq:1}
A.F.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.c.prototype={
gk(a){var t,s=this.gv(this)
for(t=0;s.m();)++t
return t},
A(a,b){var t,s
A.db(b,"index")
t=this.gv(this)
for(s=b;t.m();){if(s===0)return t.gq();--s}throw A.b(A.d3(b,b-s,this,"index"))},
j(a){return A.f1(this,"(",")")}}
A.aZ.prototype={
gt(a){return A.o.prototype.gt.call(this,0)},
j(a){return"null"}}
A.o.prototype={$io:1,
K(a,b){return this===b},
gt(a){return A.bO(this)},
j(a){return"Instance of '"+A.bP(this)+"'"},
gn(a){return A.hg(this)},
toString(){return this.j(this)}}
A.cC.prototype={}
A.ay.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$iff:1}
A.cl.prototype={}
A.bu.prototype={
V(){var t=this
return A.U(["areaMultiplier",t.a,"aspects",t.b,"angleMinDeg",t.c,"angleMaxDeg",t.d,"speedMin",t.e,"speedMax",t.f,"accelMin",t.r,"accelMax",t.w,"collideWithEachOther",t.x,"spinDegPerSec",t.y],u.N,u.z)}}
A.c5.prototype={
$1(a){return A.a2(a)},
$S:7}
A.cx.prototype={
V(){return A.U(["size",this.a,"showFace",this.b],u.N,u.z)}}
A.ca.prototype={
V(){var t,s=this,r=A.f8(u.N,u.z)
r.u(0,"borderWidth",s.a)
r.u(0,"brightness",s.b)
r.u(0,"shadowBrightness",s.c)
t=s.d
if(t!=null&&t.length!==0)r.u(0,"color",t)
return r}}
A.cb.prototype={
V(){var t=this
return A.U(["startHintEnabled",t.a,"idleSpeedMultiplier",t.b,"idleEnemiesMove",t.c,"speedRampSeconds",t.d,"jumpEnabled",t.e,"jumpDurationSec",t.f,"jumpCooldownSec",t.r,"jumpScale",t.w,"helmetEnabled",t.x,"helmetInvulnSec",t.y,"helmetCooldownSec",t.z,"startInvulnSec",t.Q,"heartbeatHaptic",t.as,"timerHaptic",t.at,"timerHapticStyle",t.ax,"timerHapticStyle5",t.ay,"timerHapticStyle10",t.ch,"hudSpeedScaleMax",t.CW,"wallsKillPlayer",t.cx],u.N,u.z)}}
A.c3.prototype={
V(){return A.U(["sfxMobWall",!0,"sfxMobCollide",!0,"sfxHeroMob",!0,"sfxHeroWall",!0,"sfxNearMiss",!0,"sfxHelmet",!0,"sfxJump",!0,"sfxStart",!0,"music",!0,"sfxVolume",1,"musicVolume",0.08],u.N,u.z)}}
A.cv.prototype={}
A.c7.prototype={
aV(a){var t=this,s=u.f.b(a)?a:B.O,r=new A.c9(s),q=new A.c8(s),p=A.dj(q.$1("brakeEnabled"))
t.a!==$&&A.a4()
t.a=p
q=A.dj(q.$1("speedBarEnabled"))
t.b!==$&&A.a4()
t.b=q
q=A.a1(r.$4("initialSpeed",0,0,150))
t.c!==$&&A.a4()
t.c=q
q=A.a1(r.$4("growthMultiplier",70,0,200))
t.d!==$&&A.a4()
t.d=q
q=A.a1(r.$4("growthExponent",0.2,0.01,1))
t.e!==$&&A.a4()
t.e=q
q=A.a1(r.$4("startSmoothingSec",3,0.01,60))
t.f!==$&&A.a4()
t.f=q
q=A.a1(r.$4("initialCompensation",1,0,10))
t.r!==$&&A.a4()
t.r=q
q=A.a1(r.$4("brakeCooldownSec",6,0.1,120))
t.w!==$&&A.a4()
t.w=q
q=A.a1(r.$4("brakeFirstReadySec",6,0.1,120))
t.x!==$&&A.a4()
t.x=q
r=A.a1(r.$4("brakeRewindSec",6,0,120))
t.y!==$&&A.a4()
t.y=r
t.as=q},
a6(a){var t,s,r,q,p=this,o=p.c
o===$&&A.f()
t=p.d
t===$&&A.f()
s=Math.max(0,a)
r=p.f
r===$&&A.f()
q=p.e
q===$&&A.f()
q=Math.pow(s+r,q)
r=p.r
r===$&&A.f()
return Math.max(0,o+t*(q-r))},
gY(){var t=this
return t.a6(t.Q)+t.ay*B.b.p(1-(t.z-t.at)/0.18,0,1)},
gX(){var t=this.a
t===$&&A.f()
return t&&this.z+1e-9>=this.as},
bt(){var t,s,r=this
if(!r.gX())return!1
r.ch=r.gY()
t=r.Q
s=r.y
s===$&&A.f()
s=Math.max(0,t-s)
r.Q=s
s=r.a6(s)
r.CW=s
r.ay=Math.max(0,r.ch-s)
s=r.z
r.at=s
t=r.w
t===$&&A.f()
r.as=s+t;++r.cx
return!0},
bu(a,b,c,d,e,f){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this.a
g===$&&A.f()
if(!g||!this.gX()||!c)return!1
t=d/2
for(g=u.t,g=[A.n([a+t,e+t],g),A.n([b+t,f+t],g)],s=190-d,r=190+d,q=0,p=1,o=0;o<2;++o){n=g[o]
if(1>=n.length)return A.j(n,1)
m=n[1]
l=n[0]
k=m-l
if(Math.abs(k)<1e-9){if(l<=s||l>=r)return!1}else{j=(s-l)/k
i=(r-l)/k
if(j>i){h=i
i=j
j=h}q=Math.max(q,j)
p=Math.min(p,i)}}return q<=p&&this.bt()}}
A.c9.prototype={
$4(a,b,c,d){var t=this.a.h(0,a)
if(t==null)t=b
if(typeof t!="number"||!isFinite(t)||t<c||t>d)throw A.b(A.aM("enemy_pace_"+a))
return t},
$S:8}
A.c8.prototype={
$1(a){var t=this.a,s=!t.H(a)||t.h(0,a)
if(!A.cR(s))throw A.b(A.aM("enemy_pace_"+a))
return s},
$S:9}
A.d.prototype={
J(a,b){return new A.d(this.a+b.a,this.b+b.b)},
Z(a,b){return new A.d(this.a-b.a,this.b-b.b)},
a5(a,b){return new A.d(this.a*b,this.b*b)},
aO(a,b){return new A.d(this.a/b,this.b/b)},
gbh(){var t=this.a,s=this.b
return Math.sqrt(t*t+s*s)}}
A.cB.prototype={}
A.I.prototype={
gT(){var t=this
return new A.d((t.a+t.c)/2,(t.b+t.d)/2)},
W(a){var t=this
return t.a<a.c&&t.c>a.a&&t.b<a.d&&t.d>a.b}}
A.cm.prototype={
bb(a){var t,s=this
if(!isFinite(a)||a<s.d)throw A.b(A.dw(a,"nowMs",null))
s.d=a
t=!1
if(!s.c)if(s.a){t=s.e
t=t!=null&&a>=t}if(t){s.c=!0
s.e=null
return!0}return!1},
be(){var t,s=this
if(!s.c)return!1
s.c=!1
t=s.b
s.e=t>0?s.d+t:null
return!0}}
A.d_.prototype={
$1(c2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9=null,c0="events",c1="startPose"
A.ac(c2)
try{m=u.c
t=m.a(B.n.bf(c2,b9))
s=J.ar(t,"proof")
l=!0
if(u.f.b(s))if(J.O(s.h(0,"version"),3)){l=u.j
l=!l.b(s.h(0,c0))||J.T(l.a(s.h(0,c0)))>6e5||!l.b(s.h(0,c1))}if(l)throw A.b(B.G)
l=u.N
k=u.z
j=A.f7(l,k)
j.P(0,t)
r=j
J.eJ(r,c1,s.h(0,c1))
r=r
i=new A.cn(A.n([],u.U))
c2=m.a(r.h(0,"config"))
i.a=A.eW(c2.h(0,"enemyPace"))
h=A.eV(m.a(c2.h(0,"enemies")))
j=m.a(c2.h(0,"player"))
g=A.p(j.h(0,"size"))
if(g==null)g=b9
if(g==null){g=A.p(j.h(0,"playerSize"))
if(g==null)g=b9}if(g==null)g=36
f=A.N(j.h(0,"showFace"))
j=f==null?A.N(j.h(0,"playerShowFace")):f
f=m.a(c2.h(0,"field"))
e=f.h(0,"color")
d=e==null?f.h(0,"colorHex"):e
if(d==null)d=f.h(0,"surfaceColor")
c=typeof d=="string"&&B.d.aL(d).length!==0?B.d.aL(d):b9
e=A.p(f.h(0,"borderWidth"))
if(e==null)e=b9
if(e==null)e=3
b=A.p(f.h(0,"brightness"))
if(b==null)b=b9
if(b==null){b=A.p(f.h(0,"fieldBrightness"))
if(b==null)b=b9}if(b==null)b=1
f=A.p(f.h(0,"shadowBrightness"))
if(f==null)f=b9
if(f==null)f=1
a=A.dD(m.a(c2.h(0,"game")))
m=m.a(c2.h(0,"mobileEnemies"))
a0=m.h(0,"startSpeedSteps")
a1=m.h(0,"accelerationSteps")
if(typeof a0!="number"||typeof a1!="number"||!isFinite(a0)||!isFinite(a1)||a0<0.01||a0>250||a1<0||a1>50)A.D(B.E)
a2=A.dN(m.h(0,"speedVariation"),0.05)
m=A.dN(m.h(0,"accelerationVariation"),0.08)
a3=g*1.2
a4=Math.max(0.000001,(a3===0?36:a3)*0.1)
a5=a0*a4
a6=a1*a4
a7=a.V()
a7.u(0,"speedRampSeconds",0)
a=A.dD(a7)
m=new A.cl(new A.bu(h.a,h.b,h.c,h.d,a5*(1-a2),a5*(1+a2),a6*(1-m),a6*(1+m),h.x,h.y),new A.cx(g,j===!0),new A.ca(e,b,f,c),a,B.t,new A.cv(a0,a1,a2,m),b9)
i.b=m
a2=A.fd(A.ac(r.h(0,"requestId")))
e/=2
f=B.b.p(e+0.5,0.5,12)
b=A.n([],u.v)
j=new A.cC()
$.ex()
g=$.dR.$0()
j.a=g
j.b=null
g=A.n([],u.l)
a8=u.S
a9=A.d8(a8)
a8=A.d8(a8)
m=new A.cc(m,B.A,new A.bQ(a2),f+e,b,j,g,a9,a8)
a3=(380-a3)/2
m.e=new A.d(a3,a3)
B.a.F(g)
a9.F(0)
a8.F(0)
B.a.F(b)
B.a.P(b,m.b9())
i.c=m
b=J.O(r.h(0,"hadHelmet"),!0)
a8=a.z
i.d=new A.cm(b,isFinite(a8)&&a8>0?B.b.p(a8,0,3600)*1000:0,b)
i.e=J.O(r.h(0,"hadJump"),!0)
if(r.h(0,c1)!=null)m.bw(r.h(0,c1))
i.f=Math.max(0,a.Q)
q=i
r=q
if(r.x||r.y)A.D(A.dT("start"))
m=r.c
m===$&&A.f()
m.aS()
m.gaT()
r.at=r.as=0
r.x=!0
for(r=J.d2(u.R.a(s.h(0,c0))),m=u.j,j=u.a;r.m();){p=r.gq()
if(!m.b(p)||J.eK(p))throw A.b(B.o)
if(J.O(J.ar(p,0),2)){if(J.T(p)!==1)throw A.b(B.p)
o=q.ax
q.bo()
g=q.ax
f=o
if(typeof f!=="number")return f.J()
if(g!==f+1)throw A.b(B.p)}else{if(!(J.O(J.ar(p,0),0)&&J.T(p)!==2))g=J.O(J.ar(p,0),1)&&J.T(p)!==3
else g=!0
if(g)throw A.b(B.o)
g=q
f=p
e=g.c
e===$&&A.f()
b=e.e
b===$&&A.f()
if(!g.x||g.y||g.ay.length>=6e5)A.D(A.dT("event"))
a=J.ao(f)
if(J.O(a.h(f,0),0)){b0=A.a2(a.h(f,1))
if(!isFinite(b0)||b0<=0||b0>50||g.w+b0>36e5)A.D(A.aM("tick"))
B.a.l(g.ay,A.n([0,b0],j))
f=g.w+=b0
a=g.d
a===$&&A.f()
a.bb(f)
b1=b0/1000
f=g.a
f.z+=b1
f.Q+=b1
e.by(b1)
f=g.w
a=g.f
a===$&&A.f()
a=a>0||g.r>0
a2=g.a.gY()
b2=e.bA(b1,f/1000,!a,a2*(e.a.b.a*1.2)*0.1)
g.as=b2.a
g.at=b2.b
g.f=Math.max(0,g.f-b1)
g.r=Math.max(0,g.r-b1)}else if(J.O(a.h(f,0),1)){b3=A.a2(a.h(f,1))
b4=A.a2(a.h(f,2))
if(!isFinite(b3)||!isFinite(b4)||Math.abs(b3)>2000||Math.abs(b4)>2000)A.D(A.aM("move"))
B.a.l(g.ay,A.n([1,b3,b4],j))
f=g.f
f===$&&A.f()
f=f>0||g.r>0
e.bp(new A.d(b3,b4),!f)}else A.D(A.aM("event"))
f=e.a
if(!f.d.cx&&e.aJ()){b5=e.d
b6=Math.max(b5,380-b5-f.b.a*1.2)
a=e.e
a===$&&A.f()
e.e=new A.d(B.b.p(a.a,b5,b6),B.b.p(e.e.b,b5,b6))}g.bd()
if(!g.y){g=g.a
a=e.e
a===$&&A.f()
g.bu(b.a,b.b,!(e.r>0),f.b.a*1.2,a.a,a.b)}}}if(!q.y)throw A.b(B.I)
n=q.gaR()
b7=B.n.bi(A.U(["ok",!0,"timeMs",J.ar(n,"timeMs"),"runDistance",J.ar(n,"runDistance"),"riskCount",J.ar(n,"riskCount")],l,k),b9)
return b7}catch(b8){return'{"ok":false}'}},
$S:10}
A.bQ.prototype={
b2(){var t=this.a
t^=t<<13
t^=t>>>17
return this.a=(t^t<<5)>>>0},
E(){var t=this.a
t^=t<<13
t^=t>>>17
t=(t^t<<5)>>>0
this.a=t
return t/4294967296},
br(a){if(a<=0)throw A.b(A.dw(a,null,null))
return B.b.aj(this.b2()/4294967296*a)},
$ifb:1}
A.cn.prototype={
gaE(){var t=this.f
t===$&&A.f()
return t>0||this.r>0},
bd(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
if(e.gaE())return
t=e.c
t===$&&A.f()
s=t.a.d.cx&&t.aJ()
r=!s
if(r&&!t.bs())return
e.z=s
q=t.e
q===$&&A.f()
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
i=m}}else{h=new A.I(p,q,p+o,q+o)
q=t.f
p=q.length
g=0
for(;;){if(!(g<q.length)){j=l
i=m
break}f=q[g]
if(h.W(f.gB())){q=f.gB()
i=(m+(q.a+q.c)/2)/2
q=f.gB()
j=(l+(q.b+q.d)/2)/2
break}q.length===p||(0,A.W)(q);++g}}e.Q=A.U(["x",i,"y",j],u.N,u.i)
q=e.d
q===$&&A.f()
if(q.c){q.be()
q=e.b
q===$&&A.f()
e.r=Math.max(0,q.d.y)
if(r)t.bv()}else{e.y=!0
e.x=!1}},
bo(){var t,s=this,r=!0
if(s.x){t=s.e
t===$&&A.f()
if(t){r=s.c
r===$&&A.f()
r=!r.bD(s.w)}}if(r)return;++s.ax
B.a.l(s.ay,A.n([2],u.a))},
gaR(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=this,a7=a6.a,a8=a7.a
a8===$&&A.f()
t=a7.b
t===$&&A.f()
s=a7.Q
r=a7.gY()
q=a7.a6(a7.Q)
if(!a8)p=0
else if(a7.gX())p=1
else{p=a7.z
o=a7.cx===0
n=o?0:a7.at
if(o){o=a7.x
o===$&&A.f()}else{o=a7.w
o===$&&A.f()}o=B.b.p((p-n)/o,0,1)
p=o}o=a7.gX()
n=a7.cx
m=n===0?-1:(a7.z-a7.at)*1000
l=a7.gX()?(a7.z-a7.as)*1000:-1
a7=A.U(["enabled",a8,"speedBarEnabled",t,"effectiveSec",s,"speed",r,"targetSpeed",q,"charge",p,"ready",o,"presses",n,"pressAgeMs",m,"readyAgeMs",l,"beforeSpeed",a7.ch,"afterSpeed",a7.CW],u.N,u.z)
a8=a6.x
t=a6.y
s=B.b.aj(a6.w)
r=a6.c
r===$&&A.f()
q=B.b.bx(Math.max(0,r.y/Math.max(0.000001,r.a.b.a*1.2*0.1)))
p=r.z
o=a6.d
o===$&&A.f()
o=o.c
n=a6.gaE()
m=r.aF(a6.w)
l=a6.ax
k=a6.e
k===$&&A.f()
if(k){k=a6.b
k===$&&A.f()
k=k.d.e}else k=!1
j=r.r
i=r.e
i===$&&A.f()
h=u.N
g=u.i
i=A.U(["x",i.a,"y",i.b,"size",r.a.b.a*1.2,"visualScale",r.gbE(),"jumpLift",r.gaG()],h,g)
f=u.O
e=A.n([],f)
for(d=r.f,c=d.length,b=0;b<d.length;d.length===c||(0,A.W)(d),++b){a=d[b]
a0=a.a
a1=a.CW
a2=a6.a.gY()
e.push(A.U(["x",a0.a,"y",a0.b,"w",a.y,"h",a.z,"angle",a1,"speed",a2*(r.a.b.a*1.2)*0.1],h,g))}d=a6.as
c=a6.at
a0=a6.z
a1=a6.Q
a2=r.gbk()
f=A.n([],f)
for(r=r.Q,a3=r.length,b=0;b<r.length;r.length===a3||(0,A.W)(r),++b){a4=r[b]
a5=a4.a
f.push(A.U(["x",a5.a,"y",a5.b,"age",a4.b],h,g))}return A.U(["brake",a7,"playing",a8,"dead",t,"timeMs",s,"runDistance",q,"riskCount",p,"helmet",o,"invulnerable",n,"jumpCooldownMs",m,"jumpCount",l,"jumpEnabled",k,"jumpRemainingMs",j*1000,"player",i,"enemies",e,"wallBounces",d,"enemyBounces",c,"againstWall",a0,"impactOrigin",a1,"startled",a2,"nearMissFx",f],h,u.z)}}
A.c4.prototype={}
A.a9.prototype={}
A.ag.prototype={
gT(){var t=this.a
return new A.d(t.a+this.y*0.5,t.b+this.z*0.5)},
aQ(a){this.a=new A.d(a.a-this.y*0.5,a.b-this.z*0.5)},
gR(){var t=this.CW*3.141592653589793/180
return new A.d(Math.cos(t),Math.sin(t))},
gS(){var t=this.CW*3.141592653589793/180
return new A.d(-Math.sin(t),Math.cos(t))},
gai(){var t=this,s=t.y*0.5,r=t.z*0.5,q=new A.c6(t.gT(),t.gR(),t.gS()),p=-s,o=-r
return A.n([q.$2(p,o),q.$2(s,o),q.$2(s,r),q.$2(p,r)],u.M)},
gB(){var t,s,r,q,p=this.gai(),o=B.a.gI(p).a,n=B.a.gI(p).a,m=B.a.gI(p).b,l=B.a.gI(p).b
for(t=0;t<4;++t){s=p[t]
r=s.a
if(r<o)o=r
if(r>n)n=r
q=s.b
if(q<m)m=q
if(q>l)l=q}return new A.I(o,m,n,l)},
a1(a){var t=this,s=t.gT(),r=t.gR(),q=t.gS(),p=a.a,o=a.b,n=s.a*p+s.b*o,m=t.y*0.5*Math.abs(p*r.a+o*r.b)+t.z*0.5*Math.abs(p*q.a+o*q.b)
return new A.bg(n-m,n+m)},
a7(a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
for(t=[B.f,B.h,this.gR(),this.gS()],s=a1.a,r=a1.c,q=(s+r)/2,p=a1.b,o=a1.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,o=a2.a,r=a2.b,m=0,l=1,k=0;k<4;++k){j=t[k]
i=this.a1(j)
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
aI(a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[B.f,B.h,b.gR(),b.gS()],a0=a3.gT(),a1=(a3.c-a3.a)*0.5,a2=(a3.d-a3.b)*0.5
for(t=a0.a,s=a0.b,r=b.y*0.5,q=b.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.d(l,k)
g=b.a1(h)
f=t*l+s*k
e=a1*Math.abs(l)+a2*Math.abs(k)
d=Math.min(g.b,f+e)-Math.max(g.a,f-e)
if(d<=0)return null
if(d<p){c=b.a
o=(c.a+r-t)*l+(c.b+q-s)*k>=0?h:new A.d(-l,-k)
p=d}}if(o==null)return null
return o.a5(0,p+0.5)},
bq(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[b.gR(),b.gS(),a0.gR(),a0.gS()]
for(t=b.y*0.5,s=a0.y*0.5,r=b.z*0.5,q=a0.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.d(l,k)
g=b.a1(h)
f=a0.a1(h)
e=Math.min(g.b,f.b)-Math.max(g.a,f.a)
if(e<=0)return null
if(e<p){d=b.a
c=a0.a
o=(d.a+t-(c.a+s))*l+(d.b+r-(c.b+q))*k>=0?h:new A.d(-l,-k)
p=e}}if(o==null)return null
return o.a5(0,p+0.5)},
N(a){var t,s,r,q,p,o=a.a,n=a.b,m=o*o+n*n
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
this.b=new A.d(n-p*s,o-p*r)}}
A.c6.prototype={
$2(a,b){var t=this.a,s=this.b,r=this.c
return new A.d(t.a+s.a*a+r.a*b,t.b+s.b*a+r.b*b)},
$S:11}
A.cc.prototype={
aF(a){var t=this.x
return Math.max(0,t-a)},
gbk(){var t,s,r=this.e
r===$&&A.f()
t=r.a
r=r.b
s=this.a.b.a*1.2
return B.a.ag(this.f,new A.ci(new A.I(t,r,t+s,r+s)))},
gaG(){var t=this.r
if(!(t>0))return 0
return Math.sin(3.141592653589793*B.b.p(1-t/Math.max(0.05,this.a.d.f),0,1))},
gbE(){if(!(this.r>0))return 1
return 1+(B.b.p(this.a.d.w,1.05,1.8)-1)*this.gaG()},
bD(a){var t,s,r=this
if(!isFinite(a)||!r.a.d.e||r.r>0||r.aF(a)>0)return!1
t=r.a.d
r.r=Math.max(0.12,t.f)
s=t.r
t=isFinite(s)?s:2
r.x=a+Math.max(0,t)*1000
r.at.F(0)
r.as.F(0)
r.ad()
return!0},
by(a){var t=this,s=t.r
if(s<=0)return
s=Math.max(0,s-a)
t.r=s
if(s>0)t.ad()
else t.at.F(0)},
b9(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=a9.a,b1=b0.a,b2=A.dM(b1.b,!0,u.i),b3=A.B(b2),b4=b3.i("b9<1>"),b5=A.dL(new A.b9(b2,b3.i("w(1)").a(new A.ch()),b4),b4.i("c.E"))
if(b5.length===0)B.a.P(b5,B.q)
t=b5.length
s=Math.max(t,4)
b2=u.S
b3=J.d5(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.a4(r,4)
b4=a9.c
B.a.an(b3,b4)
q=A.dV(b3,0,A.ek(t,"count",b2),A.B(b3).c).aK(0)
b3=J.d5(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.a4(r,4)
B.a.an(b3,b4)
p=A.dV(b3,0,A.ek(t,"count",b2),A.B(b3).c).aK(0)
o=A.n([],u.v)
for(b2=b1.e,b3=b1.f,n=b1.r,m=b1.w,l=b1.y,b0=b0.b.a*1.2,b0*=b0,k=b1.a,j=b1.c,b1=b1.d,r=0;r<t;++r){if(!(r<b5.length))return A.j(b5,r)
i=b5[r]
if(!(r<q.length))return A.j(q,r)
h=q[r]
if(!(r<p.length))return A.j(p,r)
g=p[r]
f=Math.max(1,b0)*B.b.p(k,0.2,20)
e=B.b.p(i,0.05,50)
d=Math.sqrt(f/e)
c=Math.sqrt(f*e)
b=a9.b5(g,d,c)
a=Math.min(j,b1)
a0=Math.max(j,b1)
a1=a+b4.E()*(a0-a)+90*h
a2=(a1>=360?a1-360:a1)*3.141592653589793/180
a3=Math.min(b2,b3)
a4=Math.max(b2,b3)
a5=a3+b4.E()*(a4-a3)
a3=Math.min(n,m)
a4=Math.max(n,m)
i=b4.E()
h=Math.cos(a2)
g=Math.sin(a2)
a6=Math.abs(l)>0.01
a7=a6?b4.E()*360:0
a8=new A.ag(b,new A.d(h*a5,g*a5),c,d,a5,a3+i*(a4-a3),a7,l)
if(a6)a9.b3(a8)
a8.d=a8.b
b4.E()
b4.E()
b4.E()
b4.E()
B.a.l(o,a8)}return o},
aS(){var t,s,r,q,p,o,n,m
for(t=this.f,s=t.length,r=0;r<t.length;t.length===s||(0,A.W)(t),++r){q=t[r]
p=q.b
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.b
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
m=new A.d(o/n,p/n)}else{p=q.d
p===$&&A.f()
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.d
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
n=new A.d(o/n,p/n)
m=n}else m=B.f}p=q.ay
q.b=new A.d(m.a*p,m.b*p)}},
gaT(){var t,s,r,q,p,o,n,m=A.n([],u.q)
for(t=this.f,s=t.length,r=u.t,q=0;q<t.length;t.length===s||(0,A.W)(t),++q){p=t[q]
o=p.a
n=p.b
m.push(A.n([o.a,o.b,n.a,n.b,p.CW],r))}return m},
bw(a){var t,s,r,q,p,o,n,m,l,k,j,i,h=u.j
if(!h.b(a)||J.T(a)!==this.f.length)throw A.b(B.D)
for(t=this.f,s=J.ao(a),r=0;r<t.length;++r){q=s.h(a,r)
if(h.b(q)){p=J.aF(q)
p=p.gk(q)!==5||p.ag(q,new A.cj())}else p=!0
if(p)throw A.b(B.C)
if(!(r<t.length))return A.j(t,r)
o=t[r]
p=J.ao(q)
n=A.a2(p.h(q,0))
m=A.a2(p.h(q,1))
l=A.a2(p.h(q,2))
k=A.a2(p.h(q,3))
j=A.a2(p.h(q,4))
p=o.ay
if(Math.abs(Math.sqrt(l*l+k*k)-p)>Math.max(0.0001,p*0.000001)||Math.abs(j)>1e9)throw A.b(B.H)
o.a=new A.d(n,m)
o.b=new A.d(l,k)
o.CW=j
i=o.gB()
if(i.a<-0.0001||i.b<-0.0001||i.c>380.0001||i.d>380.0001)throw A.b(B.F)}},
b3(a){var t,s,r,q,p,o,n,m,l,k,j,i
for(t=this.d,s=380-t,r=0;r<3;++r){q=a.gai()
p=A.B(q)
o=p.i("e(1)")
p=p.i("L<1,e>")
n=new A.L(q,o.a(new A.cd()),p).a2(0,B.j)
m=new A.L(q,o.a(new A.ce()),p).a2(0,B.k)
l=new A.L(q,o.a(new A.cf()),p).a2(0,B.j)
k=new A.L(q,o.a(new A.cg()),p).a2(0,B.k)
if(n<t)j=t-n
else j=m>s?s-m:0
if(l<t)i=t-l
else i=k>s?s-k:0
if(j===0&&i===0)break
p=a.a
a.a=new A.d(p.a+j,p.b+i)}},
bA(a7,a8,a9,b0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=this,a4=B.b.p(a7,0,0.05),a5=B.c.p(1,0,2),a6=B.b.p(a8,0,3600)
for(t=a3.f,s=t.length,r=a3.a,q=r.b.a*1.2,p=b0==null,o=0,n=0;n<t.length;t.length===s||(0,A.W)(t),++n){m=t[n]
l=B.b.p((p?m.ay+m.ch*a6:b0)*a5,0,4000)
k=m.b
j=k.a
k=k.b
i=Math.sqrt(j*j+k*k)
if(i<0.000001)h=B.R
else{k=m.b
h=new A.d(k.a/i,k.b/i)}m.b=new A.d(h.a*l,h.b*l)
k=m.cx
j=Math.abs(k)
g=Math.max(1,B.b.bc(j*a4/5))
for(j=j>0.01,f=a4/g,k=k*a4/g,e=0;e<g;++e){d=m.b
c=d.a*f
d=d.b*f
if(j)m.CW+=k
if(a9&&!(a3.r>0)){b=a3.e
b===$&&A.f()
a=b.a
b=b.b
a0=m.a7(new A.I(a,b,a+q,b+q),new A.d(-c,-d))}else a0=null
b=m.a
a=a0==null
if(a)a1=1
else a1=a0===0?0:Math.min(1,a0+1e-7)
m.a=new A.d(b.a+c*a1,b.b+d*a1)
if(a3.a9(m))++o
if(!a)break}}a2=r.a.x?a3.b7():0
a3.bz(a4)
return new A.c4(o,a2)},
bp(a,b){var t,s,r,q,p,o,n,m,l,k,j=this,i=a.a,h=!0
if(isFinite(i)){t=a.b
if(isFinite(t))i=i===0&&t===0
else i=h}else i=h
if(i)return
i=j.e
i===$&&A.f()
s=i.J(0,a)
h=j.a
if(!h.d.cx){t=j.d
r=Math.max(t,380-t-h.b.a*1.2)
s=new A.d(B.b.p(s.a,t,r),B.b.p(s.b,t,r))}q=s.Z(0,i)
t=j.e
r=t.a
t=t.b
h=h.b.a*1.2
p=new A.I(r,t,r+h,t+h)
o=1
if(b&&!(j.r>0))for(h=j.f,t=h.length,n=0;n<h.length;h.length===t||(0,A.W)(h),++n){m=h[n].a7(p,q)
if(m!=null){r=m===0?0:m+1e-7
o=Math.min(o,r)}}h=i.J(0,q.a5(0,Math.min(1,o)))
j.e=h
l=h.Z(0,i).gbh()
if(l===0)return
j.y+=l
if(j.r>0){for(i=j.f,k=0;k<i.length;++k)if(i[k].a7(p,q)!=null)j.aq(k)}else j.ar()},
bz(a){var t=this,s=t.Q,r=A.B(s).i("w(1)").a(new A.ck(a))
s.$flags&1&&A.aH(s,16)
B.a.b6(s,r,!0)
if(t.r>0)t.ad()
else t.ar()},
ad(){var t,s,r,q,p,o=this
if(!(o.r>0))return
t=o.e
t===$&&A.f()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.I(s,t,s+r,t+r)
for(t=o.f,s=o.at,p=0;p<t.length;++p){if(s.U(0,p))continue
if(!(p<t.length))return A.j(t,p)
if(!q.W(t[p].gB()))continue
o.aq(p)}},
aq(a){var t,s,r,q=this
if(!q.at.l(0,a))return;++q.z
t=q.e
t===$&&A.f()
s=q.a.b.a*1.2/2
r=t.J(0,new A.d(s,s))
s=q.f
if(!(a<s.length))return A.j(s,a)
B.a.l(q.Q,new A.a9(r.J(0,s[a].gB().gT()).aO(0,2)))},
ar(){var t,s,r,q,p,o,n,m,l,k,j,i=this
if(i.r>0)return
t=i.e
t===$&&A.f()
s=t.a
t=t.b
r=i.a.b.a*1.2
q=s+r
r=t+r
p=new A.I(s,t,q,r)
o=A.d8(u.S)
for(n=i.f,m=i.as,q=(s+q)/2,r=(t+r)/2,t=i.Q,l=0;l<n.length;++l){k=A.dE(p,n[l].gB())
if(k<=0)continue
if(k<=14){m.l(0,l)
o.l(0,l)}else if(k>=22&&m.U(0,l)){++i.z
if(!(l<n.length))return A.j(n,l)
s=n[l].gB()
if(!(l<n.length))return A.j(n,l)
j=n[l].gB()
B.a.l(t,new A.a9(new A.d((q+(s.a+s.c)/2)/2,(r+(j.b+j.d)/2)/2)))}else if(m.U(0,l))o.l(0,l)}m.F(0)
m.P(0,o)},
aJ(){var t,s,r,q=this.e
q===$&&A.f()
t=q.a
s=this.d
r=!0
if(!(t<=s)){q=q.b
if(!(q<=s)){r=this.a.b.a*1.2
s=380-s
q=t+r>=s||q+r>=s}else q=r}else q=r
return q},
bs(){var t,s,r,q,p,o=this
if(o.r>0)return!1
t=o.e
t===$&&A.f()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.I(s,t,s+r,t+r)
for(t=o.f,s=t.length,p=0;p<t.length;t.length===s||(0,A.W)(t),++p)if(t[p].aI(q)!=null)return!0
return!1},
bv(){var t,s,r,q,p,o,n,m=this.e
m===$&&A.f()
t=m.a
m=m.b
s=this.a.b.a*1.2
r=new A.I(t,m,t+s,m+s)
for(m=this.f,t=m.length,q=0,p=0;p<m.length;m.length===t||(0,A.W)(m),++p){o=m[p]
n=o.aI(r)
if(n==null)continue
s=o.a
o.a=new A.d(s.a+n.a,s.b+n.b)
o.N(n);++q}return q},
b5(a,b,c){var t,s,r,q,p,o,n,m,l,k,j=this,i=Math.max(8,j.d+2),h=A.cG(),g=A.cG(),f=A.cG(),e=A.cG()
switch(B.c.a4(a,4)){case 0:h.b=i
g.b=190-c-i
f.b=i
e.b=190-b-i
break
case 1:h.b=190+i
g.b=380-c-i
f.b=i
e.b=190-b-i
break
case 2:h.b=i
g.b=190-c-i
f.b=190+i
e.b=380-b-i
break
default:t=190+i
h.b=t
g.b=380-c-i
f.b=t
e.b=380-b-i}t=g.O()
s=h.O()
if(typeof t!=="number")return t.aP()
if(typeof s!=="number")return A.cV(s)
if(t<s){h.b=i
g.b=Math.max(i,380-c-i)}t=e.O()
s=f.O()
if(typeof t!=="number")return t.aP()
if(typeof s!=="number")return A.cV(s)
if(t<s){f.b=i
e.b=Math.max(i,380-b-i)}t=j.e
t===$&&A.f()
s=t.a
t=t.b
r=j.a.b.a*1.2
q=r*0.6
p=new A.I(s-q,t-q,s+r+q,t+r+q)
for(t=j.c,o=0;o<12;++o){s=h.b
if(s===h)A.D(A.aT(""))
r=t.E()
q=g.b
if(q===g)A.D(A.aT(""))
n=h.b
if(n===h)A.D(A.aT(""))
if(typeof q!=="number")return q.Z()
if(typeof n!=="number")return A.cV(n)
q=Math.max(1,q-n)
if(typeof s!=="number")return s.J()
m=s+r*q
s=f.b
if(s===f)A.D(A.aT(""))
r=t.E()
q=e.b
if(q===e)A.D(A.aT(""))
n=f.b
if(n===f)A.D(A.aT(""))
if(typeof q!=="number")return q.Z()
if(typeof n!=="number")return A.cV(n)
q=Math.max(1,q-n)
if(typeof s!=="number")return s.J()
l=s+r*q
k=new A.d(m,l)
if(!new A.I(m,l,m+c,l+b).W(p))return k}return new A.d(J.du(h.O(),i,380-c-i),J.du(f.O(),i,380-b-i))},
a9(a1){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a1.gT()
for(t=this.d,s=380-t,r=a1.y*0.5,q=a1.z*0.5,p=!1,o=0;o<3;++o){n=a0.a
m=a0.b
a1.a=new A.d(n-r,m-q)
l=a1.gai()
k=B.a.gI(l).a
j=B.a.gI(l).a
i=B.a.gI(l).b
h=B.a.gI(l).b
for(g=0;g<4;++g){f=l[g]
e=f.a
if(e<k)k=e
if(e>j)j=e
d=f.b
if(d<i)i=d
if(d>h)h=d}c=!0
if(k<t){b=t-k
a1.N(B.f)
p=c}else if(j>s){b=s-j
a1.N(B.S)
p=c}else b=0
if(i<t){a=t-i
a1.N(B.h)
p=c}else if(h>s){a=s-h
a1.N(B.Q)
p=c}else a=0
if(b===0&&a===0)break
a0=new A.d(n+b,m+a)}a1.aQ(a0)
return p},
b7(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f
for(t=this.f,s=0,r=0;r<t.length;r=q)for(q=r+1,p=q;o=t.length,p<o;++p){if(!(r<o))return A.j(t,r)
n=t[r]
m=t[p]
if(!n.gB().W(m.gB()))continue
l=n.bq(m)
if(l==null)continue;++s
o=l.a
k=o*0.5
j=l.b
i=j*0.5
h=n.a
g=n.y*0.5
f=n.z*0.5
n.a=new A.d(h.a+g+k-g,h.b+f+i-f)
f=m.a
h=m.y*0.5
g=m.z*0.5
m.a=new A.d(f.a+h-k-h,f.b+g-i-g)
n.N(l)
m.N(new A.d(-o,-j))
this.a9(n)
this.a9(m)}return s}}
A.ci.prototype={
$1(a){return A.dE(this.a,u.W.a(a).gB())<=14},
$S:12}
A.ch.prototype={
$1(a){A.a1(a)
return isFinite(a)&&a>0.05&&a<50},
$S:13}
A.cj.prototype={
$1(a){return typeof a!="number"||!isFinite(a)},
$S:14}
A.cd.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.ce.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.cf.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cg.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.ck.prototype={
$1(a){return!((u.Y.a(a).b+=this.a)<0.42)},
$S:15};(function aliases(){var t=J.a8.prototype
t.aU=t.j})();(function installTearOffs(){var t=hunkHelpers._static_0,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(A,"h2","f9",1)
s(A,"hb","fJ",2)
r(A,"hs",2,null,["$1$2","$2"],["eq",function(a,b){return A.eq(a,b,u.H)}],4,0)
r(A,"hr",2,null,["$1$2","$2"],["ep",function(a,b){return A.ep(a,b,u.H)}],4,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.o,null)
r(A.o,[A.d6,J.by,A.b2,J.af,A.q,A.i,A.cA,A.c,A.a_,A.ba,A.z,A.b7,A.al,A.aJ,A.y,A.cD,A.cw,A.H,A.ct,A.aU,A.cF,A.Q,A.bX,A.cM,A.ax,A.c_,A.aj,A.br,A.bt,A.cJ,A.b3,A.F,A.aZ,A.cC,A.ay,A.cl,A.bu,A.cx,A.ca,A.cb,A.c3,A.cv,A.c7,A.d,A.cB,A.I,A.cm,A.bQ,A.cn,A.c4,A.a9,A.ag,A.cc])
r(J.by,[J.bA,J.aO,J.aQ,J.aP,J.aR,J.at,J.au])
r(J.aQ,[J.a8,J.l,A.av,A.aX])
r(J.a8,[J.bN,J.az,J.a6])
s(J.bz,A.b2)
s(J.co,J.l)
r(J.at,[J.aN,J.bB])
r(A.q,[A.a7,A.b6,A.bC,A.bV,A.bR,A.bW,A.aS,A.bn,A.X,A.b8,A.bU,A.b4,A.bs])
s(A.aA,A.i)
s(A.aI,A.aA)
r(A.c,[A.aL,A.b9])
r(A.aL,[A.A,A.ai])
r(A.A,[A.b5,A.L,A.bZ])
s(A.aB,A.al)
s(A.bg,A.aB)
s(A.aK,A.aJ)
r(A.y,[A.bx,A.bp,A.bq,A.bT,A.cW,A.cY,A.c5,A.c9,A.c8,A.d_,A.ci,A.ch,A.cj,A.cd,A.ce,A.cf,A.cg,A.ck])
s(A.ah,A.bx)
s(A.cy,A.bp)
s(A.b_,A.b6)
r(A.bT,[A.bS,A.as])
r(A.H,[A.Z,A.bY])
r(A.bq,[A.cp,A.cX,A.cu,A.cK,A.c6])
r(A.aX,[A.bE,A.aw])
r(A.aw,[A.bc,A.be])
s(A.bd,A.bc)
s(A.aV,A.bd)
s(A.bf,A.be)
s(A.aW,A.bf)
r(A.aV,[A.bF,A.bG])
r(A.aW,[A.bH,A.bI,A.bJ,A.bK,A.bL,A.aY,A.bM])
s(A.aC,A.bW)
s(A.bh,A.ax)
s(A.bb,A.bh)
s(A.bD,A.aS)
s(A.cq,A.br)
r(A.bt,[A.cs,A.cr])
s(A.cI,A.cJ)
r(A.X,[A.b0,A.bw])
t(A.aA,A.b7)
t(A.bc,A.i)
t(A.bd,A.z)
t(A.be,A.i)
t(A.bf,A.z)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",e:"double",R:"num",m:"String",w:"bool",aZ:"Null",h:"List",o:"Object",V:"Map",t:"JSObject"},mangledNames:{},types:["e(d)","a()","@(@)","~(o?,o?)","0^(0^,0^)<R>","@(@,m)","@(m)","e(@)","e(m,e,e,e)","w(m)","m(m)","d(e,e)","w(ag)","w(e)","w(@)","w(a9)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.bg&&a.b(c.a)&&b.b(c.b)}}
A.fA(v.typeUniverse,JSON.parse('{"a6":"a8","bN":"a8","az":"a8","hA":"av","bA":{"w":[],"k":[]},"aO":{"k":[]},"aQ":{"t":[]},"a8":{"t":[]},"l":{"h":["1"],"t":[],"c":["1"]},"bz":{"b2":[]},"co":{"l":["1"],"h":["1"],"t":[],"c":["1"]},"af":{"a5":["1"]},"at":{"e":[],"R":[]},"aN":{"e":[],"a":[],"R":[],"k":[]},"bB":{"e":[],"R":[],"k":[]},"au":{"m":[],"k":[]},"a7":{"q":[]},"aI":{"i":["a"],"b7":["a"],"h":["a"],"c":["a"],"i.E":"a"},"aL":{"c":["1"]},"A":{"c":["1"]},"b5":{"A":["1"],"c":["1"],"c.E":"1","A.E":"1"},"a_":{"a5":["1"]},"L":{"A":["2"],"c":["2"],"c.E":"2","A.E":"2"},"b9":{"c":["1"],"c.E":"1"},"ba":{"a5":["1"]},"aA":{"i":["1"],"b7":["1"],"h":["1"],"c":["1"]},"bg":{"aB":[],"al":[]},"aJ":{"V":["1","2"]},"aK":{"aJ":["1","2"],"V":["1","2"]},"bx":{"y":[],"Y":[]},"ah":{"y":[],"Y":[]},"b_":{"q":[]},"bC":{"q":[]},"bV":{"q":[]},"y":{"Y":[]},"bp":{"y":[],"Y":[]},"bq":{"y":[],"Y":[]},"bT":{"y":[],"Y":[]},"bS":{"y":[],"Y":[]},"as":{"y":[],"Y":[]},"bR":{"q":[]},"Z":{"H":["1","2"],"dK":["1","2"],"V":["1","2"],"H.K":"1","H.V":"2"},"ai":{"c":["1"],"c.E":"1"},"aU":{"a5":["1"]},"aB":{"al":[]},"av":{"t":[],"k":[]},"aX":{"t":[]},"bE":{"t":[],"k":[]},"aw":{"G":["1"],"t":[]},"aV":{"i":["e"],"h":["e"],"G":["e"],"t":[],"c":["e"],"z":["e"]},"aW":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"]},"bF":{"i":["e"],"h":["e"],"G":["e"],"t":[],"c":["e"],"z":["e"],"k":[],"i.E":"e"},"bG":{"i":["e"],"h":["e"],"G":["e"],"t":[],"c":["e"],"z":["e"],"k":[],"i.E":"e"},"bH":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"],"k":[],"i.E":"a"},"bI":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"],"k":[],"i.E":"a"},"bJ":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"],"k":[],"i.E":"a"},"bK":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"],"k":[],"i.E":"a"},"bL":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"],"k":[],"i.E":"a"},"aY":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"],"k":[],"i.E":"a"},"bM":{"i":["a"],"h":["a"],"G":["a"],"t":[],"c":["a"],"z":["a"],"k":[],"i.E":"a"},"bW":{"q":[]},"aC":{"q":[]},"bb":{"ax":["1"],"dd":["1"],"c":["1"]},"aj":{"a5":["1"]},"i":{"h":["1"],"c":["1"]},"H":{"V":["1","2"]},"ax":{"dd":["1"],"c":["1"]},"bh":{"ax":["1"],"dd":["1"],"c":["1"]},"bY":{"H":["m","@"],"V":["m","@"],"H.K":"m","H.V":"@"},"bZ":{"A":["m"],"c":["m"],"c.E":"m","A.E":"m"},"aS":{"q":[]},"bD":{"q":[]},"e":{"R":[]},"a":{"R":[]},"h":{"c":["1"]},"bn":{"q":[]},"b6":{"q":[]},"X":{"q":[]},"b0":{"q":[]},"bw":{"q":[]},"b8":{"q":[]},"bU":{"q":[]},"b4":{"q":[]},"bs":{"q":[]},"b3":{"q":[]},"ay":{"ff":[]},"bQ":{"fb":[]},"f0":{"h":["a"],"c":["a"]},"fj":{"h":["a"],"c":["a"]},"fi":{"h":["a"],"c":["a"]},"eZ":{"h":["a"],"c":["a"]},"fg":{"h":["a"],"c":["a"]},"f_":{"h":["a"],"c":["a"]},"fh":{"h":["a"],"c":["a"]},"eX":{"h":["e"],"c":["e"]},"eY":{"h":["e"],"c":["e"]}}'))
A.fz(v.typeUniverse,JSON.parse('{"aL":1,"aA":1,"aw":1,"bh":1,"br":2,"bt":2}'))
var u=(function rtii(){var t=A.c1
return{V:t("aI"),W:t("ag"),C:t("q"),Z:t("Y"),u:t("ah<e>"),R:t("c<@>"),v:t("l<ag>"),q:t("l<h<e>>"),U:t("l<h<R>>"),O:t("l<V<m,e>>"),l:t("l<a9>"),M:t("l<d>"),s:t("l<m>"),t:t("l<e>"),b:t("l<@>"),a:t("l<R>"),T:t("aO"),m:t("t"),g:t("a6"),p:t("G<@>"),j:t("h<@>"),c:t("V<m,@>"),f:t("V<@,@>"),Y:t("a9"),P:t("aZ"),K:t("o"),n:t("d"),J:t("hB"),F:t("+()"),N:t("m"),k:t("k"),o:t("az"),y:t("w"),i:t("e"),z:t("@"),S:t("a"),Q:t("dC<aZ>?"),A:t("t?"),_:t("h<@>?"),X:t("o?"),w:t("m?"),L:t("c_?"),d:t("w?"),I:t("e?"),x:t("a?"),B:t("R?"),H:t("R"),D:t("~(m,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.J=J.by.prototype
B.a=J.l.prototype
B.c=J.aN.prototype
B.b=J.at.prototype
B.d=J.au.prototype
B.K=J.a6.prototype
B.L=J.aQ.prototype
B.r=J.bN.prototype
B.i=J.az.prototype
B.k=new A.ah(A.hr(),u.u)
B.j=new A.ah(A.hs(),u.u)
B.t=new A.c3()
B.l=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.u=function() {
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
B.z=function(getTagFallback) {
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
B.v=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.y=function(hooks) {
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
B.x=function(hooks) {
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
B.w=function(hooks) {
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
B.m=function(hooks) { return hooks; }

B.n=new A.cq()
B.e=new A.cA()
B.A=new A.cB()
B.B=new A.F("Invalid mobile enemy variation")
B.C=new A.F("start pose values")
B.D=new A.F("start pose count")
B.E=new A.F("Invalid mobile enemy pace")
B.F=new A.F("start pose bounds")
B.o=new A.F("event")
B.p=new A.F("jump")
B.G=new A.F("proof")
B.H=new A.F("start pose speed")
B.I=new A.F("unfinished")
B.M=new A.cr(null)
B.N=new A.cs(null)
B.q=t([1,0.25,0.5,3],u.t)
B.P={}
B.O=new A.aK(B.P,[],A.c1("aK<@,@>"))
B.h=new A.d(0,1)
B.Q=new A.d(0,-1)
B.f=new A.d(1,0)
B.R=new A.d(1,1)
B.S=new A.d(-1,0)
B.T=A.S("hw")
B.U=A.S("hx")
B.V=A.S("eX")
B.W=A.S("eY")
B.X=A.S("eZ")
B.Y=A.S("f_")
B.Z=A.S("f0")
B.a_=A.S("o")
B.a0=A.S("fg")
B.a1=A.S("fh")
B.a2=A.S("fi")
B.a3=A.S("fj")})();(function staticFields(){$.cH=null
$.J=A.n([],A.c1("l<o>"))
$.dP=null
$.cz=0
$.dR=A.h2()
$.dz=null
$.dy=null
$.en=null
$.ei=null
$.et=null
$.cU=null
$.cZ=null
$.dq=null
$.cL=A.n([],A.c1("l<h<o>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hz","ew",()=>A.em("_$dart_dartClosure"))
t($,"hy","dt",()=>A.em("_$dart_dartClosure_dartJSInterop"))
t($,"hO","eI",()=>A.n([new J.bz()],A.c1("l<b2>")))
t($,"hD","ey",()=>A.a0(A.cE({
toString:function(){return"$receiver$"}})))
t($,"hE","ez",()=>A.a0(A.cE({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hF","eA",()=>A.a0(A.cE(null)))
t($,"hG","eB",()=>A.a0(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hJ","eE",()=>A.a0(A.cE(void 0)))
t($,"hK","eF",()=>A.a0(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hI","eD",()=>A.a0(A.dW(null)))
t($,"hH","eC",()=>A.a0(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"hM","eH",()=>A.a0(A.dW(void 0)))
t($,"hL","eG",()=>A.a0(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"hN","d1",()=>A.er(B.a_))
t($,"hC","ex",()=>{A.fa()
return $.cz})})();(function nativeSupport(){!function(){var t=function(a){var n={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.av,SharedArrayBuffer:A.av,ArrayBufferView:A.aX,DataView:A.bE,Float32Array:A.bF,Float64Array:A.bG,Int16Array:A.bH,Int32Array:A.bI,Int8Array:A.bJ,Uint16Array:A.bK,Uint32Array:A.bL,Uint8ClampedArray:A.aY,CanvasPixelArray:A.aY,Uint8Array:A.bM})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.aw.$nativeSuperclassTag="ArrayBufferView"
A.bc.$nativeSuperclassTag="ArrayBufferView"
A.bd.$nativeSuperclassTag="ArrayBufferView"
A.aV.$nativeSuperclassTag="ArrayBufferView"
A.be.$nativeSuperclassTag="ArrayBufferView"
A.bf.$nativeSuperclassTag="ArrayBufferView"
A.aW.$nativeSuperclassTag="ArrayBufferView"})()
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
var t=A.hp
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
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
if(a[b]!==t){A.hW(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.n(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.dL(b)
return new t(c,this)}:function(){if(t===null)t=A.dL(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.dL(a).prototype
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
dQ(a,b,c,d){return{i:a,p:b,e:c,x:d}},
dM(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.dO==null){A.hL()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.c(A.em("Return interceptor for "+A.v(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.d4
if(p==null)p=$.d4=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.hQ(a)
if(q!=null)return q
if(typeof a=="function")return B.I
t=Object.getPrototypeOf(a)
if(t==null)return B.q
if(t===Object.prototype)return B.q
if(typeof r=="function"){p=$.d4
if(p==null)p=$.d4=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.k,enumerable:false,writable:true,configurable:true})
return B.k}return B.k},
e5(a,b){if(a<0||a>4294967295)throw A.c(A.bc(a,0,4294967295,"length",null))
return J.fu(new Array(a),b)},
e6(a,b){if(a<0)throw A.c(A.ci("Length must be a non-negative integer: "+a))
return A.n(new Array(a),b.i("o<0>"))},
du(a,b){if(a<0)throw A.c(A.ci("Length must be a non-negative integer: "+a))
return A.n(new Array(a),b.i("o<0>"))},
fu(a,b){var t=A.n(a,b.i("o<0>"))
t.$flags=1
return t},
e7(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
fv(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.e7(s))break;++b}return b},
fw(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.i(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.e7(r))break}return b},
aw(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aX.prototype
return J.bP.prototype}if(typeof a=="string")return J.aC.prototype
if(a==null)return J.aY.prototype
if(typeof a=="boolean")return J.bO.prototype
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ae.prototype
if(typeof a=="symbol")return J.b0.prototype
if(typeof a=="bigint")return J.aZ.prototype
return a}if(a instanceof A.r)return a
return J.dM(a)},
aP(a){if(typeof a=="string")return J.aC.prototype
if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ae.prototype
if(typeof a=="symbol")return J.b0.prototype
if(typeof a=="bigint")return J.aZ.prototype
return a}if(a instanceof A.r)return a
return J.dM(a)},
a4(a){if(a==null)return a
if(Array.isArray(a))return J.o.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ae.prototype
if(typeof a=="symbol")return J.b0.prototype
if(typeof a=="bigint")return J.aZ.prototype
return a}if(a instanceof A.r)return a
return J.dM(a)},
hH(a){if(typeof a=="number")return J.aB.prototype
if(a==null)return a
if(!(a instanceof A.r))return J.aH.prototype
return a},
C(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.aw(a).R(a,b)},
H(a,b){if(typeof b==="number")if(Array.isArray(a)||A.hP(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.a4(a).h(a,b)},
dq(a,b,c){return J.a4(a).q(a,b,c)},
dS(a,b){return J.a4(a).S(a,b)},
dT(a,b,c){return J.hH(a).m(a,b,c)},
dU(a,b){return J.a4(a).D(a,b)},
Q(a){return J.aw(a).gA(a)},
f9(a){return J.aP(a).gG(a)},
fa(a){return J.aP(a).gaL(a)},
ch(a){return J.a4(a).gt(a)},
W(a){return J.aP(a).gk(a)},
fb(a){return J.aw(a).gu(a)},
fc(a,b,c){return J.a4(a).a5(a,b,c)},
bz(a){return J.aw(a).j(a)},
bM:function bM(){},
bO:function bO(){},
aY:function aY(){},
b_:function b_(){},
ag:function ag(){},
c0:function c0(){},
aH:function aH(){},
ae:function ae(){},
aZ:function aZ(){},
b0:function b0(){},
o:function o(a){this.$ti=a},
bN:function bN(){},
cI:function cI(a){this.$ti=a},
am:function am(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aB:function aB(){},
aX:function aX(){},
bP:function bP(){},
aC:function aC(){}},A={dv:function dv(){},
fy(a){return new A.af("Field '"+a+"' has not been initialized.")},
b2(a){return new A.af("Local '"+a+"' has not been initialized.")},
fx(a){return new A.af("Field '"+a+"' has already been initialized.")},
ai(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
dD(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
eL(a,b,c){return a},
dP(a){var t,s
for(t=$.V.length,s=0;s<t;++s)if(a===$.V[s])return!0
return!1},
ek(a,b,c,d){A.dA(b,"start")
if(c!=null){A.dA(c,"end")
if(b>c)A.Y(A.bc(b,0,c,"start",null))}return new A.bh(a,b,c,d.i("bh<0>"))},
fA(a,b,c,d){if(u.O.b(a))return new A.aV(a,b,c.i("@<0>").C(d).i("aV<1,2>"))
return new A.aq(a,b,c.i("@<0>").C(d).i("aq<1,2>"))},
e4(){return new A.bf("No element")},
af:function af(a){this.a=a},
aS:function aS(a){this.a=a},
cY:function cY(){},
h:function h(){},
E:function E(){},
bh:function bh(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
aa:function aa(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aq:function aq(a,b,c){this.a=a
this.b=b
this.$ti=c},
aV:function aV(a,b,c){this.a=a
this.b=b
this.$ti=c},
b4:function b4(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
O:function O(a,b,c){this.a=a
this.b=b
this.$ti=c},
ar:function ar(a,b,c){this.a=a
this.b=b
this.$ti=c},
bl:function bl(a,b,c){this.a=a
this.b=b
this.$ti=c},
K:function K(){},
bj:function bj(){},
aI:function aI(){},
eV(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
hP(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
v(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.bz(a)
return t},
c1(a){var t,s=$.ef
if(s==null)s=$.ef=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
c2(a){var t,s,r,q
if(a instanceof A.r)return A.N(A.al(a),null)
t=J.aw(a)
if(t===B.H||t===B.J||u.o.b(a)){s=B.n(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.N(A.al(a),null)},
eg(a){var t,s,r
if(a==null||typeof a=="number"||A.dd(a))return J.bz(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.J)return a.j(0)
if(a instanceof A.au)return a.aZ(!0)
t=$.f8()
for(s=0;s<1;++s){r=t[s].c6(a)
if(r!=null)return r}return"Instance of '"+A.c2(a)+"'"},
fB(){return Date.now()},
fC(){var t,s
if($.cX!==0)return
$.cX=1000
if(typeof window=="undefined")return
t=window
if(t==null)return
if(!!t.dartUseDateNowForTicks)return
s=t.performance
if(s==null)return
if(typeof s.now!="function")return
$.cX=1e6
$.eh=new A.cW(s)},
F(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.c.aY(t,10)|55296)>>>0,t&1023|56320)}throw A.c(A.bc(a,0,1114111,null,null))},
dh(a){throw A.c(A.eK(a))},
i(a,b){if(a==null)J.W(a)
throw A.c(A.df(a,b))},
df(a,b){var t,s="index"
if(!A.eF(b))return new A.a5(!0,b,s,null)
t=J.W(a)
if(b<0||b>=t)return A.ds(b,t,a,s)
return new A.bb(null,null,!0,b,s,"Value not in range")},
eK(a){return new A.a5(!0,a,null,null)},
c(a){return A.B(a,new Error())},
B(a,b){var t
if(a==null)a=new A.bi()
b.dartException=a
t=A.hX
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hX(){return J.bz(this.dartException)},
Y(a,b){throw A.B(a,b==null?new Error():b)},
aR(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.Y(A.hb(a,b,c),t)},
hb(a,b,c){var t,s,r,q,p,o,n,m,l
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
return new A.bk("'"+t+"': Cannot "+p+" "+m+l+o)},
D(a){throw A.c(A.R(a))},
ab(a){var t,s,r,q,p,o
a=A.hV(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.n([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.d0(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
d1(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
el(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
dw(a,b){var t=b==null,s=t?null:b.method
return new A.bQ(a,s,t?null:b.receiver)},
eW(a){if(a==null)return new A.cU(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.ay(a,a.dartException)
return A.hC(a)},
ay(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
hC(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.c.aY(s,16)&8191)===10)switch(r){case 438:return A.ay(a,A.dw(A.v(t)+" (Error "+r+")",null))
case 445:case 5007:A.v(t)
return A.ay(a,new A.ba())}}if(a instanceof TypeError){q=$.eZ()
p=$.f_()
o=$.f0()
n=$.f1()
m=$.f4()
l=$.f5()
k=$.f3()
$.f2()
j=$.f7()
i=$.f6()
h=q.I(t)
if(h!=null)return A.ay(a,A.dw(A.ac(t),h))
else{h=p.I(t)
if(h!=null){h.method="call"
return A.ay(a,A.dw(A.ac(t),h))}else if(o.I(t)!=null||n.I(t)!=null||m.I(t)!=null||l.I(t)!=null||k.I(t)!=null||n.I(t)!=null||j.I(t)!=null||i.I(t)!=null){A.ac(t)
return A.ay(a,new A.ba())}}return A.ay(a,new A.c8(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.be()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.ay(a,new A.a5(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.be()
return a},
eS(a){if(a==null)return J.Q(a)
if(typeof a=="object")return A.c1(a)
return J.Q(a)},
hG(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.q(0,a[t],a[s])}return b},
fj(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.c5().constructor.prototype):Object.create(new A.aA(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.e_(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.ff(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.e_(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
ff(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.c("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.fd)}throw A.c("Error in functionType of tearoff")},
fg(a,b,c,d){var t=A.dZ
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
e_(a,b,c,d){if(c)return A.fi(a,b,d)
return A.fg(b.length,d,a,b)},
fh(a,b,c,d){var t=A.dZ,s=A.fe
switch(b?-1:a){case 0:throw A.c(new A.c4("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
fi(a,b,c){var t,s
if($.dX==null)$.dX=A.dW("interceptor")
if($.dY==null)$.dY=A.dW("receiver")
t=b.length
s=A.fh(t,c,a,b)
return s},
dL(a){return A.fj(a)},
fd(a,b){return A.by(v.typeUniverse,A.al(a.a),b)},
dZ(a){return a.a},
fe(a){return a.b},
dW(a){var t,s,r,q=new A.aA("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.c(A.ci("Field name "+a+" not found."))},
eN(a){return v.getIsolateTag(a)},
hQ(a){var t,s,r,q,p,o=A.ac($.eO.$1(a)),n=$.dg[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.dl[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.cf($.eJ.$2(a,o))
if(r!=null){n=$.dg[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.dl[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.dn(t)
$.dg[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.dl[o]=t
return t}if(q==="-"){p=A.dn(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.eT(a,t)
if(q==="*")throw A.c(A.em(o))
if(v.leafTags[o]===true){p=A.dn(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.eT(a,t)},
eT(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.dQ(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
dn(a){return J.dQ(a,!1,null,!!a.$iT)},
hS(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.dn(t)
else return J.dQ(t,c,null,null)},
hL(){if(!0===$.dO)return
$.dO=!0
A.hM()},
hM(){var t,s,r,q,p,o,n,m
$.dg=Object.create(null)
$.dl=Object.create(null)
A.hK()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.eU.$1(p)
if(o!=null){n=A.hS(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
hK(){var t,s,r,q,p,o,n=B.v()
n=A.aO(B.w,A.aO(B.x,A.aO(B.o,A.aO(B.o,A.aO(B.y,A.aO(B.z,A.aO(B.A(B.n),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.eO=new A.di(q)
$.eJ=new A.dj(p)
$.eU=new A.dk(o)},
aO(a,b){return a(b)||b},
hE(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
hV(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
aK:function aK(a,b){this.a=a
this.b=b},
aT:function aT(){},
aU:function aU(a,b,c){this.a=a
this.b=b
this.$ti=c},
bm:function bm(a,b){this.a=a
this.$ti=b},
bn:function bn(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bL:function bL(){},
ao:function ao(a,b){this.a=a
this.$ti=b},
cW:function cW(a){this.a=a},
bd:function bd(){},
d0:function d0(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
ba:function ba(){},
bQ:function bQ(a,b,c){this.a=a
this.b=b
this.c=c},
c8:function c8(a){this.a=a},
cU:function cU(a){this.a=a},
J:function J(){},
bC:function bC(){},
bD:function bD(){},
c6:function c6(){},
c5:function c5(){},
aA:function aA(a,b){this.a=a
this.b=b},
c4:function c4(a){this.a=a},
a8:function a8(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cJ:function cJ(a){this.a=a},
cN:function cN(a,b){this.a=a
this.b=b
this.c=null},
a9:function a9(a,b){this.a=a
this.$ti=b},
ap:function ap(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
Z:function Z(a,b){this.a=a
this.$ti=b},
b3:function b3(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
di:function di(a){this.a=a},
dj:function dj(a){this.a=a},
dk:function dk(a){this.a=a},
au:function au(){},
aJ:function aJ(){},
hW(a){throw A.B(new A.af("Field '"+a+"' has been assigned during initialization."),new Error())},
e(){throw A.B(A.fy(""),new Error())},
P(){throw A.B(A.fx(""),new Error())},
d3(){var t=new A.d2()
return t.b=t},
d2:function d2(){this.b=null},
av(a,b,c){if(a>>>0!==a||a>=c)throw A.c(A.df(b,a))},
aD:function aD(){},
b7:function b7(){},
bS:function bS(){},
aE:function aE(){},
b5:function b5(){},
b6:function b6(){},
bT:function bT(){},
bU:function bU(){},
bV:function bV(){},
bW:function bW(){},
bX:function bX(){},
bY:function bY(){},
bZ:function bZ(){},
b8:function b8(){},
c_:function c_(){},
bp:function bp(){},
bq:function bq(){},
br:function br(){},
bs:function bs(){},
dB(a,b){var t=b.c
return t==null?b.c=A.bw(a,"e0",[b.x]):t},
ei(a){var t=a.w
if(t===6||t===7)return A.ei(a.x)
return t===11||t===12},
fG(a){return a.as},
cg(a){return A.da(v.typeUniverse,a,!1)},
hO(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.ak(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
ak(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.ak(a0,t,a2,a3)
if(s===t)return a1
return A.ew(a0,s,!0)
case 7:t=a1.x
s=A.ak(a0,t,a2,a3)
if(s===t)return a1
return A.ev(a0,s,!0)
case 8:r=a1.y
q=A.aN(a0,r,a2,a3)
if(q===r)return a1
return A.bw(a0,a1.x,q)
case 9:p=a1.x
o=A.ak(a0,p,a2,a3)
n=a1.y
m=A.aN(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.dG(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.aN(a0,k,a2,a3)
if(j===k)return a1
return A.ex(a0,l,j)
case 11:i=a1.x
h=A.ak(a0,i,a2,a3)
g=a1.y
f=A.hz(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.eu(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.aN(a0,e,a2,a3)
p=a1.x
o=A.ak(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.dH(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.c(A.bB("Attempted to substitute unexpected RTI kind "+a))}},
aN(a,b,c,d){var t,s,r,q,p=b.length,o=A.db(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.ak(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
hA(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.db(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.ak(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
hz(a,b,c,d){var t,s=b.a,r=A.aN(a,s,c,d),q=b.b,p=A.aN(a,q,c,d),o=b.c,n=A.hA(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.ca()
t.a=r
t.b=p
t.c=n
return t},
n(a,b){a[v.arrayRti]=b
return a},
de(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.hJ(t)
return a.$S()}return null},
hN(a,b){var t
if(A.ei(b))if(a instanceof A.J){t=A.de(a)
if(t!=null)return t}return A.al(a)},
al(a){if(a instanceof A.r)return A.q(a)
if(Array.isArray(a))return A.G(a)
return A.dJ(J.aw(a))},
G(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
q(a){var t=a.$ti
return t!=null?t:A.dJ(a)},
dJ(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.hi(a,t)},
hi(a,b){var t=a instanceof A.J?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.h2(v.typeUniverse,t.name)
b.$ccache=s
return s},
hJ(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.da(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
hI(a){return A.ad(A.q(a))},
dN(a){var t=A.de(a)
return A.ad(t==null?A.al(a):t)},
dK(a){var t
if(a instanceof A.au)return A.hF(a.$r,a.aT())
t=a instanceof A.J?A.de(a):null
if(t!=null)return t
if(u.k.b(a))return J.fb(a).a
if(Array.isArray(a))return A.G(a)
return A.al(a)},
ad(a){var t=a.r
return t==null?a.r=new A.d9(a):t},
hF(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.i(r,0)
t=A.by(v.typeUniverse,A.dK(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.i(r,s)
t=A.ey(v.typeUniverse,t,A.dK(r[s]))}return A.by(v.typeUniverse,t,a)},
a1(a){return A.ad(A.da(v.typeUniverse,a,!1))},
hh(a){var t=this
t.b=A.hy(t)
return t.b(a)},
hy(a){var t,s,r,q,p
if(a===u.K)return A.ho
if(A.ax(a))return A.hs
t=a.w
if(t===6)return A.hf
if(t===1)return A.eH
if(t===7)return A.hj
s=A.hx(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.ax)){a.f="$i"+r
if(r==="j")return A.hm
if(a===u.m)return A.hl
return A.hr}}else if(t===10){q=A.hE(a.x,a.y)
p=q==null?A.eH:q
return p==null?A.eB(p):p}return A.hd},
hx(a){if(a.w===8){if(a===u.S)return A.eF
if(a===u.i||a===u.H)return A.hn
if(a===u.N)return A.hq
if(a===u.y)return A.dd}return null},
hg(a){var t=this,s=A.hc
if(A.ax(t))s=A.h8
else if(t===u.K)s=A.eB
else if(A.aQ(t)){s=A.he
if(t===u.x)s=A.h5
else if(t===u.w)s=A.cf
else if(t===u.h)s=A.U
else if(t===u.B)s=A.t
else if(t===u.I)s=A.h4
else if(t===u.A)s=A.h7}else if(t===u.S)s=A.ce
else if(t===u.N)s=A.ac
else if(t===u.y)s=A.dI
else if(t===u.H)s=A.y
else if(t===u.i)s=A.a3
else if(t===u.m)s=A.h6
t.a=s
return t.a(a)},
hd(a){var t=this
if(a==null)return A.aQ(t)
return A.eP(v.typeUniverse,A.hN(a,t),t)},
hf(a){if(a==null)return!0
return this.x.b(a)},
hr(a){var t,s=this
if(a==null)return A.aQ(s)
t=s.f
if(a instanceof A.r)return!!a[t]
return!!J.aw(a)[t]},
hm(a){var t,s=this
if(a==null)return A.aQ(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.r)return!!a[t]
return!!J.aw(a)[t]},
hl(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.r)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
eG(a){if(typeof a=="object"){if(a instanceof A.r)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
hc(a){var t=this
if(a==null){if(A.aQ(t))return a}else if(t.b(a))return a
throw A.B(A.eC(a,t),new Error())},
he(a){var t=this
if(a==null||t.b(a))return a
throw A.B(A.eC(a,t),new Error())},
eC(a,b){return new A.aM("TypeError: "+A.en(a,A.N(b,null)))},
eM(a,b,c,d){if(A.eP(v.typeUniverse,a,b))return a
throw A.B(A.fV("The type argument '"+A.N(a,null)+"' is not a subtype of the type variable bound '"+A.N(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
en(a,b){return A.bI(a)+": type '"+A.N(A.dK(a),null)+"' is not a subtype of type '"+b+"'"},
fV(a){return new A.aM("TypeError: "+a)},
X(a,b){return new A.aM("TypeError: "+A.en(a,b))},
hj(a){var t=this
return t.x.b(a)||A.dB(v.typeUniverse,t).b(a)},
ho(a){return a!=null},
eB(a){if(a!=null)return a
throw A.B(A.X(a,"Object"),new Error())},
hs(a){return!0},
h8(a){return a},
eH(a){return!1},
dd(a){return!0===a||!1===a},
dI(a){if(!0===a)return!0
if(!1===a)return!1
throw A.B(A.X(a,"bool"),new Error())},
U(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.B(A.X(a,"bool?"),new Error())},
a3(a){if(typeof a=="number")return a
throw A.B(A.X(a,"double"),new Error())},
h4(a){if(typeof a=="number")return a
if(a==null)return a
throw A.B(A.X(a,"double?"),new Error())},
eF(a){return typeof a=="number"&&Math.floor(a)===a},
ce(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.B(A.X(a,"int"),new Error())},
h5(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.B(A.X(a,"int?"),new Error())},
hn(a){return typeof a=="number"},
y(a){if(typeof a=="number")return a
throw A.B(A.X(a,"num"),new Error())},
t(a){if(typeof a=="number")return a
if(a==null)return a
throw A.B(A.X(a,"num?"),new Error())},
hq(a){return typeof a=="string"},
ac(a){if(typeof a=="string")return a
throw A.B(A.X(a,"String"),new Error())},
cf(a){if(typeof a=="string")return a
if(a==null)return a
throw A.B(A.X(a,"String?"),new Error())},
h6(a){if(A.eG(a))return a
throw A.B(A.X(a,"JSObject"),new Error())},
h7(a){if(a==null)return a
if(A.eG(a))return a
throw A.B(A.X(a,"JSObject?"),new Error())},
eI(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.N(a[r],b)
return t},
hw(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.eI(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.N(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
eD(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.n([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.l(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.i(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.N(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.N(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.N(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.N(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.N(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
N(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.N(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.N(a.x,b)+">"
if(m===8){q=A.hB(a.x)
p=a.y
return p.length>0?q+("<"+A.eI(p,b)+">"):q}if(m===10)return A.hw(a,b)
if(m===11)return A.eD(a,b,null)
if(m===12)return A.eD(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.i(b,o)
return b[o]}return"?"},
hB(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
h3(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
h2(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.da(a,b,!1)
else if(typeof n=="number"){t=n
s=A.bx(a,5,"#")
r=A.db(t)
for(q=0;q<t;++q)r[q]=s
p=A.bw(a,b,r)
o[b]=p
return p}else return n},
h1(a,b){return A.ez(a.tR,b)},
h0(a,b){return A.ez(a.eT,b)},
da(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.er(A.ep(a,null,b,!1))
s.set(b,t)
return t},
by(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.er(A.ep(a,b,c,!0))
r.set(c,s)
return s},
ey(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.dG(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
aj(a,b){b.a=A.hg
b.b=A.hh
return b},
bx(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.a_(null,null)
t.w=b
t.as=c
s=A.aj(a,t)
a.eC.set(c,s)
return s},
ew(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fZ(a,b,s,c)
a.eC.set(s,t)
return t},
fZ(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.ax(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aQ(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.a_(null,null)
r.w=6
r.x=b
r.as=c
return A.aj(a,r)},
ev(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fX(a,b,s,c)
a.eC.set(s,t)
return t},
fX(a,b,c,d){var t,s
if(d){t=b.w
if(A.ax(b)||b===u.K)return b
else if(t===1)return A.bw(a,"e0",[b])
else if(b===u.P||b===u.T)return u.d}s=new A.a_(null,null)
s.w=7
s.x=b
s.as=c
return A.aj(a,s)},
h_(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.a_(null,null)
t.w=13
t.x=b
t.as=r
s=A.aj(a,t)
a.eC.set(r,s)
return s},
bv(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fW(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bw(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.bv(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.a_(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.aj(a,s)
a.eC.set(q,r)
return r},
dG(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.bv(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a_(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.aj(a,p)
a.eC.set(r,o)
return o},
ex(a,b,c){var t,s,r="+"+(b+"("+A.bv(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.a_(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.aj(a,t)
a.eC.set(r,s)
return s},
eu(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.bv(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.bv(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fW(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.a_(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.aj(a,q)
a.eC.set(s,p)
return p},
dH(a,b,c,d){var t,s=b.as+("<"+A.bv(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fY(a,b,c,s,d)
a.eC.set(s,t)
return t},
fY(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.db(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.ak(a,b,s,0)
n=A.aN(a,c,s,0)
return A.dH(a,o,n,c!==n)}}m=new A.a_(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.aj(a,m)},
ep(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
er(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.fQ(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.eq(a,s,m,l,!1)
else if(r===46)s=A.eq(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.at(a.u,a.e,l.pop()))
break
case 94:l.push(A.h_(a.u,l.pop()))
break
case 35:l.push(A.bx(a.u,5,"#"))
break
case 64:l.push(A.bx(a.u,2,"@"))
break
case 126:l.push(A.bx(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.fS(a,l)
break
case 38:A.fR(a,l)
break
case 63:q=a.u
l.push(A.ew(q,A.at(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.ev(q,A.at(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.fP(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.es(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fU(a.u,a.e,p)
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
return A.at(a.u,a.e,n)},
fQ(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
eq(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.h3(t,p.x)[q]
if(o==null)A.Y('No "'+q+'" in "'+A.fG(p)+'"')
d.push(A.by(t,p,o))}else d.push(q)
return n},
fS(a,b){var t,s=a.u,r=A.eo(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bw(s,q,r))
else{t=A.at(s,a.e,q)
switch(t.w){case 11:b.push(A.dH(s,t,r,a.n))
break
default:b.push(A.dG(s,t,r))
break}}},
fP(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.eo(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.at(q,a.e,p)
r=new A.ca()
r.a=t
r.b=o
r.c=n
b.push(A.eu(q,s,r))
return
case-4:b.push(A.ex(q,b.pop(),t))
return
default:throw A.c(A.bB("Unexpected state under `()`: "+A.v(p)))}},
fR(a,b){var t=b.pop()
if(0===t){b.push(A.bx(a.u,1,"0&"))
return}if(1===t){b.push(A.bx(a.u,4,"1&"))
return}throw A.c(A.bB("Unexpected extended operation "+A.v(t)))},
eo(a,b){var t=b.splice(a.p)
A.es(a.u,a.e,t)
a.p=b.pop()
return t},
at(a,b,c){if(typeof c=="string")return A.bw(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.fT(a,b,c)}else return c},
es(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.at(a,b,c[t])},
fU(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.at(a,b,c[t])},
fT(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.c(A.bB("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.c(A.bB("Bad index "+c+" for "+b.j(0)))},
eP(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.A(a,b,null,c,null)
s.set(c,t)}return t},
A(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.ax(d))return!0
t=b.w
if(t===4)return!0
if(A.ax(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.A(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.A(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.A(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.A(a,b.x,c,d,e))return!1
return A.A(a,A.dB(a,b),c,d,e)}if(t===6)return A.A(a,q,c,d,e)&&A.A(a,b.x,c,d,e)
if(r===7){if(A.A(a,b,c,d.x,e))return!0
return A.A(a,b,c,A.dB(a,d),e)}if(r===6)return A.A(a,b,c,q,e)||A.A(a,b,c,d.x,e)
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
if(!A.A(a,k,c,j,e)||!A.A(a,j,e,k,c))return!1}return A.eE(a,b.x,c,d.x,e)}if(r===11){if(b===u.M)return!0
if(q)return!1
return A.eE(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.hk(a,b,c,d,e)}if(p&&r===10)return A.hp(a,b,c,d,e)
return!1},
eE(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.A(a2,a3.x,a4,a5.x,a6))return!1
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
if(!A.A(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.A(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.A(a2,l[i],a6,h,a4))return!1}g=t.c
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
if(!A.A(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
hk(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.by(a,b,s[p])
return A.eA(a,q,null,c,d.y,e)}return A.eA(a,b.y,null,c,d.y,e)},
eA(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.A(a,b[t],d,e[t],f))return!1
return!0},
hp(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.A(a,s[t],c,r[t],e))return!1
return!0},
aQ(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.ax(a))if(t!==6)s=t===7&&A.aQ(a.x)
return s},
ax(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
ez(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
db(a){return a>0?new Array(a):v.typeUniverse.sEA},
a_:function a_(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
ca:function ca(){this.c=this.b=this.a=null},
d9:function d9(a){this.a=a},
c9:function c9(){},
aM:function aM(a){this.a=a},
et(a,b,c){return 0},
bu:function bu(a,b){var _=this
_.a=a
_.e=_.d=_.c=_.b=null
_.$ti=b},
aL:function aL(a,b){this.a=a
this.$ti=b},
ea(a,b){return new A.a8(a.i("@<0>").C(b).i("a8<1,2>"))},
L(a,b,c){return b.i("@<0>").C(c).i("e9<1,2>").a(A.hG(a,new A.a8(b.i("@<0>").C(c).i("a8<1,2>"))))},
cO(a,b){return new A.a8(a.i("@<0>").C(b).i("a8<1,2>"))},
cQ(a){return new A.bo(a.i("bo<0>"))},
dF(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
fO(a,b,c){var t=new A.as(a,b,c.i("as<0>"))
t.c=a.e
return t},
fs(a,b){var t=a.a,s=new A.ap(t,t.r,t.e,a.$ti.i("ap<1>"))
if(s.n())return s.d
return null},
fz(a,b,c){var t=A.ea(b,c)
a.P(0,new A.cP(t,b,c))
return t},
eb(a,b,c){var t=A.ea(b,c)
t.S(0,a)
return t},
dz(a){var t,s
if(A.dP(a))return"{...}"
t=new A.aG("")
try{s={}
B.a.l($.V,a)
t.a+="{"
s.a=!0
a.P(0,new A.cS(s,t))
t.a+="}"}finally{if(0>=$.V.length)return A.i($.V,-1)
$.V.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
bo:function bo(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cd:function cd(a){this.a=a
this.c=this.b=null},
as:function as(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
cP:function cP(a,b,c){this.a=a
this.b=b
this.c=c},
k:function k(){},
x:function x(){},
cR:function cR(a){this.a=a},
cS:function cS(a,b){this.a=a
this.b=b},
aF:function aF(){},
bt:function bt(){},
hv(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.eW(s)
r=A.S(String(t))
throw A.c(r)}r=A.dc(q)
return r},
dc(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.cb(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.dc(a[t])
return a},
e8(a,b,c){return new A.b1(a,b)},
ha(a){return a.a_()},
fM(a,b){return new A.d5(a,[],A.hD())},
fN(a,b,c){var t,s=new A.aG(""),r=A.fM(s,b)
r.aj(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
cb:function cb(a,b){this.a=a
this.b=b
this.c=null},
cc:function cc(a){this.a=a},
bE:function bE(){},
bG:function bG(){},
b1:function b1(a,b){this.a=a
this.b=b},
bR:function bR(a,b){this.a=a
this.b=b},
cK:function cK(){},
cM:function cM(a){this.b=a},
cL:function cL(a){this.a=a},
d6:function d6(){},
d7:function d7(a,b){this.a=a
this.b=b},
d5:function d5(a,b,c){this.c=a
this.a=b
this.b=c},
dy(a,b,c,d){var t,s=c?J.e6(a,d):J.e5(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
ec(a,b,c){var t,s,r=A.n([],c.i("o<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.D)(a),++s)B.a.l(r,c.a(a[s]))
if(b)return r
r.$flags=1
return r},
dx(a,b){var t,s=A.n([],b.i("o<0>"))
for(t=a.gt(a);t.n();)B.a.l(s,t.gp())
return s},
ej(a,b,c){var t=J.ch(b)
if(!t.n())return a
if(c.length===0){do a+=A.v(t.gp())
while(t.n())}else{a+=A.v(t.gp())
while(t.n())a=a+c+A.v(t.gp())}return a},
bI(a){if(typeof a=="number"||A.dd(a)||a==null)return J.bz(a)
if(typeof a=="string")return JSON.stringify(a)
return A.eg(a)},
bB(a){return new A.bA(a)},
ci(a){return new A.a5(!1,null,null,a)},
dV(a,b,c){return new A.a5(!0,a,b,c)},
bc(a,b,c,d,e){return new A.bb(b,c,!0,a,d,"Invalid value")},
fE(a,b,c){if(0>a||a>c)throw A.c(A.bc(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.c(A.bc(b,a,c,"end",null))
return b}return c},
dA(a,b){if(a<0)throw A.c(A.bc(a,0,null,b,null))
return a},
ds(a,b,c,d){return new A.bK(b,!0,a,d,"Index out of range")},
dE(a){return new A.bk(a)},
em(a){return new A.c7(a)},
bg(a){return new A.bf(a)},
R(a){return new A.bF(a)},
S(a){return new A.a6(a)},
ft(a,b,c){var t,s
if(A.dP(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.n([],u.s)
B.a.l($.V,a)
try{A.ht(a,t)}finally{if(0>=$.V.length)return A.i($.V,-1)
$.V.pop()}s=A.ej(b,u.R.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
dt(a,b,c){var t,s
if(A.dP(a))return b+"..."+c
t=new A.aG(b)
B.a.l($.V,a)
try{s=t
s.a=A.ej(s.a,a,", ")}finally{if(0>=$.V.length)return A.i($.V,-1)
$.V.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
ht(a,b){var t,s,r,q,p,o,n,m=a.gt(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.n())return
t=A.v(m.gp())
B.a.l(b,t)
l+=t.length+2;++k}if(!m.n()){if(k<=5)return
if(0>=b.length)return A.i(b,-1)
s=b.pop()
if(0>=b.length)return A.i(b,-1)
r=b.pop()}else{q=m.gp();++k
if(!m.n()){if(k<=4){B.a.l(b,A.v(q))
return}s=A.v(q)
if(0>=b.length)return A.i(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gp();++k
for(;m.n();q=p,p=o){o=m.gp();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.i(b,-1)
l-=b.pop().length+2;--k}B.a.l(b,"...")
return}}r=A.v(q)
s=A.v(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.i(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.l(b,n)
B.a.l(b,r)
B.a.l(b,s)},
ee(a,b,c,d){var t
if(B.h===c){t=J.Q(a)
b=J.Q(b)
return A.dD(A.ai(A.ai($.dp(),t),b))}if(B.h===d){t=J.Q(a)
b=J.Q(b)
c=J.Q(c)
return A.dD(A.ai(A.ai(A.ai($.dp(),t),b),c))}t=J.Q(a)
b=J.Q(b)
c=J.Q(c)
d=J.Q(d)
d=A.dD(A.ai(A.ai(A.ai(A.ai($.dp(),t),b),c),d))
return d},
u:function u(){},
bA:function bA(a){this.a=a},
bi:function bi(){},
a5:function a5(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bb:function bb(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bK:function bK(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
bk:function bk(a){this.a=a},
c7:function c7(a){this.a=a},
bf:function bf(a){this.a=a},
bF:function bF(a){this.a=a},
be:function be(){},
a6:function a6(a){this.a=a},
d:function d(){},
M:function M(a,b,c){this.a=a
this.b=b
this.$ti=c},
b9:function b9(){},
r:function r(){},
d_:function d_(){this.b=this.a=0},
aG:function aG(a){this.a=a},
fk(a){var t,s,r,q,p,o,n,m,l,k,j=null,i=a.h(0,"aspects")
if(i==null)i=a.h(0,"enemyAspects")
if(u.j.b(i)&&J.fa(i)){t=J.fc(i,new A.ck(),u.i)
s=A.dx(t,t.$ti.i("E.E"))}else s=B.p
t=A.t(a.h(0,"areaMultiplier"))
if(t==null)t=j
if(t==null){t=A.t(a.h(0,"enemyAreaMultiplier"))
if(t==null)t=j}if(t==null)t=2
r=A.t(a.h(0,"angleMinDeg"))
if(r==null)r=j
if(r==null)r=30
q=A.t(a.h(0,"angleMaxDeg"))
if(q==null)q=j
if(q==null)q=60
p=A.t(a.h(0,"speedMin"))
if(p==null)p=j
if(p==null)p=75
o=A.t(a.h(0,"speedMax"))
if(o==null)o=j
if(o==null)o=105
n=A.t(a.h(0,"accelMin"))
if(n==null)n=j
if(n==null)n=9
m=A.t(a.h(0,"accelMax"))
if(m==null)m=j
if(m==null)m=15
l=A.U(a.h(0,"collideWithEachOther"))
if(l==null)l=A.U(a.h(0,"enemiesCollide"))
k=A.t(a.h(0,"spinDegPerSec"))
if(k==null)k=j
if(k==null)k=0
return new A.bH(t,s,r,q,p,o,n,m,l===!0,k)},
e1(a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=null,a="warning",a0=A.U(a2.h(0,"startHintEnabled")),a1=A.t(a2.h(0,"idleSpeedMultiplier"))
if(a1==null)a1=b
if(a1==null)a1=0.5
t=A.U(a2.h(0,"idleEnemiesMove"))
s=A.t(a2.h(0,"speedRampSeconds"))
if(s==null)s=b
if(s==null)s=0.5
r=A.U(a2.h(0,"jumpEnabled"))
if(r==null)r=A.U(a2.h(0,"jumpsEnabled"))
q=A.t(a2.h(0,"jumpDurationSec"))
if(q==null)q=b
if(q==null)q=0.38
p=A.t(a2.h(0,"jumpCooldownSec"))
if(p==null)p=b
if(p==null)p=2
o=A.t(a2.h(0,"jumpScale"))
if(o==null)o=b
if(o==null)o=1.32
n=A.U(a2.h(0,"helmetEnabled"))
m=A.U(a2.h(0,"invulnerableHeroPushEnabled"))
l=A.t(a2.h(0,"helmetInvulnSec"))
if(l==null)l=b
if(l==null)l=0.3
k=A.t(a2.h(0,"helmetCooldownSec"))
if(k==null)k=b
if(k==null)k=0
j=A.t(a2.h(0,"startInvulnSec"))
if(j==null)j=b
if(j==null)j=1
i=A.U(a2.h(0,"heartbeatHaptic"))
h=A.U(a2.h(0,"timerHaptic"))
g=A.cf(a2.h(0,"timerHapticStyle"))
if(g==null)g=a
f=A.cf(a2.h(0,"timerHapticStyle5"))
if(f==null)f=a
e=A.cf(a2.h(0,"timerHapticStyle10"))
if(e==null)e=a
d=A.t(a2.h(0,"hudSpeedScaleMax"))
if(d==null)d=b
if(d==null)d=400
c=A.U(a2.h(0,"wallsKillPlayer"))
return new A.cr(a0!==!1,a1,t!==!1,s,r!==!1,q,p,o,n!==!1,m!==!1,l,k,j,i!==!1,h!==!1,g,f,e,d,c!==!1)},
ed(a,b){if(a==null)return b
if(typeof a!="number"||!isFinite(a)||a<0||a>0.5)throw A.c(B.B)
return a},
cF:function cF(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bH:function bH(a,b,c,d,e,f,g,h,i,j){var _=this
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
ck:function ck(){},
cV:function cV(a,b){this.a=a
this.b=b},
cq:function cq(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cr:function cr(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t){var _=this
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
_.cx=s
_.cy=t},
cj:function cj(){},
cT:function cT(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
fl(a){var t=new A.cm()
t.bm(a)
return t},
cm:function cm(){var _=this
_.y=_.x=_.w=_.r=_.f=_.e=_.d=_.c=_.b=_.a=$
_.as=_.Q=_.z=0
_.at=-100
_.cx=_.CW=_.ch=_.ay=0},
co:function co(a){this.a=a},
cn:function cn(a){this.a=a},
e2(a,b){return new A.l(Math.max(a.a,b.a),Math.max(a.b,b.b),Math.min(a.c,b.c),Math.min(a.d,b.d))},
b:function b(a,b){this.a=a
this.b=b},
cZ:function cZ(a,b){this.a=a
this.b=b},
l:function l(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bJ(a,b){var t
if(isFinite(a)&&a>0)t=isFinite(b)&&b>0&&Math.abs(a/b-1)<=0.030000001
else t=!1
return t},
fo(a3,a4,a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
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
if(!A.bJ(c,380)||!A.bJ(d.b,380))return"world_scale"
if(!A.bJ(g,a5.b)||!A.bJ(a4.c-f,a4.d-e))return"field_distorted"
t=A.e2(a4,a6)
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
if(A.bJ(s,r)){a0=s
if(typeof a0!=="number")return a0.al()
if(!(a0<0.03)){a=s
if(typeof a!=="number")return a.cc()
a=a>0.25}}if(a)return"hero_scale"
q=(a4.c-f)/c
p=(a4.d-e)/d.b
o=new A.cu(a7)
n=new A.ct(q,p,a3)
f=a7.w
f===$&&A.e()
e=f.a
f=f.b
if(!o.$1(new A.l(e,f,e+b,f+b))||!n.$2(b,b))return"hero_invisible"
g=g.a
f=g.b
e=A.G(f)
d=e.i("ar<1>")
a1=A.dx(new A.ar(f,e.i("w(1)").a(new A.cs()),d),d.i("d.E"))
m=a1
if(J.W(m)===0)J.dS(m,A.n([1,0.25,0.5,3],u.t))
f=a7.x
if(f.length!==4||J.W(m)!==4)return"enemy_count"
l=b*b*B.b.m(g.a,0.2,20)
k=0
for(;;){g=k
if(typeof g!=="number")return g.al()
if(!(g<4))break
j=B.a.h(f,k)
g=l
e=J.H(m,k)
if(typeof g!=="number")return g.W()
i=Math.sqrt(g*e)
e=l
g=J.H(m,k)
if(typeof e!=="number")return e.ak()
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
g===$&&A.e()
if(isFinite(g.a)&&isFinite(g.b))if(isFinite(j.CW))if(o.$1(j.gB())){g=j.c
g===$&&A.e()
g=g.a
e=j.c
e===$&&A.e()
e=e.b
g=!o.$1(new A.l(g,e,g+j.y,e+j.z))||!n.$2(j.y,j.z)}else g=e
else g=e
else g=e}else g=e
if(g)return"enemy_invisible"
g=j.b
if(isFinite(g.a)&&isFinite(g.b)){g=j.d
g===$&&A.e()
g=!(isFinite(g.a)&&isFinite(g.b))||!isFinite(j.ay)||j.ay<0||!isFinite(j.ch)||j.ch<0}else g=!0
if(g)return"enemy_motion"
g=k
if(typeof g!=="number")return g.K()
k=g+1}return null}catch(a2){return"world_not_ready"}},
cu:function cu(a){this.a=a},
ct:function ct(a,b,c){this.a=a
this.b=b
this.c=c},
cs:function cs(){},
e3(a){var t=new A.cG(A.n([],u.U))
t.bn(a)
return t},
cG:function cG(a){var _=this
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
cH:function cH(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=0
_.e=null},
hR(){var t,s,r={}
r.a=null
t=v.G.globalThis
r=new A.dm(r)
if(typeof r=="function")A.Y(A.ci("Attempting to rewrap a JS function."))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.h9,r)
s[$.dR()]=r
t.untouchKernel=s},
dm:function dm(a){this.a=a},
fF(a){var t,s,r,q
for(t=new A.aS(a),s=u.E,t=new A.aa(t,t.gk(0),s.i("aa<k.E>")),s=s.i("k.E"),r=2166136261;t.n();){q=t.d
r=(r^(q==null?s.a(q):q))>>>0
r=r*403+((r&255)<<24>>>0)>>>0}return r===0?1:r},
c3:function c3(a){this.a=a},
cp:function cp(a,b){this.a=a
this.b=b},
aW:function aW(){},
dr(a,b){var t,s
if(a.a6(b))return 0
t=Math.max(0,Math.max(a.a-b.c,b.a-a.c))
s=Math.max(0,Math.max(a.b-b.d,b.b-a.d))
if(t>0&&s>0)return Math.sqrt(t*t+s*s)
return Math.max(t,s)},
az:function az(a,b){this.a=a
this.b=b},
ah:function ah(a){this.a=a
this.b=0},
an:function an(a,b,c,d,e,f,g,h){var _=this
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
cl:function cl(a,b,c){this.a=a
this.b=b
this.c=c},
cv:function cv(a,b,c,d,e,f,g,h,i,j,k,l,m){var _=this
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
cC:function cC(a){this.a=a},
cB:function cB(){},
cD:function cD(){},
cw:function cw(){},
cx:function cx(){},
cy:function cy(){},
cz:function cz(){},
cA:function cA(a){this.a=a},
cE:function cE(a){this.a=a},
h9(a,b,c){u.Z.a(a)
if(A.ce(c)>=1)return a.$1(b)
return a.$0()},
eR(a,b,c){A.eM(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
eQ(a,b,c){A.eM(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.dv.prototype={}
J.bM.prototype={
R(a,b){return a===b},
gA(a){return A.c1(a)},
j(a){return"Instance of '"+A.c2(a)+"'"},
gu(a){return A.ad(A.dJ(this))}}
J.bO.prototype={
j(a){return String(a)},
gA(a){return a?519018:218159},
gu(a){return A.ad(u.y)},
$im:1,
$iw:1}
J.aY.prototype={
R(a,b){return null==b},
j(a){return"null"},
gA(a){return 0},
$im:1}
J.b_.prototype={$iz:1}
J.ag.prototype={
gA(a){return 0},
j(a){return String(a)}}
J.c0.prototype={}
J.aH.prototype={}
J.ae.prototype={
j(a){var t=a[$.eX()]
if(t==null)t=a[$.dR()]
if(t==null)return this.bl(a)
return"JavaScript function for "+J.bz(t)},
$ia7:1}
J.aZ.prototype={
gA(a){return 0},
j(a){return String(a)}}
J.b0.prototype={
gA(a){return 0},
j(a){return String(a)}}
J.o.prototype={
l(a,b){A.G(a).c.a(b)
a.$flags&1&&A.aR(a,29)
a.push(b)},
bB(a,b,c){var t,s,r,q,p
A.G(a).i("w(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.c(A.R(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
S(a,b){A.G(a).i("d<1>").a(b)
a.$flags&1&&A.aR(a,"addAll",2)
this.bp(a,b)
return},
bp(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.c(A.R(a))
for(s=0;s<t;++s)a.push(b[s])},
v(a){a.$flags&1&&A.aR(a,"clear","clear")
a.length=0},
a5(a,b,c){var t=A.G(a)
return new A.O(a,t.C(c).i("1(2)").a(b),t.i("@<1>").C(c).i("O<1,2>"))},
bT(a,b){var t,s=A.dy(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.q(s,t,A.v(a[t]))
return s.join(b)},
D(a,b){if(!(b>=0&&b<a.length))return A.i(a,b)
return a[b]},
gO(a){if(a.length>0)return a[0]
throw A.c(A.e4())},
aE(a,b){var t,s
A.G(a).i("w(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.c(A.R(a))}return!1},
bQ(a,b){var t,s
A.G(a).i("w(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(!b.$1(a[s]))return!1
if(a.length!==t)throw A.c(A.R(a))}return!0},
aM(a,b){var t,s,r,q
a.$flags&2&&A.aR(a,"shuffle")
t=a.length
while(t>1){s=b.bW(t);--t
r=a.length
if(!(t<r))return A.i(a,t)
q=a[t]
if(!(s>=0&&s<r))return A.i(a,s)
a[t]=a[s]
a[s]=q}},
a4(a,b){var t,s=a.length
if(0>=s)return-1
for(t=0;t<s;++t){if(!(t<a.length))return A.i(a,t)
if(J.C(a[t],b))return t}return-1},
F(a,b){var t
for(t=0;t<a.length;++t)if(J.C(a[t],b))return!0
return!1},
gG(a){return a.length===0},
gaL(a){return a.length!==0},
j(a){return A.dt(a,"[","]")},
gt(a){return new J.am(a,a.length,A.G(a).i("am<1>"))},
gA(a){return A.c1(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.aR(a,"set length","change the length of")
if(b>a.length)A.G(a).c.a(null)
a.length=b},
h(a,b){if(!(b>=0&&b<a.length))throw A.c(A.df(a,b))
return a[b]},
q(a,b,c){A.G(a).c.a(c)
a.$flags&2&&A.aR(a)
if(!(b>=0&&b<a.length))throw A.c(A.df(a,b))
a[b]=c},
$ih:1,
$id:1,
$ij:1}
J.bN.prototype={
c6(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.c2(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.cI.prototype={}
J.am.prototype={
gp(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.D(r)
throw A.c(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$iI:1}
J.aB.prototype={
aG(a,b){var t
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gaK(b)
if(this.gaK(a)===t)return 0
if(this.gaK(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gaK(a){return a===0?1/a<0:a<0},
aF(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.c(A.dE(""+a+".ceil()"))},
aI(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.c(A.dE(""+a+".floor()"))},
c1(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.c(A.dE(""+a+".round()"))},
m(a,b,c){if(this.aG(b,c)>0)throw A.c(A.eK(b))
if(this.aG(a,b)<0)return b
if(this.aG(a,c)>0)return c
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
am(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
aY(a,b){var t
if(a>0)t=this.bD(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
bD(a,b){return b>31?0:a>>>b},
gu(a){return A.ad(u.H)},
$if:1,
$ia0:1}
J.aX.prototype={
gu(a){return A.ad(u.S)},
$im:1,
$ia:1}
J.bP.prototype={
gu(a){return A.ad(u.i)},
$im:1}
J.aC.prototype={
ad(a,b,c){return a.substring(b,A.fE(b,c,a.length))},
be(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.i(q,0)
if(q.charCodeAt(0)===133){t=J.fv(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.i(q,s)
r=q.charCodeAt(s)===133?J.fw(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
j(a){return a},
gA(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gu(a){return A.ad(u.N)},
gk(a){return a.length},
$im:1,
$ip:1}
A.af.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.aS.prototype={
gk(a){return this.a.length},
h(a,b){var t=this.a
if(!(b>=0&&b<t.length))return A.i(t,b)
return t.charCodeAt(b)}}
A.cY.prototype={}
A.h.prototype={}
A.E.prototype={
gt(a){var t=this
return new A.aa(t,t.gk(t),A.q(t).i("aa<E.E>"))},
gG(a){return this.gk(this)===0},
a5(a,b,c){var t=A.q(this)
return new A.O(this,t.C(c).i("1(E.E)").a(b),t.i("@<E.E>").C(c).i("O<1,2>"))},
ai(a,b){var t,s,r,q=this
A.q(q).i("E.E(E.E,E.E)").a(b)
t=q.gk(q)
if(t===0)throw A.c(A.e4())
s=q.D(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.D(0,r))
if(t!==q.gk(q))throw A.c(A.R(q))}return s}}
A.bh.prototype={
gbt(){var t=J.W(this.a),s=this.c
if(s==null||s>t)return t
return s},
gbF(){var t=J.W(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.W(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
D(a,b){var t=this,s=t.gbF()+b
if(b<0||s>=t.gbt())throw A.c(A.ds(b,t.gk(0),t,"index"))
return J.dU(t.a,s)},
c5(a,b){var t,s,r,q=this,p=q.b,o=q.a,n=J.aP(o),m=n.gk(o),l=q.c
if(l!=null&&l<m)m=l
t=m-p
if(t<=0){o=q.$ti.c
return b?J.e6(0,o):J.e5(0,o)}s=A.dy(t,n.D(o,p),b,q.$ti.c)
for(r=1;r<t;++r){B.a.q(s,r,n.D(o,p+r))
if(n.gk(o)<m)throw A.c(A.R(q))}return s},
bd(a){return this.c5(0,!0)}}
A.aa.prototype={
gp(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=J.aP(r),p=q.gk(r)
if(s.b!==p)throw A.c(A.R(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.D(r,t);++s.c
return!0},
$iI:1}
A.aq.prototype={
gt(a){var t=this.a
return new A.b4(t.gt(t),this.b,A.q(this).i("b4<1,2>"))},
gk(a){var t=this.a
return t.gk(t)}}
A.aV.prototype={$ih:1}
A.b4.prototype={
n(){var t=this,s=t.b
if(s.n()){t.a=t.c.$1(s.gp())
return!0}t.a=null
return!1},
gp(){var t=this.a
return t==null?this.$ti.y[1].a(t):t},
$iI:1}
A.O.prototype={
gk(a){return J.W(this.a)},
D(a,b){return this.b.$1(J.dU(this.a,b))}}
A.ar.prototype={
gt(a){return new A.bl(J.ch(this.a),this.b,this.$ti.i("bl<1>"))}}
A.bl.prototype={
n(){var t,s
for(t=this.a,s=this.b;t.n();)if(s.$1(t.gp()))return!0
return!1},
gp(){return this.a.gp()},
$iI:1}
A.K.prototype={}
A.bj.prototype={}
A.aI.prototype={}
A.aK.prototype={$r:"+(1,2)",$s:1}
A.aT.prototype={
gG(a){return this.gk(this)===0},
j(a){return A.dz(this)},
gag(){return new A.aL(this.bP(),A.q(this).i("aL<M<1,2>>"))},
bP(){var t=this
return function(){var s=0,r=1,q=[],p,o,n,m,l
return function $async$gag(a,b,c){if(b===1){q.push(c)
s=r}for(;;)switch(s){case 0:p=t.gH(),p=p.gt(p),o=A.q(t),n=o.y[1],o=o.i("M<1,2>")
case 2:if(!p.n()){s=3
break}m=p.gp()
l=t.h(0,m)
s=4
return a.b=new A.M(m,l==null?n.a(l):l,o),1
case 4:s=2
break
case 3:return 0
case 1:return a.c=q.at(-1),3}}}},
$ia2:1}
A.aU.prototype={
gk(a){return this.b.length},
gaU(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
L(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.L(b))return null
return this.b[this.a[b]]},
P(a,b){var t,s,r,q
this.$ti.i("~(1,2)").a(b)
t=this.gaU()
s=this.b
for(r=t.length,q=0;q<r;++q)b.$2(t[q],s[q])},
gH(){return new A.bm(this.gaU(),this.$ti.i("bm<1>"))}}
A.bm.prototype={
gk(a){return this.a.length},
gt(a){var t=this.a
return new A.bn(t,t.length,this.$ti.i("bn<1>"))}}
A.bn.prototype={
gp(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t=this,s=t.c
if(s>=t.b){t.d=null
return!1}t.d=t.a[s]
t.c=s+1
return!0},
$iI:1}
A.bL.prototype={
R(a,b){if(b==null)return!1
return b instanceof A.ao&&this.a.R(0,b.a)&&A.dN(this)===A.dN(b)},
gA(a){return A.ee(this.a,A.dN(this),B.h,B.h)},
j(a){var t=B.a.bT([A.ad(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.ao.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hO(A.de(this.a),this.$ti)}}
A.cW.prototype={
$0(){return B.b.aI(1000*this.a.now())},
$S:1}
A.bd.prototype={}
A.d0.prototype={
I(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
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
A.ba.prototype={
j(a){return"Null check operator used on a null value"}}
A.bQ.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.c8.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.cU.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.J.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.eV(s==null?"unknown":s)+"'"},
$ia7:1,
gcb(){return this},
$C:"$1",
$R:1,
$D:null}
A.bC.prototype={$C:"$0",$R:0}
A.bD.prototype={$C:"$2",$R:2}
A.c6.prototype={}
A.c5.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.eV(t)+"'"}}
A.aA.prototype={
R(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.aA))return!1
return this.$_target===b.$_target&&this.a===b.a},
gA(a){return(A.eS(this.a)^A.c1(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.c2(this.a)+"'")}}
A.c4.prototype={
j(a){return"RuntimeError: "+this.a}}
A.a8.prototype={
gk(a){return this.a},
gG(a){return this.a===0},
gH(){return new A.a9(this,A.q(this).i("a9<1>"))},
gag(){return new A.Z(this,A.q(this).i("Z<1,2>"))},
L(a){var t=this.b
if(t==null)return!1
return t[a]!=null},
S(a,b){A.q(this).i("a2<1,2>").a(b).P(0,new A.cJ(this))},
h(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.bR(b)},
bR(a){var t,s,r=this.d
if(r==null)return null
t=r[this.b4(a)]
s=this.b5(t,a)
if(s<0)return null
return t[s].b},
q(a,b,c){var t,s,r=this,q=A.q(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.aP(t==null?r.b=r.az():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.aP(s==null?r.c=r.az():s,b,c)}else r.bS(b,c)},
bS(a,b){var t,s,r,q,p=this,o=A.q(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.az()
s=p.b4(a)
r=t[s]
if(r==null)t[s]=[p.aA(a,b)]
else{q=p.b5(r,a)
if(q>=0)r[q].b=b
else r.push(p.aA(a,b))}},
v(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.aV()}},
P(a,b){var t,s,r=this
A.q(r).i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.c(A.R(r))
t=t.c}},
aP(a,b,c){var t,s=A.q(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.aA(b,c)
else t.b=c},
aV(){this.r=this.r+1&1073741823},
aA(a,b){var t=this,s=A.q(t),r=new A.cN(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.aV()
return r},
b4(a){return J.Q(a)&1073741823},
b5(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.C(a[s].a,b))return s
return-1},
j(a){return A.dz(this)},
az(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$ie9:1}
A.cJ.prototype={
$2(a,b){var t=this.a,s=A.q(t)
t.q(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.q(this.a).i("~(1,2)")}}
A.cN.prototype={}
A.a9.prototype={
gk(a){return this.a.a},
gG(a){return this.a.a===0},
gt(a){var t=this.a
return new A.ap(t,t.r,t.e,this.$ti.i("ap<1>"))},
F(a,b){return this.a.L(b)}}
A.ap.prototype={
gp(){return this.d},
n(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.c(A.R(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$iI:1}
A.Z.prototype={
gk(a){return this.a.a},
gt(a){var t=this.a
return new A.b3(t,t.r,t.e,this.$ti.i("b3<1,2>"))}}
A.b3.prototype={
gp(){var t=this.d
t.toString
return t},
n(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.c(A.R(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=new A.M(t.a,t.b,s.$ti.i("M<1,2>"))
s.c=t.c
return!0}},
$iI:1}
A.di.prototype={
$1(a){return this.a(a)},
$S:2}
A.dj.prototype={
$2(a,b){return this.a(a,b)},
$S:7}
A.dk.prototype={
$1(a){return this.a(A.ac(a))},
$S:8}
A.au.prototype={
j(a){return this.aZ(!1)},
aZ(a){var t,s,r,q,p,o=this.bu(),n=this.aT(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.i(n,r)
p=n[r]
m=a?m+A.eg(p):m+A.v(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
bu(){var t,s=this.$s
while($.d8.length<=s)B.a.l($.d8,null)
t=$.d8[s]
if(t==null){t=this.bq()
B.a.q($.d8,s,t)}return t},
bq(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=u.K,k=J.du(m,l)
for(t=0;t<m;++t)k[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.q(k,r,s[t])}}k=A.ec(k,!1,l)
k.$flags=3
return k}}
A.aJ.prototype={
aT(){return[this.a,this.b]},
R(a,b){if(b==null)return!1
return b instanceof A.aJ&&this.$s===b.$s&&J.C(this.a,b.a)&&J.C(this.b,b.b)},
gA(a){return A.ee(this.$s,this.a,this.b,B.h)}}
A.d2.prototype={
X(){var t=this.b
if(t===this)throw A.c(new A.af("Local '' has not been initialized."))
return t}}
A.aD.prototype={
gu(a){return B.Q},
$im:1}
A.b7.prototype={}
A.bS.prototype={
gu(a){return B.R},
$im:1}
A.aE.prototype={
gk(a){return a.length},
$iT:1}
A.b5.prototype={
h(a,b){A.av(b,a,a.length)
return a[b]},
$ih:1,
$id:1,
$ij:1}
A.b6.prototype={$ih:1,$id:1,$ij:1}
A.bT.prototype={
gu(a){return B.S},
$im:1}
A.bU.prototype={
gu(a){return B.T},
$im:1}
A.bV.prototype={
gu(a){return B.U},
h(a,b){A.av(b,a,a.length)
return a[b]},
$im:1}
A.bW.prototype={
gu(a){return B.V},
h(a,b){A.av(b,a,a.length)
return a[b]},
$im:1}
A.bX.prototype={
gu(a){return B.W},
h(a,b){A.av(b,a,a.length)
return a[b]},
$im:1}
A.bY.prototype={
gu(a){return B.Y},
h(a,b){A.av(b,a,a.length)
return a[b]},
$im:1}
A.bZ.prototype={
gu(a){return B.Z},
h(a,b){A.av(b,a,a.length)
return a[b]},
$im:1}
A.b8.prototype={
gu(a){return B.a_},
gk(a){return a.length},
h(a,b){A.av(b,a,a.length)
return a[b]},
$im:1}
A.c_.prototype={
gu(a){return B.a0},
gk(a){return a.length},
h(a,b){A.av(b,a,a.length)
return a[b]},
$im:1}
A.bp.prototype={}
A.bq.prototype={}
A.br.prototype={}
A.bs.prototype={}
A.a_.prototype={
i(a){return A.by(v.typeUniverse,this,a)},
C(a){return A.ey(v.typeUniverse,this,a)}}
A.ca.prototype={}
A.d9.prototype={
j(a){return A.N(this.a,null)}}
A.c9.prototype={
j(a){return this.a}}
A.aM.prototype={}
A.bu.prototype={
gp(){var t=this.b
return t==null?this.$ti.c.a(t):t},
bC(a,b){var t,s,r
a=A.ce(a)
b=b
t=this.a
for(;;)try{s=t(this,a,b)
return s}catch(r){b=r
a=1}},
n(){var t,s,r,q,p=this,o=null,n=0
for(;;){t=p.d
if(t!=null)try{if(t.n()){p.b=t.gp()
return!0}else p.d=null}catch(s){o=s
n=1
p.d=null}r=p.bC(n,o)
if(1===r)return!0
if(0===r){p.b=null
q=p.e
if(q==null||q.length===0){p.a=A.et
return!1}if(0>=q.length)return A.i(q,-1)
p.a=q.pop()
n=0
o=null
continue}if(2===r){n=0
o=null
continue}if(3===r){o=p.c
p.c=null
q=p.e
if(q==null||q.length===0){p.b=null
p.a=A.et
throw o
return!1}if(0>=q.length)return A.i(q,-1)
p.a=q.pop()
n=1
continue}throw A.c(A.bg("sync*"))}return!1},
cd(a){var t,s,r=this
if(a instanceof A.aL){t=a.a()
s=r.e
if(s==null)s=r.e=[]
B.a.l(s,r.a)
r.a=t
return 2}else{r.d=J.ch(a)
return 2}},
$iI:1}
A.aL.prototype={
gt(a){return new A.bu(this.a(),this.$ti.i("bu<1>"))}}
A.bo.prototype={
gt(a){var t=this,s=new A.as(t,t.r,t.$ti.i("as<1>"))
s.c=t.e
return s},
gk(a){return this.a},
F(a,b){var t
if((b&1073741823)===b){t=this.c
if(t==null)return!1
return u.g.a(t[b])!=null}else return this.bs(b)},
bs(a){var t=this.d
if(t==null)return!1
return this.aw(t[B.c.gA(a)&1073741823],a)>=0},
l(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.aQ(t==null?r.b=A.dF():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.aQ(s==null?r.c=A.dF():s,b)}else return r.bo(b)},
bo(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.dF()
s=J.Q(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.aq(a)]
else{if(q.aw(r,a)>=0)return!1
r.push(q.aq(a))}return!0},
Z(a,b){var t=this
if(typeof b=="string"&&b!=="__proto__")return t.aX(t.b,b)
else if(typeof b=="number"&&(b&1073741823)===b)return t.aX(t.c,b)
else return t.bA(b)},
bA(a){var t,s,r,q,p=this.d
if(p==null)return!1
t=J.Q(a)&1073741823
s=p[t]
r=this.aw(s,a)
if(r<0)return!1
q=s.splice(r,1)[0]
if(0===s.length)delete p[t]
this.b_(q)
return!0},
v(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.ap()}},
aQ(a,b){this.$ti.c.a(b)
if(u.g.a(a[b])!=null)return!1
a[b]=this.aq(b)
return!0},
aX(a,b){var t
if(a==null)return!1
t=u.g.a(a[b])
if(t==null)return!1
this.b_(t)
delete a[b]
return!0},
ap(){this.r=this.r+1&1073741823},
aq(a){var t,s=this,r=new A.cd(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.ap()
return r},
b_(a){var t=this,s=a.c,r=a.b
if(s==null)t.e=r
else s.b=r
if(r==null)t.f=s
else r.c=s;--t.a
t.ap()},
aw(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.C(a[s].a,b))return s
return-1}}
A.cd.prototype={}
A.as.prototype={
gp(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.c(A.R(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.i("1?").a(s.a)
t.c=s.b
return!0}},
$iI:1}
A.cP.prototype={
$2(a,b){this.a.q(0,this.b.a(a),this.c.a(b))},
$S:9}
A.k.prototype={
gt(a){return new A.aa(a,this.gk(a),A.al(a).i("aa<k.E>"))},
D(a,b){return this.h(a,b)},
gG(a){return this.gk(a)===0},
gaL(a){return this.gk(a)!==0},
aE(a,b){var t,s
A.al(a).i("w(k.E)").a(b)
t=this.gk(a)
for(s=0;s<t;++s){if(b.$1(this.h(a,s)))return!0
if(t!==this.gk(a))throw A.c(A.R(a))}return!1},
a5(a,b,c){var t=A.al(a)
return new A.O(a,t.C(c).i("1(k.E)").a(b),t.i("@<k.E>").C(c).i("O<1,2>"))},
j(a){return A.dt(a,"[","]")},
$ih:1,
$id:1,
$ij:1}
A.x.prototype={
P(a,b){var t,s,r,q=A.q(this)
q.i("~(x.K,x.V)").a(b)
for(t=this.gH(),t=t.gt(t),q=q.i("x.V");t.n();){s=t.gp()
r=this.h(0,s)
b.$2(s,r==null?q.a(r):r)}},
gag(){return this.gH().a5(0,new A.cR(this),A.q(this).i("M<x.K,x.V>"))},
L(a){return this.gH().F(0,a)},
gk(a){var t=this.gH()
return t.gk(t)},
gG(a){var t=this.gH()
return t.gG(t)},
j(a){return A.dz(this)},
$ia2:1}
A.cR.prototype={
$1(a){var t=this.a,s=A.q(t)
s.i("x.K").a(a)
t=t.h(0,a)
if(t==null)t=s.i("x.V").a(t)
return new A.M(a,t,s.i("M<x.K,x.V>"))},
$S(){return A.q(this.a).i("M<x.K,x.V>(x.K)")}}
A.cS.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.v(a)
s.a=(s.a+=t)+": "
t=A.v(b)
s.a+=t},
$S:3}
A.aF.prototype={
S(a,b){var t,s,r
this.$ti.i("d<1>").a(b)
for(t=A.fO(b,b.r,b.$ti.c),s=t.$ti.c;t.n();){r=t.d
this.l(0,r==null?s.a(r):r)}},
j(a){return A.dt(this,"{","}")},
$ih:1,
$id:1,
$idC:1}
A.bt.prototype={}
A.cb.prototype={
h(a,b){var t,s=this.b
if(s==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.bx(b):t}},
gk(a){return this.b==null?this.c.a:this.af().length},
gG(a){return this.gk(0)===0},
gH(){if(this.b==null){var t=this.c
return new A.a9(t,A.q(t).i("a9<1>"))}return new A.cc(this)},
L(a){if(this.b==null)return this.c.L(a)
return Object.prototype.hasOwnProperty.call(this.a,a)},
P(a,b){var t,s,r,q,p=this
u.D.a(b)
if(p.b==null)return p.c.P(0,b)
t=p.af()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.dc(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.c(A.R(p))}},
af(){var t=u.e.a(this.c)
if(t==null)t=this.c=A.n(Object.keys(this.a),u.s)
return t},
bx(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.dc(this.a[a])
return this.b[a]=t}}
A.cc.prototype={
gk(a){return this.a.gk(0)},
D(a,b){var t=this.a
if(t.b==null)t=t.gH().D(0,b)
else{t=t.af()
if(!(b>=0&&b<t.length))return A.i(t,b)
t=t[b]}return t},
gt(a){var t=this.a
if(t.b==null){t=t.gH()
t=t.gt(t)}else{t=t.af()
t=new J.am(t,t.length,A.G(t).i("am<1>"))}return t},
F(a,b){return this.a.L(b)}}
A.bE.prototype={}
A.bG.prototype={}
A.b1.prototype={
j(a){var t=A.bI(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.bR.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.cK.prototype={
bL(a,b){var t=A.hv(a,this.gbM().a)
return t},
a2(a,b){var t=A.fN(a,this.gbN().b,null)
return t},
gbN(){return B.L},
gbM(){return B.K}}
A.cM.prototype={}
A.cL.prototype={}
A.d6.prototype={
bg(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.e.ad(a,s,r)
s=r+1
p=A.F(92)
t.a+=p
p=A.F(117)
t.a+=p
p=A.F(100)
t.a+=p
p=q>>>8&15
p=A.F(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.F(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.F(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.e.ad(a,s,r)
s=r+1
p=A.F(92)
t.a+=p
switch(q){case 8:p=A.F(98)
t.a+=p
break
case 9:p=A.F(116)
t.a+=p
break
case 10:p=A.F(110)
t.a+=p
break
case 12:p=A.F(102)
t.a+=p
break
case 13:p=A.F(114)
t.a+=p
break
default:p=A.F(117)
t.a+=p
p=A.F(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.F(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.F(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.e.ad(a,s,r)
s=r+1
p=A.F(92)
t.a+=p
p=A.F(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.e.ad(a,s,n)},
ao(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.c(new A.bR(a,null))}B.a.l(t,a)},
aj(a){var t,s,r,q,p=this
if(p.bf(a))return
p.ao(a)
try{t=p.b.$1(a)
if(!p.bf(t)){r=A.e8(a,null,p.gaW())
throw A.c(r)}r=p.a
if(0>=r.length)return A.i(r,-1)
r.pop()}catch(q){s=A.eW(q)
r=A.e8(a,s,p.gaW())
throw A.c(r)}},
bf(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.bg(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.ao(a)
r.c9(a)
t=r.a
if(0>=t.length)return A.i(t,-1)
t.pop()
return!0}else if(u.f.b(a)){r.ao(a)
s=r.ca(a)
t=r.a
if(0>=t.length)return A.i(t,-1)
t.pop()
return s}else return!1},
c9(a){var t,s,r=this.c
r.a+="["
t=J.aP(a)
if(t.gaL(a)){this.aj(t.h(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.aj(t.h(a,s))}}r.a+="]"},
ca(a){var t,s,r,q,p,o,n=this,m={}
if(a.gG(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.dy(t,null,!1,u.X)
r=m.a=0
m.b=!0
a.P(0,new A.d7(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.bg(A.ac(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.i(s,o)
n.aj(s[o])}q.a+="}"
return!0}}
A.d7.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.q(t,s.a++,a)
B.a.q(t,s.a++,b)},
$S:3}
A.d5.prototype={
gaW(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.u.prototype={}
A.bA.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bI(t)
return"Assertion failed"}}
A.bi.prototype={}
A.a5.prototype={
gau(){return"Invalid argument"+(!this.a?"(s)":"")},
gar(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+A.v(q),o=t.gau()+r+p
if(!t.a)return o
return o+t.gar()+": "+A.bI(t.gaJ())},
gaJ(){return this.b}}
A.bb.prototype={
gaJ(){return A.t(this.b)},
gau(){return"RangeError"},
gar(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.v(r):""
else if(r==null)t=": Not greater than or equal to "+A.v(s)
else if(r>s)t=": Not in inclusive range "+A.v(s)+".."+A.v(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.v(s)
return t}}
A.bK.prototype={
gaJ(){return A.ce(this.b)},
gau(){return"RangeError"},
gar(){if(A.ce(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.bk.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.c7.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.bf.prototype={
j(a){return"Bad state: "+this.a}}
A.bF.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bI(t)+"."}}
A.be.prototype={
j(a){return"Stack Overflow"},
$iu:1}
A.a6.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.d.prototype={
a5(a,b,c){var t=A.q(this)
return A.fA(this,t.C(c).i("1(d.E)").a(b),t.i("d.E"),c)},
gk(a){var t,s=this.gt(this)
for(t=0;s.n();)++t
return t},
D(a,b){var t,s
A.dA(b,"index")
t=this.gt(this)
for(s=b;t.n();){if(s===0)return t.gp();--s}throw A.c(A.ds(b,b-s,this,"index"))},
j(a){return A.ft(this,"(",")")}}
A.M.prototype={
j(a){return"MapEntry("+A.v(this.a)+": "+A.v(this.b)+")"}}
A.b9.prototype={
gA(a){return A.r.prototype.gA.call(this,0)},
j(a){return"null"}}
A.r.prototype={$ir:1,
R(a,b){return this===b},
gA(a){return A.c1(this)},
j(a){return"Instance of '"+A.c2(this)+"'"},
gu(a){return A.hI(this)},
toString(){return this.j(this)}}
A.d_.prototype={}
A.aG.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$ifH:1}
A.cF.prototype={}
A.bH.prototype={
a_(){var t=this
return A.L(["areaMultiplier",t.a,"aspects",t.b,"angleMinDeg",t.c,"angleMaxDeg",t.d,"speedMin",t.e,"speedMax",t.f,"accelMin",t.r,"accelMax",t.w,"collideWithEachOther",t.x,"spinDegPerSec",t.y],u.N,u.z)}}
A.ck.prototype={
$1(a){return A.y(a)},
$S:10}
A.cV.prototype={
a_(){return A.L(["size",this.a,"showFace",this.b],u.N,u.z)}}
A.cq.prototype={
a_(){var t,s=this,r=A.cO(u.N,u.z)
r.q(0,"borderWidth",s.a)
r.q(0,"brightness",s.b)
r.q(0,"shadowBrightness",s.c)
t=s.d
if(t!=null&&t.length!==0)r.q(0,"color",t)
return r}}
A.cr.prototype={
a_(){var t=this
return A.L(["startHintEnabled",t.a,"idleSpeedMultiplier",t.b,"idleEnemiesMove",t.c,"speedRampSeconds",t.d,"jumpEnabled",t.e,"jumpDurationSec",t.f,"jumpCooldownSec",t.r,"jumpScale",t.w,"helmetEnabled",t.x,"invulnerableHeroPushEnabled",t.y,"helmetInvulnSec",t.z,"helmetCooldownSec",t.Q,"startInvulnSec",t.as,"heartbeatHaptic",t.at,"timerHaptic",t.ax,"timerHapticStyle",t.ay,"timerHapticStyle5",t.ch,"timerHapticStyle10",t.CW,"hudSpeedScaleMax",t.cx,"wallsKillPlayer",t.cy],u.N,u.z)}}
A.cj.prototype={
a_(){return A.L(["sfxMobWall",!0,"sfxMobCollide",!0,"sfxHeroMob",!0,"sfxHeroWall",!0,"sfxNearMiss",!0,"sfxHelmet",!0,"sfxJump",!0,"sfxBrake",!0,"sfxStart",!0,"music",!0,"sfxVolume",1,"musicVolume",0.08],u.N,u.z)}}
A.cT.prototype={}
A.cm.prototype={
bm(a){var t=this,s=u.f.b(a)?a:B.M,r=new A.co(s),q=new A.cn(s),p=A.dI(q.$1("brakeEnabled"))
t.a!==$&&A.P()
t.a=p
q=A.dI(q.$1("speedBarEnabled"))
t.b!==$&&A.P()
t.b=q
q=A.a3(r.$4("initialSpeed",0,0,150))
t.c!==$&&A.P()
t.c=q
q=A.a3(r.$4("growthMultiplier",70,0,200))
t.d!==$&&A.P()
t.d=q
q=A.a3(r.$4("growthExponent",0.2,0.01,1))
t.e!==$&&A.P()
t.e=q
q=A.a3(r.$4("startSmoothingSec",3,0.01,60))
t.f!==$&&A.P()
t.f=q
q=A.a3(r.$4("initialCompensation",1,0,10))
t.r!==$&&A.P()
t.r=q
q=A.a3(r.$4("brakeCooldownSec",6,0.1,120))
t.w!==$&&A.P()
t.w=q
q=A.a3(r.$4("brakeFirstReadySec",6,0.1,120))
t.x!==$&&A.P()
t.x=q
r=A.a3(r.$4("brakeRewindSec",6,0,120))
t.y!==$&&A.P()
t.y=r
t.as=q},
an(a){var t,s,r,q,p=this,o=p.c
o===$&&A.e()
t=p.d
t===$&&A.e()
s=Math.max(0,a)
r=p.f
r===$&&A.e()
q=p.e
q===$&&A.e()
q=Math.pow(s+r,q)
r=p.r
r===$&&A.e()
return Math.max(0,o+t*(q-r))},
gac(){var t=this
return t.an(t.Q)+t.ay*B.b.m(1-(t.z-t.at)/0.18,0,1)},
ga8(){var t=this.a
t===$&&A.e()
return t&&this.z+1e-9>=this.as},
bY(){var t,s,r=this
if(!r.ga8())return!1
r.ch=r.gac()
t=r.Q
s=r.y
s===$&&A.e()
s=Math.max(0,t-s)
r.Q=s
s=r.an(s)
r.CW=s
r.ay=Math.max(0,r.ch-s)
s=r.z
r.at=s
t=r.w
t===$&&A.e()
r.as=s+t;++r.cx
return!0},
bZ(a,b,c,d,e,f){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this.a
g===$&&A.e()
if(!g||!this.ga8()||!c)return!1
t=d/2
for(g=u.t,g=[A.n([a+t,e+t],g),A.n([b+t,f+t],g)],s=190-d,r=190+d,q=0,p=1,o=0;o<2;++o){n=g[o]
if(1>=n.length)return A.i(n,1)
m=n[1]
l=n[0]
k=m-l
if(Math.abs(k)<1e-9){if(l<=s||l>=r)return!1}else{j=(s-l)/k
i=(r-l)/k
if(j>i){h=i
i=j
j=h}q=Math.max(q,j)
p=Math.min(p,i)}}return q<=p&&this.bY()}}
A.co.prototype={
$4(a,b,c,d){var t=this.a.h(0,a)
if(t==null)t=b
if(typeof t!="number"||!isFinite(t)||t<c||t>d)throw A.c(A.S("enemy_pace_"+a))
return t},
$S:11}
A.cn.prototype={
$1(a){var t=this.a,s=!t.L(a)||t.h(0,a)
if(!A.dd(s))throw A.c(A.S("enemy_pace_"+a))
return s},
$S:12}
A.b.prototype={
K(a,b){return new A.b(this.a+b.a,this.b+b.b)},
a0(a,b){return new A.b(this.a-b.a,this.b-b.b)},
W(a,b){return new A.b(this.a*b,this.b*b)},
ak(a,b){return new A.b(this.a/b,this.b/b)},
gb1(){var t=this.a,s=this.b
return Math.sqrt(t*t+s*s)}}
A.cZ.prototype={}
A.l.prototype={
gN(){var t=this
return new A.b((t.a+t.c)/2,(t.b+t.d)/2)},
a6(a){var t=this
return t.a<a.c&&t.c>a.a&&t.b<a.d&&t.d>a.b},
b3(a){var t=this
return new A.l(t.a-a,t.b-a,t.c+a,t.d+a)}}
A.cu.prototype={
$1(a){var t,s,r,q=a.a,p=a.b
if(isFinite(q)&&isFinite(p)){s=a.c-q
r=a.d-p
r=!(isFinite(s)&&s>0&&isFinite(r)&&r>0)
s=r}else s=!0
if(s)return!1
s=this.a.b
t=A.e2(a,new A.l(0,0,0+s.a,0+s.b))
s=t
if(!(s.c-s.a<=0||s.d-s.b<=0)){s=t
r=t
p=(s.c-s.a)*(r.d-r.b)/((a.c-q)*(a.d-p))>=0.97
q=p}else q=!1
return q},
$S:13}
A.ct.prototype={
$2(a,b){return Math.min(a*this.a,b*this.b)*this.c>=8},
$S:14}
A.cs.prototype={
$1(a){A.a3(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.cG.prototype={
a3(a){var t,s=this,r=s.e
r===$&&A.e()
t=r.c
s.aO(a)
if(!t&&r.c)s.cx=s.x},
ga9(){var t,s,r,q,p=this,o=u.N,n=A.eb(A.aW.prototype.ga9.call(p),o,u.z),m=p.e
m===$&&A.e()
t=m.b
s=m.gbb()
if(m.c)r=1
else r=t>0&&m.e!=null?B.b.m(1-m.gbb()/t,0,1):0
q=p.cx
q=q==null?null:p.x-q
n.q(0,"helmetCharge",A.L(["equipped",m.a,"cooldownMs",t,"remainingMs",s,"progress",r,"readyAgeMs",q,"breaks",p.cy],o,u.X))
return n}}
A.cH.prototype={
bI(a){var t,s=this
if(!isFinite(a)||a<s.d)throw A.c(A.dV(a,"nowMs",null))
s.d=a
t=!1
if(!s.c)if(s.a){t=s.e
t=t!=null&&a>=t}if(t){s.c=!0
s.e=null
return!0}return!1},
bK(){var t,s=this
if(!s.c)return!1
s.c=!1
t=s.b
s.e=t>0?s.d+t:null
return!0},
gbb(){var t=this.e
return t==null?0:Math.max(0,t-this.d)}}
A.dm.prototype={
$1(a8){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=null,a5="events",a6="startPose",a7="proofVersion"
A.ac(a8)
try{j=u.c
t=j.a(B.d.bL(a8,a4))
s=J.H(t,"op")
if(J.C(s,"verify")){r=J.H(t,"proof")
k=!0
if(u.f.b(r))if(B.a.F(A.n([3,4,5,6],u.Y),r.h(0,"version"))){k=u.j
k=!k.b(r.h(0,a5))||J.W(k.a(r.h(0,a5)))>6e5||!k.b(r.h(0,a6))}if(k){q=A.S("proof")
throw A.c(q)}k=u.N
j=u.z
q=A.eb(t,k,j)
J.dq(q,a7,r.h(0,"version"))
J.dq(q,a6,r.h(0,a6))
p=A.e3(q)
p.aN()
for(q=J.ch(u.R.a(r.h(0,a5))),i=u.j;q.n();){o=q.gp()
if(!i.b(o)||J.f9(o)){q=A.S("event")
throw A.c(q)}if(J.C(J.H(o,0),2)){if(J.W(o)!==1){q=A.S("jump")
throw A.c(q)}n=p.ay
p.b6()
h=p.ay
g=n
if(typeof g!=="number")return g.K()
if(h!==g+1){q=A.S("jump")
throw A.c(q)}}else{if(!(J.C(J.H(o,0),0)&&J.W(o)!==2))h=J.C(J.H(o,0),1)&&J.W(o)!==3
else h=!0
if(h){q=A.S("event")
throw A.c(q)}h=p
g=h.e
g===$&&A.e()
f=g.c
h.aO(o)
if(!f&&g.c)h.cx=h.x}}if(!p.z){q=A.S("unfinished")
throw A.c(q)}m=p.ga9()
e=B.d.a2(A.L(["ok",!0,"timeMs",J.H(m,"timeMs"),"runDistance",J.H(m,"runDistance"),"riskCount",J.H(m,"riskCount")],k,j),a4)
return e}if(J.C(s,"rewardFrame")){q=A.y(J.H(t,"p"))
k=J.C(J.H(t,"reduced"),!0)
l=new A.cp(B.b.m(q,0,1),k)
k=l.a
q=B.b.m(l.a/0.1125,0,1)
j=l.gV()
i=l.gb2()
h=l
if(h.b)h=1
else{g=B.b.m(h.a/0.1125,0,1)-1
h=(0.82+0.18*(1+2.70158*Math.pow(g,3)+1.70158*Math.pow(g,2)))*(1-0.78*h.gb2())}g=l
d=B.b.m(g.a/0.1125,0,1)
g=B.b.m((g.gV()-0.76)/0.24,0,1)
c=l
b=c.a
c=c.b
a=c?0.5:0.8
c=c?0.5:0.2
c=Math.pow(1-B.b.m((b-a)/c,0,1),3)
a=l
b=a.b?0:Math.sin(3.141592653589793*B.b.m((a.a-0.83)/0.17,0,1))
e=B.d.a2(A.L(["ok",!0,"p",k,"appearance",q,"flight",j,"fly",i,"scale",h,"opacity",d*(1-g),"roll",1-c,"hit",b],u.N,u.K),a4)
return e}if(J.C(s,"create")){if(t.L(a7)&&!B.a.F(A.n([3,4,5,6],u.Y),J.H(t,a7))){q=A.S("proof_version")
throw A.c(q)}q=this.a
q.a=A.e3(t)}else{q=this.a
i=q.a
if(i==null){q=A.bg("session_missing")
throw A.c(q)}switch(s){case"idle":j=A.y(J.H(t,"ms"))
if(i.y||i.z||!isFinite(j)||j<=0||j>50)A.Y(A.bg("idle"))
h=i.d
h===$&&A.e()
a0=h.c2(j/1000)
i.at=a0.a
i.ax=a0.b
break
case"start":i.aN()
break
case"tick":i.a3([0,J.H(t,"ms")])
break
case"move":j=A.y(J.H(t,"dx"))
h=A.y(J.H(t,"dy"))
if(!i.y)A.Y(A.bg("move"))
if(i.x===0)i.a3([0,1])
if(!i.z)i.a3([1,j,h])
break
case"jump":i.b6()
break
case"snapshot":break
case"proof":q=i.a
q===$&&A.e()
k=u.N
e=B.d.a2(A.L(["ok",!0,"proof",A.L(["version",q,"events",i.ch,"startPose",i.CW],k,u.z)],k,u.K),a4)
return e
case"guard":q=j.a(t)
k=u.j
a1=k.a(q.h(0,"field"))
a2=k.a(q.h(0,"visible"))
i=i.d
i===$&&A.e()
k=J.a4(a1)
j=A.y(k.h(a1,0))
h=A.y(k.h(a1,1))
g=A.y(k.h(a1,2))
k=A.y(k.h(a1,3))
d=J.a4(a2)
c=A.y(d.h(a2,0))
b=A.y(d.h(a2,1))
a=A.y(d.h(a2,2))
d=A.y(d.h(a2,3))
e=B.d.a2(A.L(["ok",!0,"issue",A.fo(A.y(q.h(0,"dpr")),new A.l(j,h,j+g,h+k),B.r,new A.l(c,b,c+a,b+d),i)],u.N,u.X),a4)
return e
default:q=A.S("unknown_operation")
throw A.c(q)}}k=A.cO(u.N,u.z)
J.dq(k,"ok",!0)
J.dS(k,q.a.ga9())
e=B.d.a2(k,a4)
return e}catch(a3){return'{"ok":false,"error":"invalid_kernel_operation"}'}},
$S:15}
A.c3.prototype={
bw(){var t=this.a
t^=t<<13
t^=t>>>17
return this.a=(t^t<<5)>>>0},
J(){var t=this.a
t^=t<<13
t^=t>>>17
t=(t^t<<5)>>>0
this.a=t
return t/4294967296},
bW(a){if(a<=0)throw A.c(A.dV(a,null,null))
return B.b.aI(this.bw()/4294967296*a)},
$ifD:1}
A.cp.prototype={
gV(){return this.b?0:B.b.m((this.a-0.4)/0.4,0,1)},
gb2(){var t=this
return t.gV()<0.5?4*t.gV()*t.gV()*t.gV():1-Math.pow(-2*t.gV()+2,3)/2}}
A.aW.prototype={
bn(a8){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=this,a5="proofVersion",a6=null,a7="startPose"
if(J.C(a8.h(0,a5),6))t=6
else if(J.C(a8.h(0,a5),5))t=5
else t=J.C(a8.h(0,a5),4)?4:3
a4.a!==$&&A.P()
a4.a=t
s=u.c
r=s.a(a8.h(0,"config"))
a4.b=A.fl(r.h(0,"enemyPace"))
q=A.fk(s.a(r.h(0,"enemies")))
p=s.a(r.h(0,"player"))
o=A.t(p.h(0,"size"))
if(o==null)o=a6
if(o==null){o=A.t(p.h(0,"playerSize"))
if(o==null)o=a6}if(o==null)o=36
n=A.U(p.h(0,"showFace"))
p=n==null?A.U(p.h(0,"playerShowFace")):n
n=s.a(r.h(0,"field"))
m=n.h(0,"color")
l=m==null?n.h(0,"colorHex"):m
if(l==null)l=n.h(0,"surfaceColor")
k=typeof l=="string"&&B.e.be(l).length!==0?B.e.be(l):a6
m=A.t(n.h(0,"borderWidth"))
if(m==null)m=a6
if(m==null)m=3
j=A.t(n.h(0,"brightness"))
if(j==null)j=a6
if(j==null){j=A.t(n.h(0,"fieldBrightness"))
if(j==null)j=a6}if(j==null)j=1
n=A.t(n.h(0,"shadowBrightness"))
if(n==null)n=a6
if(n==null)n=1
i=A.cO(u.N,u.z)
for(h=u.f.a(r.h(0,"game")).gag(),h=h.gt(h);h.n();){g=h.gp()
i.q(0,A.ac(g.a),g.b)}if(t<6)i.q(0,"invulnerableHeroPushEnabled",!0)
i=A.e1(i)
s=s.a(r.h(0,"mobileEnemies"))
f=s.h(0,"startSpeedSteps")
e=s.h(0,"accelerationSteps")
if(typeof f!="number"||typeof e!="number"||!isFinite(f)||!isFinite(e)||f<0.01||f>250||e<0||e>50)A.Y(B.E)
h=A.ed(s.h(0,"speedVariation"),0.05)
s=A.ed(s.h(0,"accelerationVariation"),0.08)
g=o*1.2
d=Math.max(0.000001,(g===0?36:g)*0.1)
c=f*d
b=e*d
a=i.a_()
a.q(0,"speedRampSeconds",0)
i=A.e1(a)
s=new A.cF(new A.bH(q.a,q.b,q.c,q.d,c*(1-h),c*(1+h),b*(1-s),b*(1+s),q.x,q.y),new A.cV(o,p===!0),new A.cq(m,j,n,k),i,B.u,new A.cT(f,e,h,s),a6)
a4.c!==$&&A.P()
a4.c=s
h=A.fF(A.ac(a8.h(0,"requestId")))
m/=2
n=B.b.m(m+0.5,0.5,12)
j=A.cO(u.V,u.n)
p=A.n([],u.v)
o=new A.d_()
$.eY()
a0=$.eh.$0()
o.a=a0
o.b=null
a0=A.n([],u.l)
a1=u.S
a2=A.cQ(a1)
a3=A.cQ(a1)
a1=A.cQ(a1)
t=new A.cv(s,B.r,new A.c3(h),t<4,t>=5,j,n+m,p,o,a0,a2,a3,a1)
g=(380-g)/2
t.w=new A.b(g,g)
B.a.v(a0)
a2.v(0)
a3.v(0)
a1.v(0)
j.v(0)
B.a.v(p)
B.a.S(p,t.bE())
a4.d!==$&&A.P()
a4.d=t
p=J.C(a8.h(0,"hadHelmet"),!0)
j=i.Q
s=isFinite(j)&&j>0?B.b.m(j,0,3600)*1000:0
a4.e!==$&&A.P()
a4.e=new A.cH(p,s,p)
p=J.C(a8.h(0,"hadJump"),!0)
a4.f!==$&&A.P()
a4.f=p
if(a8.h(0,a7)!=null)t.c0(a8.h(0,a7))
a4.r=Math.max(0,i.as)},
gah(){var t=this.r
t===$&&A.e()
return t>0||this.w>0},
aN(){var t,s=this
if(s.y||s.z)throw A.c(A.bg("start"))
t=s.d
t===$&&A.e()
t.bi()
s.CW=t.gbj()
s.ax=s.at=0
s.y=!0},
bJ(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
if(e.gah())return
t=e.d
t===$&&A.e()
s=t.a.d.cy&&t.ba()
r=!s
if(r&&!t.bX())return
e.Q=s
q=t.w
q===$&&A.e()
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
i=m}}else{h=new A.l(p,q,p+o,q+o)
q=t.x
p=q.length
o=u.V
g=0
for(;;){if(!(g<q.length)){j=l
i=m
break}f=q[g]
n=t.f
if(f===A.fs(new A.a9(n,A.q(n).i("a9<1>")),o)||h.a6(f.gB())){q=f.gB()
i=(m+(q.a+q.c)/2)/2
q=f.gB()
j=(l+(q.b+q.d)/2)/2
break}q.length===p||(0,A.D)(q);++g}}e.as=A.L(["x",i,"y",j],u.N,u.i)
q=e.e
q===$&&A.e()
if(q.c){q.bK()
q=e.c
q===$&&A.e()
e.w=Math.max(0,q.d.z)
if(r)t.c_()}else{e.z=!0
e.y=!1}},
b6(){var t,s=this,r=!0
if(s.y){t=s.f
t===$&&A.e()
if(t){r=s.d
r===$&&A.e()
r=!r.c7(s.x)}}if(r)return;++s.ay
B.a.l(s.ch,A.n([2],u.a))},
a3(a){var t,s,r,q,p,o,n,m,l,k,j=this,i=j.d
i===$&&A.e()
t=i.w
t===$&&A.e()
if(!j.y||j.z||j.ch.length>=6e5)throw A.c(A.bg("event"))
s=J.a4(a)
if(J.C(s.h(a,0),0)){r=A.y(s.h(a,1))
if(!isFinite(r)||r<=0||r>50||j.x+r>36e5)throw A.c(A.S("tick"))
B.a.l(j.ch,A.n([0,r],u.a))
s=j.x+=r
q=j.e
q===$&&A.e()
q.bI(s)
p=r/1000
s=j.b
if(s!=null){s.z+=p
s.Q+=p}i.c3(p)
s=j.x
q=j.gah()
o=j.b
o=o==null?null:o.gac()*(i.a.b.a*1.2)*0.1
n=i.c4(p,s/1000,!q,o)
j.at=n.a
j.ax=n.b
o=j.r
o===$&&A.e()
j.r=Math.max(0,o-p)
j.w=Math.max(0,j.w-p)}else if(J.C(s.h(a,0),1)){m=A.y(s.h(a,1))
l=A.y(s.h(a,2))
if(!isFinite(m)||!isFinite(l)||Math.abs(m)>2000||Math.abs(l)>2000)throw A.c(A.S("move"))
B.a.l(j.ch,A.n([1,m,l],u.a))
i.bU(new A.b(m,l),!j.gah())}else throw A.c(A.S("event"))
if(!i.a.d.cy&&i.ba())i.b0()
s=j.e
s===$&&A.e()
k=s.c
j.bk()
if(k&&!s.c){++j.cy
j.cx=null}if(!j.z){s=j.b
if(s!=null){q=i.w
q===$&&A.e()
s.bZ(t.a,t.b,!(i.y>0),i.a.b.a*1.2,q.a,q.b)}}},
ga9(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=this,a8=a7.b
if(a8==null)a8=null
else{t=a8.a
t===$&&A.e()
s=a8.b
s===$&&A.e()
r=a8.Q
q=a8.gac()
p=a8.an(a8.Q)
if(!t)o=0
else if(a8.ga8())o=1
else{o=a8.z
n=a8.cx===0
m=n?0:a8.at
if(n){n=a8.x
n===$&&A.e()}else{n=a8.w
n===$&&A.e()}n=B.b.m((o-m)/n,0,1)
o=n}n=a8.ga8()
m=a8.cx
l=m===0?-1:(a8.z-a8.at)*1000
k=a8.ga8()?(a8.z-a8.as)*1000:-1
a8=A.L(["enabled",t,"speedBarEnabled",s,"effectiveSec",r,"speed",q,"targetSpeed",p,"charge",o,"ready",n,"presses",m,"pressAgeMs",l,"readyAgeMs",k,"beforeSpeed",a8.ch,"afterSpeed",a8.CW],u.N,u.z)}t=a7.y
s=a7.z
r=B.b.aI(a7.x)
q=a7.d
q===$&&A.e()
p=B.b.c1(Math.max(0,q.as/Math.max(0.000001,q.a.b.a*1.2*0.1)))
o=q.at
n=a7.e
n===$&&A.e()
n=n.c
m=a7.gah()
l=q.b7(a7.x)
k=a7.ay
j=a7.f
j===$&&A.e()
if(j){j=a7.c
j===$&&A.e()
j=j.d.e}else j=!1
i=q.y
h=q.w
h===$&&A.e()
g=u.N
f=u.i
h=A.L(["x",h.a,"y",h.b,"size",q.a.b.a*1.2,"visualScale",q.gc8(),"jumpLift",q.gb8()],g,f)
e=u.Q
d=A.n([],e)
for(c=q.x,b=c.length,a=0;a<c.length;c.length===b||(0,A.D)(c),++a){a0=c[a]
a1=a0.a
a2=a0.CW
a3=a7.b
a3=a3==null?a0.ay+a0.ch*(a7.x/1000):a3.gac()*(q.a.b.a*1.2)*0.1
d.push(A.L(["x",a1.a,"y",a1.b,"w",a0.y,"h",a0.z,"angle",a2,"speed",a3],g,f))}c=a7.at
b=a7.ax
a1=a7.Q
a2=a7.as
a3=q.gbO()
e=A.n([],e)
for(q=q.ax,a4=q.length,a=0;a<q.length;q.length===a4||(0,A.D)(q),++a){a5=q[a]
a6=a5.a
e.push(A.L(["x",a6.a,"y",a6.b,"age",a5.b],g,f))}return A.L(["brake",a8,"playing",t,"dead",s,"timeMs",r,"runDistance",p,"riskCount",o,"helmet",n,"invulnerable",m,"jumpCooldownMs",l,"jumpCount",k,"jumpEnabled",j,"jumpRemainingMs",i*1000,"player",h,"enemies",d,"wallBounces",c,"enemyBounces",b,"againstWall",a1,"impactOrigin",a2,"startled",a3,"nearMissFx",e],g,u.z)}}
A.az.prototype={}
A.ah.prototype={}
A.an.prototype={
gN(){var t=this.a
return new A.b(t.a+this.y*0.5,t.b+this.z*0.5)},
bh(a){this.a=new A.b(a.a-this.y*0.5,a.b-this.z*0.5)},
gT(){var t=this.CW*3.141592653589793/180
return new A.b(Math.cos(t),Math.sin(t))},
gU(){var t=this.CW*3.141592653589793/180
return new A.b(-Math.sin(t),Math.cos(t))},
gaH(){var t=this,s=t.y*0.5,r=t.z*0.5,q=new A.cl(t.gN(),t.gT(),t.gU()),p=-s,o=-r
return A.n([q.$2(p,o),q.$2(s,o),q.$2(s,r),q.$2(p,r)],u.L)},
gB(){var t,s,r,q,p=this.gaH(),o=B.a.gO(p).a,n=B.a.gO(p).a,m=B.a.gO(p).b,l=B.a.gO(p).b
for(t=0;t<4;++t){s=p[t]
r=s.a
if(r<o)o=r
if(r>n)n=r
q=s.b
if(q<m)m=q
if(q>l)l=q}return new A.l(o,m,n,l)},
a7(a){var t=this,s=t.gN(),r=t.gT(),q=t.gU(),p=a.a,o=a.b,n=s.a*p+s.b*o,m=t.y*0.5*Math.abs(p*r.a+o*r.b)+t.z*0.5*Math.abs(p*q.a+o*q.b)
return new A.aK(n-m,n+m)},
ab(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c=a.b3(b)
for(t=[B.f,B.i,this.gT(),this.gU()],s=c.a,r=c.c,q=(s+r)/2,p=c.b,o=c.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,m=1/0,l=null,k=0;k<4;++k){j=t[k]
i=this.a7(j)
r=j.a
o=j.b
h=q*r+n*o
g=s*Math.abs(r)+p*Math.abs(o)
f=h+g-i.a
e=i.b-h+g
if(f<=0||e<=0)return null
d=Math.min(f,e)
if(d<m){l=f<e?j:new A.b(-r,-o)
m=d}}return l==null?null:l.W(0,m+0.000001)},
aa(a){return this.ab(a,2.5)},
M(a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
for(t=[B.f,B.i,this.gT(),this.gU()],s=a1.a,r=a1.c,q=(s+r)/2,p=a1.b,o=a1.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,o=a2.a,r=a2.b,m=0,l=1,k=0;k<4;++k){j=t[k]
i=this.a7(j)
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
b9(a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[B.f,B.i,b.gT(),b.gU()],a0=a3.gN(),a1=(a3.c-a3.a)*0.5,a2=(a3.d-a3.b)*0.5
for(t=a0.a,s=a0.b,r=b.y*0.5,q=b.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.b(l,k)
g=b.a7(h)
f=t*l+s*k
e=a1*Math.abs(l)+a2*Math.abs(k)
d=Math.min(g.b,f+e)-Math.max(g.a,f-e)
if(d<=0)return null
if(d<p){c=b.a
o=(c.a+r-t)*l+(c.b+q-s)*k>=0?h:new A.b(-l,-k)
p=d}}if(o==null)return null
return o.W(0,p+0.5)},
bV(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[b.gT(),b.gU(),a0.gT(),a0.gU()]
for(t=b.y*0.5,s=a0.y*0.5,r=b.z*0.5,q=a0.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.b(l,k)
g=b.a7(h)
f=a0.a7(h)
e=Math.min(g.b,f.b)-Math.max(g.a,f.a)
if(e<=0)return null
if(e<p){d=b.a
c=a0.a
o=(d.a+t-(c.a+s))*l+(d.b+r-(c.b+q))*k>=0?h:new A.b(-l,-k)
p=e}}if(o==null)return null
return o.W(0,p+0.5)},
E(a){var t,s,r,q,p,o=a.a,n=a.b,m=o*o+n*n
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
A.cl.prototype={
$2(a,b){var t=this.a,s=this.b,r=this.c
return new A.b(t.a+s.a*a+r.a*b,t.b+s.b*a+r.b*b)},
$S:16}
A.cv.prototype={
gaC(){var t,s,r=this.w
r===$&&A.e()
t=r.a
r=r.b
s=this.a.b.a*1.2
return new A.l(t,r,t+s,r+s)},
bz(a,b){var t,s=this
s.f.q(0,a,b)
t=B.a.a4(s.x,a)
s.ay.Z(0,t)
s.CW.l(0,t)},
b7(a){var t=this.Q
return Math.max(0,t-a)},
gbO(){var t,s,r=this.w
r===$&&A.e()
t=r.a
r=r.b
s=this.a.b.a*1.2
return B.a.aE(this.x,new A.cC(new A.l(t,r,t+s,r+s)))},
gb8(){var t=this.y
if(!(t>0))return 0
return Math.sin(3.141592653589793*B.b.m(1-t/Math.max(0.05,this.a.d.f),0,1))},
gc8(){if(!(this.y>0))return 1
return 1+(B.b.m(this.a.d.w,1.05,1.8)-1)*this.gb8()},
c7(a){var t,s,r=this
if(!isFinite(a)||!r.a.d.e||r.y>0||r.b7(a)>0)return!1
t=r.a.d
r.y=Math.max(0.12,t.f)
s=t.r
t=isFinite(s)?s:2
r.Q=a+Math.max(0,t)*1000
r.ch.v(0)
r.ay.v(0)
if(r.d)r.av()
else r.ae()
return!0},
c3(a){var t,s,r=this
if(r.y<=0)return
t=r.d
if(!t)r.ae()
s=Math.max(0,r.y-a)
r.y=s
if(s>0){if(t)r.av()}else r.ch.v(0)},
bE(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=a9.a,b1=b0.a,b2=A.ec(b1.b,!0,u.i),b3=A.G(b2),b4=b3.i("ar<1>"),b5=A.dx(new A.ar(b2,b3.i("w(1)").a(new A.cB()),b4),b4.i("d.E"))
if(b5.length===0)B.a.S(b5,B.p)
t=b5.length
s=Math.max(t,4)
b2=u.S
b3=J.du(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.am(r,4)
b4=a9.c
B.a.aM(b3,b4)
q=A.ek(b3,0,A.eL(t,"count",b2),A.G(b3).c).bd(0)
b3=J.du(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.am(r,4)
B.a.aM(b3,b4)
p=A.ek(b3,0,A.eL(t,"count",b2),A.G(b3).c).bd(0)
o=A.n([],u.v)
for(b2=b1.e,b3=b1.f,n=b1.r,m=b1.w,l=b1.y,b0=b0.b.a*1.2,b0*=b0,k=b1.a,j=b1.c,b1=b1.d,r=0;r<t;++r){if(!(r<b5.length))return A.i(b5,r)
i=b5[r]
if(!(r<q.length))return A.i(q,r)
h=q[r]
if(!(r<p.length))return A.i(p,r)
g=p[r]
f=Math.max(1,b0)*B.b.m(k,0.2,20)
e=B.b.m(i,0.05,50)
d=Math.sqrt(f/e)
c=Math.sqrt(f*e)
b=a9.by(g,d,c)
a=Math.min(j,b1)
a0=Math.max(j,b1)
a1=a+b4.J()*(a0-a)+90*h
a2=(a1>=360?a1-360:a1)*3.141592653589793/180
a3=Math.min(b2,b3)
a4=Math.max(b2,b3)
a5=a3+b4.J()*(a4-a3)
a3=Math.min(n,m)
a4=Math.max(n,m)
i=b4.J()
h=Math.cos(a2)
g=Math.sin(a2)
a6=Math.abs(l)>0.01
a7=a6?b4.J()*360:0
a8=new A.an(b,new A.b(h*a5,g*a5),c,d,a5,a3+i*(a4-a3),a7,l)
if(a6)a9.aB(a8)
a8.c=a8.a
a8.d=a8.b
a8.w=b4.J()*3.141592653589793*2
a8.x=b4.J()*3.141592653589793*2
a8.f=1.15+b4.J()*0.85
a8.r=0.85+b4.J()*0.85
B.a.l(o,a8)}return o},
c2(a){var t,s,r,q,p,o,n,m,l,k,j,i=this,h=B.b.m(a,0,0.05),g=i.a,f=g.d
if(!f.c)return i.bG(h)
t=B.b.m(f.b,0.05,1)
for(f=i.x,s=f.length,r=0,q=0;q<f.length;f.length===s||(0,A.D)(f),++q){p=f[q]
o=B.b.m(p.ay*t,0,2000)
n=p.b
m=n.a
n=n.b
l=Math.sqrt(m*m+n*n)
if(l<0.000001)k=B.j
else{n=p.b
k=new A.b(n.a/l,n.b/l)}n=k.a*o
m=k.b*o
p.b=new A.b(n,m)
j=p.a
p.a=new A.b(j.a+n*h,j.b+m*h)
n=p.cx
if(Math.abs(n)>0.01)p.CW=p.CW+n*h
if(i.a1(p))++r}return new A.az(r,g.a.x?i.aD():0)},
bi(){var t,s,r,q,p,o,n,m
for(t=this.x,s=t.length,r=0;r<t.length;t.length===s||(0,A.D)(t),++r){q=t[r]
p=q.b
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.b
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
m=new A.b(o/n,p/n)}else{p=q.d
p===$&&A.e()
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.d
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
n=new A.b(o/n,p/n)
m=n}else m=B.f}p=q.ay
q.b=new A.b(m.a*p,m.b*p)}},
gbj(){var t,s,r,q,p,o,n,m=A.n([],u.q)
for(t=this.x,s=t.length,r=u.t,q=0;q<t.length;t.length===s||(0,A.D)(t),++q){p=t[q]
o=p.a
n=p.b
m.push(A.n([o.a,o.b,n.a,n.b,p.CW],r))}return m},
c0(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=u.j
if(!f.b(a)||J.W(a)!==this.x.length)throw A.c(B.D)
for(t=this.x,s=J.a4(a),r=this.b,q=r.a+0.0001,r=r.b+0.0001,p=0;p<t.length;++p){o=s.h(a,p)
if(f.b(o)){n=J.aP(o)
n=n.gk(o)!==5||n.aE(o,new A.cD())}else n=!0
if(n)throw A.c(B.C)
if(!(p<t.length))return A.i(t,p)
m=t[p]
n=J.a4(o)
l=A.y(n.h(o,0))
k=A.y(n.h(o,1))
j=A.y(n.h(o,2))
i=A.y(n.h(o,3))
h=A.y(n.h(o,4))
n=m.ay
if(Math.abs(Math.sqrt(j*j+i*i)-n)>Math.max(0.0001,n*0.000001)||Math.abs(h)>1e9)throw A.c(B.G)
m.a=new A.b(l,k)
m.b=new A.b(j,i)
m.CW=h
g=m.gB()
if(g.a<-0.0001||g.b<-0.0001||g.c>q||g.d>r)throw A.c(B.F)}},
bG(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.x,s=t.length,r=0;r<t.length;t.length===s||(0,A.D)(t),++r){q=t[r]
q.e+=a
p=Math.min(q.y,q.z)*0.5
o=q.d
o===$&&A.e()
n=o.a
o=o.b
m=Math.sqrt(n*n+o*o)
if(m<0.000001)l=B.f
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
o===$&&A.e()
q.a=new A.b(o.a+h.a,o.b+h.b)
o=q.cx
if(Math.abs(o)>0.01)q.CW=q.CW+o*a*0.35
this.aB(q)}return B.t},
aB(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.r,s=this.b,r=s.a-t,q=s.b-t,p=0;p<3;++p){o=a.gaH()
s=A.G(o)
n=s.i("f(1)")
s=s.i("O<1,f>")
m=new A.O(o,n.a(new A.cw()),s).ai(0,B.l)
l=new A.O(o,n.a(new A.cx()),s).ai(0,B.m)
k=new A.O(o,n.a(new A.cy()),s).ai(0,B.l)
j=new A.O(o,n.a(new A.cz()),s).ai(0,B.m)
if(m<t)i=t-m
else i=l>r?r-l:0
if(k<t)h=t-k
else h=j>q?q-j:0
if(i===0&&h===0)break
s=a.a
a.a=new A.b(s.a+i,s.b+h)}},
c4(b0,b1,b2,b3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this
if(a9.e)return a9.bH(b0,b1,b2,b3,1)
t=B.b.m(b0,0,0.05)
s=B.c.m(1,0,2)
r=B.b.m(b1,0,3600)
for(q=a9.x,p=q.length,o=!a9.d,n=!b2,m=a9.a,l=m.b.a*1.2,k=a9.CW,j=b3==null,i=0,h=0;h<q.length;q.length===p||(0,A.D)(q),++h){g=q[h]
f=B.b.m((j?g.ay+g.ch*r:b3)*s,0,4000)
e=g.b
d=e.a
e=e.b
c=Math.sqrt(d*d+e*e)
if(c<0.000001)b=B.j
else{e=g.b
b=new A.b(e.a/c,e.b/c)}g.b=new A.b(b.a*f,b.b*f)
e=g.cx
d=Math.abs(e)
a=Math.max(1,B.b.aF(d*t/5))
for(d=d>0.01,a0=t/a,e=e*t/a,a1=0;a1<a;++a1){a2=g.b
a3=a2.a*a0
a2=a2.b*a0
if(d)g.CW+=e
a4=!1
if(o)if(!(a9.y>0))if(n){a4=a9.w
a4===$&&A.e()
a5=a4.a
a4=a4.b
a4=g.M(new A.l(a5,a4,a5+l,a4+l),new A.b(-a3,-a2))!=null}if(a4)k.l(0,B.a.a4(q,g))
if(b2&&!(a9.y>0)){a4=a9.w
a4===$&&A.e()
a5=a4.a
a4=a4.b
a6=g.M(new A.l(a5,a4,a5+l,a4+l),new A.b(-a3,-a2))}else a6=null
a4=g.a
a5=a6==null
if(a5)a7=1
else a7=a6===0?0:Math.min(1,a6+1e-7)
g.a=new A.b(a4.a+a3*a7,a4.b+a2*a7)
if(a9.a1(g))++i
if(!a5)break}}a8=m.a.x?a9.aD():0
a9.bc(t)
return new A.az(i,a8)},
br(a){var t=a.ab(this.gaC(),2.501)
return t==null?a.gN().a0(0,this.gaC().gN()):t},
Y(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
if(e.y>0)return!0
for(t=e.x,s=e.f,r=e.ay,q=e.CW,p=e.a.b.a*1.2,o=0;o<24;++o){for(n=t.length,m=!1,l=0;l<t.length;t.length===n||(0,A.D)(t),++l){k=t[l]
j=e.w
j===$&&A.e()
i=j.a
j=j.b
h=k.aa(new A.l(i,j,i+p,j+p))
if(h==null)continue
s.q(0,k,h)
g=B.a.a4(t,k)
r.Z(0,g)
q.l(0,g)
j=k.a
k.a=new A.b(j.a+h.a,j.b+h.b)
e.aB(k)
j=e.w
i=j.a
j=j.b
f=k.aa(new A.l(i,j,i+p,j+p))
if(f!=null){j=e.w
e.w=new A.b(j.a-f.a,j.b-f.b)
e.b0()}m=!0}if(!m)return!0}return B.a.bQ(t,new A.cA(e))},
bv(a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=this
a4.Y()
if(!a6){for(t=a4.x,s=t.length,r=a4.a.b.a*1.2,q=1,p=null,o=0;o<t.length;t.length===s||(0,A.D)(t),++o){n=t[o]
m=a4.w
m===$&&A.e()
l=m.a
m=m.b
k=n.M(new A.l(l-2.5,m-2.5,l+r+2.5,m+r+2.5),a5)
if(k!=null&&k<=q){q=Math.max(0,k-1e-7)
p=n}}t=a4.w
t===$&&A.e()
a4.w=t.K(0,a5.W(0,q))
if(p!=null){j=a4.br(p)
a4.bz(p,j)
if(a7)p.E(j)}return}t=a4.a.b.a*1.2
i=Math.min(8,t/4)
for(s=a4.x,r=s.length,o=0;o<r;++o){n=s[o]
i=Math.min(i,Math.min(n.y,n.z)/4)}h=Math.max(1,B.b.aF(a5.gb1()/Math.max(0.25,i)))
g=a5.ak(0,h)
for(r=g.a,m=g.b,l=u.L,f=0;f<h;++f){e=a4.w
e===$&&A.e()
d=A.n([],l)
for(c=s.length,o=0;b=s.length,o<b;s.length===c||(0,A.D)(s),++o)d.push(s[o].a)
for(a=null,q=1,o=0;o<s.length;s.length===b||(0,A.D)(s),++o){n=s[o]
c=a4.w
a0=c.a
c=c.b
k=n.M(new A.l(a0-2.5,c-2.5,a0+t+2.5,c+t+2.5),g)
if(k!=null&&k<=q){q=k
a=n}}c=a4.w
b=c.a+r
c=c.b+m
a4.w=new A.b(b,c)
if(a!=null&&a.aa(new A.l(b,c,b+t,c+t))==null){l=Math.max(0,q-1e-7)
d=e.a+r*l
l=e.b+m*l
a4.w=new A.b(d,l)
l=a.ab(new A.l(d,l,d+t,l+t),2.501)
if(l==null){r=a.a
m=a.y
l=a.z
e=a4.w
d=e.a
e=e.b
e=new A.b(r.a+m*0.5-(d+(d+t))/2,r.b+l*0.5-(e+(e+t))/2)
t=e}else t=l
a4.f.q(0,a,t)
a1=B.a.a4(s,a)
a4.ay.Z(0,a1)
a4.CW.l(0,a1)
break}if(!a4.Y()){a4.w=e
for(a2=0;a2<s.length;++a2){t=s[a2]
if(!(a2<d.length))return A.i(d,a2)
t.a=d[a2]}break}d=a4.w
c=d.a-e.a
e=d.b-e.b
if(Math.sqrt(c*c+e*e)<1e-7)break}for(t=a4.f,t=new A.Z(t,A.q(t).i("Z<1,2>")).gt(0);t.n();){a3=t.d
a3.a.E(a3.b)}},
bH(b6,b7,b8,b9,c0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4=this,b5=b4.f
b5.v(0)
t=B.b.m(b6,0,0.05)
s=B.c.m(c0,0,2)
r=B.b.m(b7,0,3600)
b4.Y()
q=b4.w
q===$&&A.e()
p=A.n([],u.W)
for(o=b4.x,n=o.length,m=0;l=o.length,m<l;o.length===n||(0,A.D)(o),++m){k=o[m]
p.push(new A.aK(k.a,k.CW))}for(n=b4.a,j=n.b.a*1.2,i=b4.ay,h=b4.CW,g=b9==null,f=0,m=0;m<o.length;o.length===l||(0,A.D)(o),++m){e=o[m]
d=B.b.m((g?e.ay+e.ch*r:b9)*s,0,4000)
c=e.b
b=c.a
c=c.b
a=Math.sqrt(b*b+c*c)
if(a<0.000001)c=B.j
else{c=e.b
c=new A.b(c.a/a,c.b/a)}e.b=new A.b(c.a*d,c.b*d)
c=e.cx
b=Math.abs(c)
a0=Math.max(1,B.b.aF(b*t/5))
for(b=b>0.01,a1=t/a0,c=c*t/a0,a2=e.y*0.5,a3=e.z*0.5,a4=0;a4<a0;++a4){a5=e.b
a6=a5.a*a1
a5=a5.b*a1
if(b)e.CW+=c
if(b4.y>0)a7=null
else{a8=b4.w
a9=a8.a
a8=a8.b
a7=e.M(new A.l(a9-2.5,a8-2.5,a9+j+2.5,a8+j+2.5),new A.b(-a6,-a5))}a8=e.a
a9=a7==null
b0=a9?1:Math.max(0,a7-1e-7)
e.a=new A.b(a8.a+a6*b0,a8.b+a5*b0)
a5=!a9
if(a5){a6=b4.w
a8=a6.a
a6=a6.b
a6=e.ab(new A.l(a8,a6,a8+j,a6+j),2.501)
if(a6==null){a6=e.a
a8=b4.w
a9=a8.a
a8=a8.b
a8=new A.b(a6.a+a2-(a9+(a9+j))/2,a6.b+a3-(a8+(a8+j))/2)
a6=a8}b5.q(0,e,a6)
b1=B.a.a4(o,e)
i.Z(0,b1)
h.l(0,b1)}if(b4.a1(e))++f
b4.Y()
if(a5)break}}b2=n.a.x?b4.aD():0
if(!b4.Y()){b4.w=q
for(a4=0;a4<o.length;++a4){q=o[a4]
n=p.length
if(!(a4<n))return A.i(p,a4)
l=p[a4]
q.a=l.a
if(!(a4<n))return A.i(p,a4)
q.CW=l.b}}if(!b8)for(b5=new A.Z(b5,A.q(b5).i("Z<1,2>")).gt(0);b5.n();){b3=b5.d
b3.a.E(b3.b)}b4.bc(t)
return new A.az(f,b2)},
bU(a,b){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=a.a,e=!0
if(isFinite(f)){t=a.b
if(isFinite(t))f=f===0&&t===0
else f=e}else f=e
if(f)return
f=g.w
f===$&&A.e()
e=g.e
if(e)g.f.v(0)
s=g.w.K(0,a)
t=g.a
r=t.d
if(!r.cy){q=g.r
p=g.b
o=t.b.a*1.2
s=new A.b(B.b.m(s.a,q,Math.max(q,p.a-q-o)),B.b.m(s.b,q,Math.max(q,p.b-q-o)))}n=s.a0(0,f)
q=g.w
p=q.a
q=q.b
t=t.b.a*1.2
m=new A.l(p,q,p+t,q+t)
if(e&&!(g.y>0)){e=!b
g.bv(n,e&&r.y,e)}else{l=1
if(b&&!(g.y>0))for(e=g.x,t=e.length,k=0;k<e.length;e.length===t||(0,A.D)(e),++k){j=e[k].M(m,n)
if(j!=null){r=j===0?0:j+1e-7
l=Math.min(l,r)}}g.w=f.K(0,n.W(0,Math.min(1,l)))}i=g.w.a0(0,f).gb1()
if(i===0)return
g.as+=i
if(g.y>0)if(g.d){for(f=g.x,h=0;h<f.length;++h)if(f[h].M(m,n)!=null)g.aR(h)}else g.ae()
else{if(!g.d)for(e=g.x,t=f.a,f=f.b,r=g.ay,q=g.CW,h=0;h<e.length;++h){p=e[h]
o=g.w
if(p.M(m,new A.b(o.a-t,o.b-f))!=null){r.Z(0,h)
q.l(0,h)}}g.aS()}},
bc(a){var t=this,s=t.ax,r=A.G(s).i("w(1)").a(new A.cE(a))
s.$flags&1&&A.aR(s,16)
B.a.bB(s,r,!0)
if(t.y>0)if(t.d)t.av()
else t.ae()
else t.aS()},
ae(){var t,s,r,q,p,o=this
o.ay.v(0)
t=o.w
t===$&&A.e()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.l(s,t,s+r,t+r)
for(t=o.x,s=o.CW,p=0;p<t.length;++p)if(A.dr(q,t[p].gB())<22)s.l(0,p)},
av(){var t,s,r,q,p,o=this
if(!(o.y>0))return
t=o.w
t===$&&A.e()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.l(s,t,s+r,t+r)
for(t=o.x,s=o.ch,p=0;p<t.length;++p){if(s.F(0,p))continue
if(!(p<t.length))return A.i(t,p)
if(!q.a6(t[p].gB()))continue
o.aR(p)}},
aR(a){var t,s,r,q=this
if(!q.ch.l(0,a))return;++q.at
t=q.w
t===$&&A.e()
s=q.a.b.a*1.2/2
r=t.K(0,new A.b(s,s))
s=q.x
if(!(a<s.length))return A.i(s,a)
B.a.l(q.ax,new A.ah(r.K(0,s[a].gB().gN()).ak(0,2)))},
aS(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this
if(g.y>0)return
t=g.w
t===$&&A.e()
s=t.a
t=t.b
r=g.a.b.a*1.2
q=s+r
r=t+r
p=new A.l(s,t,q,r)
o=A.cQ(u.S)
for(n=g.x,m=g.ay,l=!g.d,k=g.CW,q=(s+q)/2,r=(t+r)/2,t=g.ax,j=0;j<n.length;++j){i=A.dr(p,n[j].gB())
if(l&&k.F(0,j)){if(i>=22)k.Z(0,j)
continue}if(i<=0)continue
if(i<=14){m.l(0,j)
o.l(0,j)}else if(i>=22&&m.F(0,j)){++g.at
if(!(j<n.length))return A.i(n,j)
s=n[j].gB()
if(!(j<n.length))return A.i(n,j)
h=n[j].gB()
B.a.l(t,new A.ah(new A.b((q+(s.a+s.c)/2)/2,(r+(h.b+h.d)/2)/2)))}else if(m.F(0,j))o.l(0,j)}m.v(0)
m.S(0,o)},
b0(){var t=this,s=t.a.b.a*1.2,r=t.r,q=t.b,p=Math.max(r,q.a-r-s),o=Math.max(r,q.b-r-s)
q=t.w
q===$&&A.e()
t.w=new A.b(B.b.m(q.a,r,p),B.b.m(t.w.b,r,o))},
ba(){var t,s,r,q,p=this,o=p.w
o===$&&A.e()
t=o.a
s=p.r
r=!0
if(!(t<=s)){o=o.b
if(!(o<=s)){r=p.a.b.a*1.2
q=p.b
o=t+r>=q.a-s||o+r>=q.b-s}else o=r}else o=r
return o},
bX(){var t,s,r,q,p,o=this
if(o.y>0)return!1
if(o.e&&o.f.a!==0)return!0
t=o.w
t===$&&A.e()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.l(s,t,s+r,t+r)
for(t=o.x,s=t.length,p=0;p<t.length;t.length===s||(0,A.D)(t),++p)if(t[p].b9(q)!=null)return!0
return!1},
c_(){var t,s,r,q,p,o,n,m,l,k,j=this
if(j.e){j.Y()
t=j.f
s=A.fz(t,u.V,u.n)
for(r=new A.Z(s,A.q(s).i("Z<1,2>")).gt(0);r.n();){q=r.d
q.a.E(q.b)}t.v(0)
return s.a}t=j.w
t===$&&A.e()
r=t.a
t=t.b
p=j.a.b.a*1.2
o=new A.l(r,t,r+p,t+p)
for(t=j.x,r=t.length,n=0,m=0;m<t.length;t.length===r||(0,A.D)(t),++m){l=t[m]
k=l.b9(o)
if(k==null)continue
p=l.a
l.a=new A.b(p.a+k.a,p.b+k.b)
l.E(k);++n}return n},
by(a0,a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this,d=Math.max(8,e.r+2),c=e.b,b=c.a,a=b/2
c=c.b
t=c/2
s=A.d3()
r=A.d3()
q=A.d3()
p=A.d3()
switch(B.c.am(a0,4)){case 0:s.b=d
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
if(typeof o!=="number")return o.al()
if(typeof n!=="number")return A.dh(n)
if(o<n){s.b=d
r.b=Math.max(d,b-a2-d)}o=p.X()
n=q.X()
if(typeof o!=="number")return o.al()
if(typeof n!=="number")return A.dh(n)
if(o<n){q.b=d
p.b=Math.max(d,c-a1-d)}o=e.w
o===$&&A.e()
n=o.a
o=o.b
m=e.a.b.a*1.2
l=new A.l(n,o,n+m,o+m).b3(m*0.6)
for(o=e.c,k=0;k<12;++k){n=s.b
if(n===s)A.Y(A.b2(""))
m=o.J()
j=r.b
if(j===r)A.Y(A.b2(""))
i=s.b
if(i===s)A.Y(A.b2(""))
if(typeof j!=="number")return j.a0()
if(typeof i!=="number")return A.dh(i)
j=Math.max(1,j-i)
if(typeof n!=="number")return n.K()
h=n+m*j
n=q.b
if(n===q)A.Y(A.b2(""))
m=o.J()
j=p.b
if(j===p)A.Y(A.b2(""))
i=q.b
if(i===q)A.Y(A.b2(""))
if(typeof j!=="number")return j.a0()
if(typeof i!=="number")return A.dh(i)
j=Math.max(1,j-i)
if(typeof n!=="number")return n.K()
g=n+m*j
f=new A.b(h,g)
if(!new A.l(h,g,h+a2,g+a1).a6(l))return f}return new A.b(J.dT(s.X(),d,b-a2-d),J.dT(q.X(),d,c-a1-d))},
a1(a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=a2.gN()
for(t=this.r,s=this.b,r=s.a-t,q=s.b-t,s=a2.y*0.5,p=a2.z*0.5,o=!1,n=0;n<3;++n){m=a1.a
l=a1.b
a2.a=new A.b(m-s,l-p)
k=a2.gaH()
j=B.a.gO(k).a
i=B.a.gO(k).a
h=B.a.gO(k).b
g=B.a.gO(k).b
for(f=0;f<4;++f){e=k[f]
d=e.a
if(d<j)j=d
if(d>i)i=d
c=e.b
if(c<h)h=c
if(c>g)g=c}b=!0
if(j<t){a=t-j
a2.E(B.f)
o=b}else if(i>r){a=r-i
a2.E(B.P)
o=b}else a=0
if(h<t){a0=t-h
a2.E(B.i)
o=b}else if(g>q){a0=q-g
a2.E(B.O)
o=b}else a0=0
if(a===0&&a0===0)break
a1=new A.b(m+a,l+a0)}a2.bh(a1)
return o},
aD(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f
for(t=this.x,s=0,r=0;r<t.length;r=q)for(q=r+1,p=q;o=t.length,p<o;++p){if(!(r<o))return A.i(t,r)
n=t[r]
m=t[p]
if(!n.gB().a6(m.gB()))continue
l=n.bV(m)
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
n.E(l)
m.E(new A.b(-o,-j))
this.a1(n)
this.a1(m)}return s}}
A.cC.prototype={
$1(a){return A.dr(this.a,u.V.a(a).gB())<=14},
$S:5}
A.cB.prototype={
$1(a){A.a3(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.cD.prototype={
$1(a){return typeof a!="number"||!isFinite(a)},
$S:17}
A.cw.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.cx.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.cy.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cz.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cA.prototype={
$1(a){return u.V.a(a).aa(this.a.gaC())==null},
$S:5}
A.cE.prototype={
$1(a){return!((u._.a(a).b+=this.a)<0.42)},
$S:18};(function aliases(){var t=J.ag.prototype
t.bl=t.j
t=A.aW.prototype
t.bk=t.bJ
t.aO=t.a3})();(function installTearOffs(){var t=hunkHelpers._static_0,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(A,"hu","fB",1)
s(A,"hD","ha",2)
r(A,"hU",2,null,["$1$2","$2"],["eR",function(a,b){return A.eR(a,b,u.H)}],6,0)
r(A,"hT",2,null,["$1$2","$2"],["eQ",function(a,b){return A.eQ(a,b,u.H)}],6,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.r,null)
r(A.r,[A.dv,J.bM,A.bd,J.am,A.u,A.k,A.cY,A.d,A.aa,A.b4,A.bl,A.K,A.bj,A.au,A.aT,A.bn,A.J,A.d0,A.cU,A.x,A.cN,A.ap,A.b3,A.d2,A.a_,A.ca,A.d9,A.bu,A.aF,A.cd,A.as,A.bE,A.bG,A.d6,A.be,A.a6,A.M,A.b9,A.d_,A.aG,A.cF,A.bH,A.cV,A.cq,A.cr,A.cj,A.cT,A.cm,A.b,A.cZ,A.l,A.aW,A.cH,A.c3,A.cp,A.az,A.ah,A.an,A.cv])
r(J.bM,[J.bO,J.aY,J.b_,J.aZ,J.b0,J.aB,J.aC])
r(J.b_,[J.ag,J.o,A.aD,A.b7])
r(J.ag,[J.c0,J.aH,J.ae])
s(J.bN,A.bd)
s(J.cI,J.o)
r(J.aB,[J.aX,J.bP])
r(A.u,[A.af,A.bi,A.bQ,A.c8,A.c4,A.c9,A.b1,A.bA,A.a5,A.bk,A.c7,A.bf,A.bF])
s(A.aI,A.k)
s(A.aS,A.aI)
r(A.d,[A.h,A.aq,A.ar,A.bm,A.aL])
r(A.h,[A.E,A.a9,A.Z])
r(A.E,[A.bh,A.O,A.cc])
s(A.aV,A.aq)
s(A.aJ,A.au)
s(A.aK,A.aJ)
s(A.aU,A.aT)
r(A.J,[A.bL,A.bC,A.bD,A.c6,A.di,A.dk,A.cR,A.ck,A.co,A.cn,A.cu,A.cs,A.dm,A.cC,A.cB,A.cD,A.cw,A.cx,A.cy,A.cz,A.cA,A.cE])
s(A.ao,A.bL)
s(A.cW,A.bC)
s(A.ba,A.bi)
r(A.c6,[A.c5,A.aA])
r(A.x,[A.a8,A.cb])
r(A.bD,[A.cJ,A.dj,A.cP,A.cS,A.d7,A.ct,A.cl])
r(A.b7,[A.bS,A.aE])
r(A.aE,[A.bp,A.br])
s(A.bq,A.bp)
s(A.b5,A.bq)
s(A.bs,A.br)
s(A.b6,A.bs)
r(A.b5,[A.bT,A.bU])
r(A.b6,[A.bV,A.bW,A.bX,A.bY,A.bZ,A.b8,A.c_])
s(A.aM,A.c9)
s(A.bt,A.aF)
s(A.bo,A.bt)
s(A.bR,A.b1)
s(A.cK,A.bE)
r(A.bG,[A.cM,A.cL])
s(A.d5,A.d6)
r(A.a5,[A.bb,A.bK])
s(A.cG,A.aW)
t(A.aI,A.bj)
t(A.bp,A.k)
t(A.bq,A.K)
t(A.br,A.k)
t(A.bs,A.K)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",f:"double",a0:"num",p:"String",w:"bool",b9:"Null",j:"List",r:"Object",a2:"Map",z:"JSObject"},mangledNames:{},types:["f(b)","a()","@(@)","~(r?,r?)","w(f)","w(an)","0^(0^,0^)<a0>","@(@,p)","@(p)","~(@,@)","f(@)","f(p,f,f,f)","w(p)","w(l)","w(f,f)","p(p)","b(f,f)","w(@)","w(ah)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.aK&&a.b(c.a)&&b.b(c.b)}}
A.h1(v.typeUniverse,JSON.parse('{"ae":"ag","c0":"ag","aH":"ag","i1":"aD","bO":{"w":[],"m":[]},"aY":{"m":[]},"b_":{"z":[]},"ag":{"z":[]},"o":{"j":["1"],"h":["1"],"z":[],"d":["1"]},"bN":{"bd":[]},"cI":{"o":["1"],"j":["1"],"h":["1"],"z":[],"d":["1"]},"am":{"I":["1"]},"aB":{"f":[],"a0":[]},"aX":{"f":[],"a":[],"a0":[],"m":[]},"bP":{"f":[],"a0":[],"m":[]},"aC":{"p":[],"m":[]},"af":{"u":[]},"aS":{"k":["a"],"bj":["a"],"j":["a"],"h":["a"],"d":["a"],"k.E":"a"},"h":{"d":["1"]},"E":{"h":["1"],"d":["1"]},"bh":{"E":["1"],"h":["1"],"d":["1"],"d.E":"1","E.E":"1"},"aa":{"I":["1"]},"aq":{"d":["2"],"d.E":"2"},"aV":{"aq":["1","2"],"h":["2"],"d":["2"],"d.E":"2"},"b4":{"I":["2"]},"O":{"E":["2"],"h":["2"],"d":["2"],"d.E":"2","E.E":"2"},"ar":{"d":["1"],"d.E":"1"},"bl":{"I":["1"]},"aI":{"k":["1"],"bj":["1"],"j":["1"],"h":["1"],"d":["1"]},"aK":{"aJ":[],"au":[]},"aT":{"a2":["1","2"]},"aU":{"aT":["1","2"],"a2":["1","2"]},"bm":{"d":["1"],"d.E":"1"},"bn":{"I":["1"]},"bL":{"J":[],"a7":[]},"ao":{"J":[],"a7":[]},"ba":{"u":[]},"bQ":{"u":[]},"c8":{"u":[]},"J":{"a7":[]},"bC":{"J":[],"a7":[]},"bD":{"J":[],"a7":[]},"c6":{"J":[],"a7":[]},"c5":{"J":[],"a7":[]},"aA":{"J":[],"a7":[]},"c4":{"u":[]},"a8":{"x":["1","2"],"e9":["1","2"],"a2":["1","2"],"x.K":"1","x.V":"2"},"a9":{"h":["1"],"d":["1"],"d.E":"1"},"ap":{"I":["1"]},"Z":{"h":["M<1,2>"],"d":["M<1,2>"],"d.E":"M<1,2>"},"b3":{"I":["M<1,2>"]},"aJ":{"au":[]},"aD":{"z":[],"m":[]},"b7":{"z":[]},"bS":{"z":[],"m":[]},"aE":{"T":["1"],"z":[]},"b5":{"k":["f"],"j":["f"],"T":["f"],"h":["f"],"z":[],"d":["f"],"K":["f"]},"b6":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"]},"bT":{"k":["f"],"j":["f"],"T":["f"],"h":["f"],"z":[],"d":["f"],"K":["f"],"m":[],"k.E":"f"},"bU":{"k":["f"],"j":["f"],"T":["f"],"h":["f"],"z":[],"d":["f"],"K":["f"],"m":[],"k.E":"f"},"bV":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"],"m":[],"k.E":"a"},"bW":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"],"m":[],"k.E":"a"},"bX":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"],"m":[],"k.E":"a"},"bY":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"],"m":[],"k.E":"a"},"bZ":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"],"m":[],"k.E":"a"},"b8":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"],"m":[],"k.E":"a"},"c_":{"k":["a"],"j":["a"],"T":["a"],"h":["a"],"z":[],"d":["a"],"K":["a"],"m":[],"k.E":"a"},"c9":{"u":[]},"aM":{"u":[]},"bu":{"I":["1"]},"aL":{"d":["1"],"d.E":"1"},"bo":{"aF":["1"],"dC":["1"],"h":["1"],"d":["1"]},"as":{"I":["1"]},"k":{"j":["1"],"h":["1"],"d":["1"]},"x":{"a2":["1","2"]},"aF":{"dC":["1"],"h":["1"],"d":["1"]},"bt":{"aF":["1"],"dC":["1"],"h":["1"],"d":["1"]},"cb":{"x":["p","@"],"a2":["p","@"],"x.K":"p","x.V":"@"},"cc":{"E":["p"],"h":["p"],"d":["p"],"d.E":"p","E.E":"p"},"b1":{"u":[]},"bR":{"u":[]},"f":{"a0":[]},"a":{"a0":[]},"j":{"h":["1"],"d":["1"]},"bA":{"u":[]},"bi":{"u":[]},"a5":{"u":[]},"bb":{"u":[]},"bK":{"u":[]},"bk":{"u":[]},"c7":{"u":[]},"bf":{"u":[]},"bF":{"u":[]},"be":{"u":[]},"aG":{"fH":[]},"c3":{"fD":[]},"fr":{"j":["a"],"h":["a"],"d":["a"]},"fL":{"j":["a"],"h":["a"],"d":["a"]},"fK":{"j":["a"],"h":["a"],"d":["a"]},"fp":{"j":["a"],"h":["a"],"d":["a"]},"fI":{"j":["a"],"h":["a"],"d":["a"]},"fq":{"j":["a"],"h":["a"],"d":["a"]},"fJ":{"j":["a"],"h":["a"],"d":["a"]},"fm":{"j":["f"],"h":["f"],"d":["f"]},"fn":{"j":["f"],"h":["f"],"d":["f"]}}'))
A.h0(v.typeUniverse,JSON.parse('{"h":1,"aI":1,"aE":1,"bt":1,"bE":2,"bG":2}'))
var u=(function rtii(){var t=A.cg
return{E:t("aS"),O:t("h<@>"),V:t("an"),C:t("u"),Z:t("a7"),u:t("ao<f>"),R:t("d<@>"),v:t("o<an>"),q:t("o<j<f>>"),U:t("o<j<a0>>"),Q:t("o<a2<p,f>>"),l:t("o<ah>"),L:t("o<b>"),W:t("o<+(b,f)>"),s:t("o<p>"),t:t("o<f>"),b:t("o<@>"),Y:t("o<a>"),a:t("o<a0>"),T:t("aY"),m:t("z"),M:t("ae"),p:t("T<@>"),j:t("j<@>"),c:t("a2<p,@>"),f:t("a2<@,@>"),_:t("ah"),P:t("b9"),K:t("r"),n:t("b"),J:t("i2"),F:t("+()"),N:t("p"),k:t("m"),o:t("aH"),y:t("w"),i:t("f"),z:t("@"),S:t("a"),d:t("e0<b9>?"),A:t("z?"),e:t("j<@>?"),X:t("r?"),w:t("p?"),g:t("cd?"),h:t("w?"),I:t("f?"),x:t("a?"),B:t("a0?"),H:t("a0"),D:t("~(p,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.H=J.bM.prototype
B.a=J.o.prototype
B.c=J.aX.prototype
B.b=J.aB.prototype
B.e=J.aC.prototype
B.I=J.ae.prototype
B.J=J.b_.prototype
B.q=J.c0.prototype
B.k=J.aH.prototype
B.t=new A.az(0,0)
B.m=new A.ao(A.hT(),u.u)
B.l=new A.ao(A.hU(),u.u)
B.u=new A.cj()
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

B.d=new A.cK()
B.h=new A.cY()
B.B=new A.a6("Invalid mobile enemy variation")
B.C=new A.a6("start pose values")
B.D=new A.a6("start pose count")
B.E=new A.a6("Invalid mobile enemy pace")
B.F=new A.a6("start pose bounds")
B.G=new A.a6("start pose speed")
B.K=new A.cL(null)
B.L=new A.cM(null)
B.p=t([1,0.25,0.5,3],u.t)
B.N={}
B.M=new A.aU(B.N,[],A.cg("aU<@,@>"))
B.i=new A.b(0,1)
B.O=new A.b(0,-1)
B.f=new A.b(1,0)
B.j=new A.b(1,1)
B.P=new A.b(-1,0)
B.r=new A.cZ(380,380)
B.Q=A.a1("hY")
B.R=A.a1("hZ")
B.S=A.a1("fm")
B.T=A.a1("fn")
B.U=A.a1("fp")
B.V=A.a1("fq")
B.W=A.a1("fr")
B.X=A.a1("r")
B.Y=A.a1("fI")
B.Z=A.a1("fJ")
B.a_=A.a1("fK")
B.a0=A.a1("fL")})();(function staticFields(){$.d4=null
$.V=A.n([],A.cg("o<r>"))
$.ef=null
$.cX=0
$.eh=A.hu()
$.dY=null
$.dX=null
$.eO=null
$.eJ=null
$.eU=null
$.dg=null
$.dl=null
$.dO=null
$.d8=A.n([],A.cg("o<j<r>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"i0","eX",()=>A.eN("_$dart_dartClosure"))
t($,"i_","dR",()=>A.eN("_$dart_dartClosure_dartJSInterop"))
t($,"ig","f8",()=>A.n([new J.bN()],A.cg("o<bd>")))
t($,"i4","eZ",()=>A.ab(A.d1({
toString:function(){return"$receiver$"}})))
t($,"i5","f_",()=>A.ab(A.d1({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"i6","f0",()=>A.ab(A.d1(null)))
t($,"i7","f1",()=>A.ab(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"ia","f4",()=>A.ab(A.d1(void 0)))
t($,"ib","f5",()=>A.ab(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"i9","f3",()=>A.ab(A.el(null)))
t($,"i8","f2",()=>A.ab(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"id","f7",()=>A.ab(A.el(void 0)))
t($,"ic","f6",()=>A.ab(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"ie","dp",()=>A.eS(B.X))
t($,"i3","eY",()=>{A.fC()
return $.cX})})();(function nativeSupport(){!function(){var t=function(a){var n={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.aD,SharedArrayBuffer:A.aD,ArrayBufferView:A.b7,DataView:A.bS,Float32Array:A.bT,Float64Array:A.bU,Int16Array:A.bV,Int32Array:A.bW,Int8Array:A.bX,Uint16Array:A.bY,Uint32Array:A.bZ,Uint8ClampedArray:A.b8,CanvasPixelArray:A.b8,Uint8Array:A.c_})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.aE.$nativeSuperclassTag="ArrayBufferView"
A.bp.$nativeSuperclassTag="ArrayBufferView"
A.bq.$nativeSuperclassTag="ArrayBufferView"
A.b5.$nativeSuperclassTag="ArrayBufferView"
A.br.$nativeSuperclassTag="ArrayBufferView"
A.bs.$nativeSuperclassTag="ArrayBufferView"
A.b6.$nativeSuperclassTag="ArrayBufferView"})()
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
var t=A.hR
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
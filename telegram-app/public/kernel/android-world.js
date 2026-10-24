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
if(a[b]!==t){A.hC(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.m(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.du(b)
return new t(c,this)}:function(){if(t===null)t=A.du(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.du(a).prototype
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
dz(a,b,c,d){return{i:a,p:b,e:c,x:d}},
dv(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.dx==null){A.hr()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.b(A.e4("Return interceptor for "+A.t(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.cM
if(p==null)p=$.cM=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.hw(a)
if(q!=null)return q
if(typeof a=="function")return B.I
t=Object.getPrototypeOf(a)
if(t==null)return B.q
if(t===Object.prototype)return B.q
if(typeof r=="function"){p=$.cM
if(p==null)p=$.cM=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.j,enumerable:false,writable:true,configurable:true})
return B.j}return B.j},
dP(a,b){if(a<0||a>4294967295)throw A.b(A.b3(a,0,4294967295,"length",null))
return J.fb(new Array(a),b)},
dQ(a,b){if(a<0)throw A.b(A.c5("Length must be a non-negative integer: "+a))
return A.m(new Array(a),b.i("l<0>"))},
db(a,b){if(a<0)throw A.b(A.c5("Length must be a non-negative integer: "+a))
return A.m(new Array(a),b.i("l<0>"))},
fb(a,b){var t=A.m(a,b.i("l<0>"))
t.$flags=1
return t},
dR(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
fc(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.dR(s))break;++b}return b},
fd(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.j(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.dR(r))break}return b},
ar(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aP.prototype
return J.bD.prototype}if(typeof a=="string")return J.aw.prototype
if(a==null)return J.aQ.prototype
if(typeof a=="boolean")return J.bC.prototype
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a9.prototype
if(typeof a=="symbol")return J.aT.prototype
if(typeof a=="bigint")return J.aR.prototype
return a}if(a instanceof A.o)return a
return J.dv(a)},
aH(a){if(typeof a=="string")return J.aw.prototype
if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a9.prototype
if(typeof a=="symbol")return J.aT.prototype
if(typeof a=="bigint")return J.aR.prototype
return a}if(a instanceof A.o)return a
return J.dv(a)},
a_(a){if(a==null)return a
if(Array.isArray(a))return J.l.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a9.prototype
if(typeof a=="symbol")return J.aT.prototype
if(typeof a=="bigint")return J.aR.prototype
return a}if(a instanceof A.o)return a
return J.dv(a)},
hn(a){if(typeof a=="number")return J.av.prototype
if(a==null)return a
if(!(a instanceof A.o))return J.aB.prototype
return a},
A(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.ar(a).K(a,b)},
C(a,b){if(typeof b==="number")if(Array.isArray(a)||A.hv(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.a_(a).h(a,b)},
d7(a,b,c){return J.a_(a).u(a,b,c)},
dB(a,b){return J.a_(a).L(a,b)},
dC(a,b,c){return J.hn(a).l(a,b,c)},
dD(a,b){return J.a_(a).B(a,b)},
M(a){return J.ar(a).gt(a)},
eR(a){return J.aH(a).gC(a)},
eS(a){return J.aH(a).gar(a)},
d8(a){return J.a_(a).gv(a)},
N(a){return J.aH(a).gk(a)},
eT(a){return J.ar(a).gp(a)},
eU(a,b,c){return J.a_(a).aS(a,b,c)},
bn(a){return J.ar(a).j(a)},
bA:function bA(){},
bC:function bC(){},
aQ:function aQ(){},
aS:function aS(){},
ab:function ab(){},
bP:function bP(){},
aB:function aB(){},
a9:function a9(){},
aR:function aR(){},
aT:function aT(){},
l:function l(a){this.$ti=a},
bB:function bB(){},
ct:function ct(a){this.$ti=a},
ai:function ai(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
av:function av(){},
aP:function aP(){},
bD:function bD(){},
aw:function aw(){}},A={dc:function dc(){},
ff(a){return new A.aa("Field '"+a+"' has not been initialized.")},
aV(a){return new A.aa("Local '"+a+"' has not been initialized.")},
fe(a){return new A.aa("Field '"+a+"' has already been initialized.")},
ad(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
dl(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
es(a,b,c){return a},
dy(a){var t,s
for(t=$.L.length,s=0;s<t;++s)if(a===$.L[s])return!0
return!1},
e2(a,b,c,d){A.di(b,"start")
if(c!=null){A.di(c,"end")
if(b>c)A.T(A.b3(b,0,c,"start",null))}return new A.b7(a,b,c,d.i("b7<0>"))},
dO(){return new A.b6("No element")},
aa:function aa(a){this.a=a},
aL:function aL(a){this.a=a},
cF:function cF(){},
aO:function aO(){},
F:function F(){},
b7:function b7(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
a4:function a4(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
P:function P(a,b,c){this.a=a
this.b=b
this.$ti=c},
am:function am(a,b,c){this.a=a
this.b=b
this.$ti=c},
bb:function bb(a,b,c){this.a=a
this.b=b
this.$ti=c},
E:function E(){},
b9:function b9(){},
aC:function aC(){},
eC(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
hv(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
t(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.bn(a)
return t},
bQ(a){var t,s=$.dY
if(s==null)s=$.dY=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bR(a){var t,s,r,q
if(a instanceof A.o)return A.G(A.ah(a),null)
t=J.ar(a)
if(t===B.H||t===B.J||u.A.b(a)){s=B.m(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.G(A.ah(a),null)},
dZ(a){var t,s,r
if(a==null||typeof a=="number"||A.cW(a))return J.bn(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.D)return a.j(0)
if(a instanceof A.ap)return a.aL(!0)
t=$.eQ()
for(s=0;s<1;++s){r=t[s].bG(a)
if(r!=null)return r}return"Instance of '"+A.bR(a)+"'"},
fh(){return Date.now()},
fi(){var t,s
if($.cE!==0)return
$.cE=1000
if(typeof window=="undefined")return
t=window
if(t==null)return
if(!!t.dartUseDateNowForTicks)return
s=t.performance
if(s==null)return
if(typeof s.now!="function")return
$.cE=1e6
$.e_=new A.cD(s)},
z(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.c.aK(t,10)|55296)>>>0,t&1023|56320)}throw A.b(A.b3(a,0,1114111,null,null))},
d_(a){throw A.b(A.er(a))},
j(a,b){if(a==null)J.N(a)
throw A.b(A.cY(a,b))},
cY(a,b){var t,s="index"
if(!A.em(b))return new A.a0(!0,b,s,null)
t=J.N(a)
if(b<0||b>=t)return A.d9(b,t,a,s)
return new A.b2(null,null,!0,b,s,"Value not in range")},
er(a){return new A.a0(!0,a,null,null)},
b(a){return A.y(a,new Error())},
y(a,b){var t
if(a==null)a=new A.b8()
b.dartException=a
t=A.hD
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hD(){return J.bn(this.dartException)},
T(a,b){throw A.y(a,b==null?new Error():b)},
aJ(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.T(A.fS(a,b,c),t)},
fS(a,b,c){var t,s,r,q,p,o,n,m,l
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
return new A.ba("'"+t+"': Cannot "+p+" "+m+l+o)},
S(a){throw A.b(A.U(a))},
a5(a){var t,s,r,q,p,o
a=A.hB(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.m([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.cI(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
cJ(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
e3(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
dd(a,b){var t=b==null,s=t?null:b.method
return new A.bE(a,s,t?null:b.receiver)},
eD(a){if(a==null)return new A.cB(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.at(a,a.dartException)
return A.hi(a)},
at(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
hi(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.c.aK(s,16)&8191)===10)switch(r){case 438:return A.at(a,A.dd(A.t(t)+" (Error "+r+")",null))
case 445:case 5007:A.t(t)
return A.at(a,new A.b1())}}if(a instanceof TypeError){q=$.eG()
p=$.eH()
o=$.eI()
n=$.eJ()
m=$.eM()
l=$.eN()
k=$.eL()
$.eK()
j=$.eP()
i=$.eO()
h=q.D(t)
if(h!=null)return A.at(a,A.dd(A.af(t),h))
else{h=p.D(t)
if(h!=null){h.method="call"
return A.at(a,A.dd(A.af(t),h))}else if(o.D(t)!=null||n.D(t)!=null||m.D(t)!=null||l.D(t)!=null||k.D(t)!=null||n.D(t)!=null||j.D(t)!=null||i.D(t)!=null){A.af(t)
return A.at(a,new A.b1())}}return A.at(a,new A.bY(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.b5()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.at(a,new A.a0(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.b5()
return a},
ez(a){if(a==null)return J.M(a)
if(typeof a=="object")return A.bQ(a)
return J.M(a)},
hm(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.u(0,a[t],a[s])}return b},
f1(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bV().constructor.prototype):Object.create(new A.au(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.dJ(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.eY(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.dJ(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
eY(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.b("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.eW)}throw A.b("Error in functionType of tearoff")},
eZ(a,b,c,d){var t=A.dH
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
dJ(a,b,c,d){if(c)return A.f0(a,b,d)
return A.eZ(b.length,d,a,b)},
f_(a,b,c,d){var t=A.dH,s=A.eX
switch(b?-1:a){case 0:throw A.b(new A.bT("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
f0(a,b,c){var t,s
if($.dF==null)$.dF=A.dE("interceptor")
if($.dG==null)$.dG=A.dE("receiver")
t=b.length
s=A.f_(t,c,a,b)
return s},
du(a){return A.f1(a)},
eW(a,b){return A.bm(v.typeUniverse,A.ah(a.a),b)},
dH(a){return a.a},
eX(a){return a.b},
dE(a){var t,s,r,q=new A.au("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.b(A.c5("Field name "+a+" not found."))},
eu(a){return v.getIsolateTag(a)},
hw(a){var t,s,r,q,p,o=A.af($.ev.$1(a)),n=$.cZ[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.d3[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.c3($.eq.$2(a,o))
if(r!=null){n=$.cZ[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.d3[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.d5(t)
$.cZ[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.d3[o]=t
return t}if(q==="-"){p=A.d5(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.eA(a,t)
if(q==="*")throw A.b(A.e4(o))
if(v.leafTags[o]===true){p=A.d5(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.eA(a,t)},
eA(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.dz(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
d5(a){return J.dz(a,!1,null,!!a.$iJ)},
hy(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.d5(t)
else return J.dz(t,c,null,null)},
hr(){if(!0===$.dx)return
$.dx=!0
A.hs()},
hs(){var t,s,r,q,p,o,n,m
$.cZ=Object.create(null)
$.d3=Object.create(null)
A.hq()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.eB.$1(p)
if(o!=null){n=A.hy(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
hq(){var t,s,r,q,p,o,n=B.v()
n=A.aG(B.w,A.aG(B.x,A.aG(B.n,A.aG(B.n,A.aG(B.y,A.aG(B.z,A.aG(B.A(B.m),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.ev=new A.d0(q)
$.eq=new A.d1(p)
$.eB=new A.d2(o)},
aG(a,b){return a(b)||b},
hk(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
hB(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
bh:function bh(a,b){this.a=a
this.b=b},
aM:function aM(){},
aN:function aN(a,b,c){this.a=a
this.b=b
this.$ti=c},
bz:function bz(){},
ak:function ak(a,b){this.a=a
this.$ti=b},
cD:function cD(a){this.a=a},
b4:function b4(){},
cI:function cI(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b1:function b1(){},
bE:function bE(a,b,c){this.a=a
this.b=b
this.c=c},
bY:function bY(a){this.a=a},
cB:function cB(a){this.a=a},
D:function D(){},
bq:function bq(){},
br:function br(){},
bW:function bW(){},
bV:function bV(){},
au:function au(a,b){this.a=a
this.b=b},
bT:function bT(a){this.a=a},
a3:function a3(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cu:function cu(a){this.a=a},
cy:function cy(a,b){this.a=a
this.b=b
this.c=null},
al:function al(a,b){this.a=a
this.$ti=b},
aW:function aW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
d0:function d0(a){this.a=a},
d1:function d1(a){this.a=a},
d2:function d2(a){this.a=a},
ap:function ap(){},
aD:function aD(){},
hC(a){throw A.y(new A.aa("Field '"+a+"' has been assigned during initialization."),new Error())},
f(){throw A.y(A.ff(""),new Error())},
a7(){throw A.y(A.fe(""),new Error())},
cL(){var t=new A.cK()
return t.b=t},
cK:function cK(){this.b=null},
aq(a,b,c){if(a>>>0!==a||a>=c)throw A.b(A.cY(b,a))},
ax:function ax(){},
aZ:function aZ(){},
bG:function bG(){},
ay:function ay(){},
aX:function aX(){},
aY:function aY(){},
bH:function bH(){},
bI:function bI(){},
bJ:function bJ(){},
bK:function bK(){},
bL:function bL(){},
bM:function bM(){},
bN:function bN(){},
b_:function b_(){},
bO:function bO(){},
bd:function bd(){},
be:function be(){},
bf:function bf(){},
bg:function bg(){},
dj(a,b){var t=b.c
return t==null?b.c=A.bk(a,"dK",[b.x]):t},
e0(a){var t=a.w
if(t===6||t===7)return A.e0(a.x)
return t===11||t===12},
fm(a){return a.as},
c4(a){return A.cS(v.typeUniverse,a,!1)},
hu(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.ag(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
ag(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.ag(a0,t,a2,a3)
if(s===t)return a1
return A.ed(a0,s,!0)
case 7:t=a1.x
s=A.ag(a0,t,a2,a3)
if(s===t)return a1
return A.ec(a0,s,!0)
case 8:r=a1.y
q=A.aF(a0,r,a2,a3)
if(q===r)return a1
return A.bk(a0,a1.x,q)
case 9:p=a1.x
o=A.ag(a0,p,a2,a3)
n=a1.y
m=A.aF(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.dp(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.aF(a0,k,a2,a3)
if(j===k)return a1
return A.ee(a0,l,j)
case 11:i=a1.x
h=A.ag(a0,i,a2,a3)
g=a1.y
f=A.hf(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.eb(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.aF(a0,e,a2,a3)
p=a1.x
o=A.ag(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.dq(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.b(A.bp("Attempted to substitute unexpected RTI kind "+a))}},
aF(a,b,c,d){var t,s,r,q,p=b.length,o=A.cT(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.ag(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
hg(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.cT(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.ag(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
hf(a,b,c,d){var t,s=b.a,r=A.aF(a,s,c,d),q=b.b,p=A.aF(a,q,c,d),o=b.c,n=A.hg(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.c_()
t.a=r
t.b=p
t.c=n
return t},
m(a,b){a[v.arrayRti]=b
return a},
cX(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.hp(t)
return a.$S()}return null},
ht(a,b){var t
if(A.e0(b))if(a instanceof A.D){t=A.cX(a)
if(t!=null)return t}return A.ah(a)},
ah(a){if(a instanceof A.o)return A.I(a)
if(Array.isArray(a))return A.B(a)
return A.ds(J.ar(a))},
B(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
I(a){var t=a.$ti
return t!=null?t:A.ds(a)},
ds(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.fZ(a,t)},
fZ(a,b){var t=a instanceof A.D?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fJ(v.typeUniverse,t.name)
b.$ccache=s
return s},
hp(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.cS(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
ho(a){return A.a6(A.I(a))},
dw(a){var t=A.cX(a)
return A.a6(t==null?A.ah(a):t)},
dt(a){var t
if(a instanceof A.ap)return A.hl(a.$r,a.aF())
t=a instanceof A.D?A.cX(a):null
if(t!=null)return t
if(u.k.b(a))return J.eT(a).a
if(Array.isArray(a))return A.B(a)
return A.ah(a)},
a6(a){var t=a.r
return t==null?a.r=new A.cR(a):t},
hl(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.j(r,0)
t=A.bm(v.typeUniverse,A.dt(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.j(r,s)
t=A.ef(v.typeUniverse,t,A.dt(r[s]))}return A.bm(v.typeUniverse,t,a)},
X(a){return A.a6(A.cS(v.typeUniverse,a,!1))},
fY(a){var t=this
t.b=A.he(t)
return t.b(a)},
he(a){var t,s,r,q,p
if(a===u.K)return A.h4
if(A.as(a))return A.h8
t=a.w
if(t===6)return A.fW
if(t===1)return A.eo
if(t===7)return A.h_
s=A.hd(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.as)){a.f="$i"+r
if(r==="h")return A.h2
if(a===u.m)return A.h1
return A.h7}}else if(t===10){q=A.hk(a.x,a.y)
p=q==null?A.eo:q
return p==null?A.ei(p):p}return A.fU},
hd(a){if(a.w===8){if(a===u.S)return A.em
if(a===u.i||a===u.H)return A.h3
if(a===u.N)return A.h6
if(a===u.y)return A.cW}return null},
fX(a){var t=this,s=A.fT
if(A.as(t))s=A.fP
else if(t===u.K)s=A.ei
else if(A.aI(t)){s=A.fV
if(t===u.w)s=A.fM
else if(t===u.v)s=A.c3
else if(t===u.d)s=A.R
else if(t===u.x)s=A.q
else if(t===u.I)s=A.fL
else if(t===u.B)s=A.fO}else if(t===u.S)s=A.cU
else if(t===u.N)s=A.af
else if(t===u.y)s=A.dr
else if(t===u.H)s=A.u
else if(t===u.i)s=A.Z
else if(t===u.m)s=A.fN
t.a=s
return t.a(a)},
fU(a){var t=this
if(a==null)return A.aI(t)
return A.ew(v.typeUniverse,A.ht(a,t),t)},
fW(a){if(a==null)return!0
return this.x.b(a)},
h7(a){var t,s=this
if(a==null)return A.aI(s)
t=s.f
if(a instanceof A.o)return!!a[t]
return!!J.ar(a)[t]},
h2(a){var t,s=this
if(a==null)return A.aI(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.o)return!!a[t]
return!!J.ar(a)[t]},
h1(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.o)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
en(a){if(typeof a=="object"){if(a instanceof A.o)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
fT(a){var t=this
if(a==null){if(A.aI(t))return a}else if(t.b(a))return a
throw A.y(A.ej(a,t),new Error())},
fV(a){var t=this
if(a==null||t.b(a))return a
throw A.y(A.ej(a,t),new Error())},
ej(a,b){return new A.aE("TypeError: "+A.e5(a,A.G(b,null)))},
et(a,b,c,d){if(A.ew(v.typeUniverse,a,b))return a
throw A.y(A.fB("The type argument '"+A.G(a,null)+"' is not a subtype of the type variable bound '"+A.G(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
e5(a,b){return A.bw(a)+": type '"+A.G(A.dt(a),null)+"' is not a subtype of type '"+b+"'"},
fB(a){return new A.aE("TypeError: "+a)},
Q(a,b){return new A.aE("TypeError: "+A.e5(a,b))},
h_(a){var t=this
return t.x.b(a)||A.dj(v.typeUniverse,t).b(a)},
h4(a){return a!=null},
ei(a){if(a!=null)return a
throw A.y(A.Q(a,"Object"),new Error())},
h8(a){return!0},
fP(a){return a},
eo(a){return!1},
cW(a){return!0===a||!1===a},
dr(a){if(!0===a)return!0
if(!1===a)return!1
throw A.y(A.Q(a,"bool"),new Error())},
R(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.y(A.Q(a,"bool?"),new Error())},
Z(a){if(typeof a=="number")return a
throw A.y(A.Q(a,"double"),new Error())},
fL(a){if(typeof a=="number")return a
if(a==null)return a
throw A.y(A.Q(a,"double?"),new Error())},
em(a){return typeof a=="number"&&Math.floor(a)===a},
cU(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.y(A.Q(a,"int"),new Error())},
fM(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.y(A.Q(a,"int?"),new Error())},
h3(a){return typeof a=="number"},
u(a){if(typeof a=="number")return a
throw A.y(A.Q(a,"num"),new Error())},
q(a){if(typeof a=="number")return a
if(a==null)return a
throw A.y(A.Q(a,"num?"),new Error())},
h6(a){return typeof a=="string"},
af(a){if(typeof a=="string")return a
throw A.y(A.Q(a,"String"),new Error())},
c3(a){if(typeof a=="string")return a
if(a==null)return a
throw A.y(A.Q(a,"String?"),new Error())},
fN(a){if(A.en(a))return a
throw A.y(A.Q(a,"JSObject"),new Error())},
fO(a){if(a==null)return a
if(A.en(a))return a
throw A.y(A.Q(a,"JSObject?"),new Error())},
ep(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.G(a[r],b)
return t},
hc(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.ep(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.G(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
ek(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.m([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.m(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.j(a3,m)
p=p+o+a3[m]
l=a4[r]
k=l.w
if(!(k===2||k===3||k===4||k===5||l===q))p+=" extends "+A.G(l,a3)}p+=">"}else p=""
q=a2.x
j=a2.y
i=j.a
h=i.length
g=j.b
f=g.length
e=j.c
d=e.length
c=A.G(q,a3)
for(b="",a="",r=0;r<h;++r,a=a0)b+=a+A.G(i[r],a3)
if(f>0){b+=a+"["
for(a="",r=0;r<f;++r,a=a0)b+=a+A.G(g[r],a3)
b+="]"}if(d>0){b+=a+"{"
for(a="",r=0;r<d;r+=3,a=a0){b+=a
if(e[r+1])b+="required "
b+=A.G(e[r+2],a3)+" "+e[r]}b+="}"}if(a1!=null){a3.toString
a3.length=a1}return p+"("+b+") => "+c},
G(a,b){var t,s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){t=a.x
s=A.G(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(m===7)return"FutureOr<"+A.G(a.x,b)+">"
if(m===8){q=A.hh(a.x)
p=a.y
return p.length>0?q+("<"+A.ep(p,b)+">"):q}if(m===10)return A.hc(a,b)
if(m===11)return A.ek(a,b,null)
if(m===12)return A.ek(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.j(b,o)
return b[o]}return"?"},
hh(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
fK(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fJ(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.cS(a,b,!1)
else if(typeof n=="number"){t=n
s=A.bl(a,5,"#")
r=A.cT(t)
for(q=0;q<t;++q)r[q]=s
p=A.bk(a,b,r)
o[b]=p
return p}else return n},
fI(a,b){return A.eg(a.tR,b)},
fH(a,b){return A.eg(a.eT,b)},
cS(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.e9(A.e7(a,null,b,!1))
s.set(b,t)
return t},
bm(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.e9(A.e7(a,b,c,!0))
r.set(c,s)
return s},
ef(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.dp(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
ae(a,b){b.a=A.fX
b.b=A.fY
return b},
bl(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.V(null,null)
t.w=b
t.as=c
s=A.ae(a,t)
a.eC.set(c,s)
return s},
ed(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fF(a,b,s,c)
a.eC.set(s,t)
return t},
fF(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.as(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.aI(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.V(null,null)
r.w=6
r.x=b
r.as=c
return A.ae(a,r)},
ec(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fD(a,b,s,c)
a.eC.set(s,t)
return t},
fD(a,b,c,d){var t,s
if(d){t=b.w
if(A.as(b)||b===u.K)return b
else if(t===1)return A.bk(a,"dK",[b])
else if(b===u.P||b===u.T)return u.Q}s=new A.V(null,null)
s.w=7
s.x=b
s.as=c
return A.ae(a,s)},
fG(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.V(null,null)
t.w=13
t.x=b
t.as=r
s=A.ae(a,t)
a.eC.set(r,s)
return s},
bj(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fC(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
bk(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.bj(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.V(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.ae(a,s)
a.eC.set(q,r)
return r},
dp(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.bj(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.V(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.ae(a,p)
a.eC.set(r,o)
return o},
ee(a,b,c){var t,s,r="+"+(b+"("+A.bj(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.V(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.ae(a,t)
a.eC.set(r,s)
return s},
eb(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.bj(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.bj(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fC(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.V(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.ae(a,q)
a.eC.set(s,p)
return p},
dq(a,b,c,d){var t,s=b.as+("<"+A.bj(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fE(a,b,c,s,d)
a.eC.set(s,t)
return t},
fE(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.cT(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.ag(a,b,s,0)
n=A.aF(a,c,s,0)
return A.dq(a,o,n,c!==n)}}m=new A.V(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.ae(a,m)},
e7(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
e9(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.fw(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.e8(a,s,m,l,!1)
else if(r===46)s=A.e8(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.ao(a.u,a.e,l.pop()))
break
case 94:l.push(A.fG(a.u,l.pop()))
break
case 35:l.push(A.bl(a.u,5,"#"))
break
case 64:l.push(A.bl(a.u,2,"@"))
break
case 126:l.push(A.bl(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.fy(a,l)
break
case 38:A.fx(a,l)
break
case 63:q=a.u
l.push(A.ed(q,A.ao(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.ec(q,A.ao(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.fv(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.ea(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fA(a.u,a.e,p)
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
return A.ao(a.u,a.e,n)},
fw(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
e8(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fK(t,p.x)[q]
if(o==null)A.T('No "'+q+'" in "'+A.fm(p)+'"')
d.push(A.bm(t,p,o))}else d.push(q)
return n},
fy(a,b){var t,s=a.u,r=A.e6(a,b),q=b.pop()
if(typeof q=="string")b.push(A.bk(s,q,r))
else{t=A.ao(s,a.e,q)
switch(t.w){case 11:b.push(A.dq(s,t,r,a.n))
break
default:b.push(A.dp(s,t,r))
break}}},
fv(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.e6(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.ao(q,a.e,p)
r=new A.c_()
r.a=t
r.b=o
r.c=n
b.push(A.eb(q,s,r))
return
case-4:b.push(A.ee(q,b.pop(),t))
return
default:throw A.b(A.bp("Unexpected state under `()`: "+A.t(p)))}},
fx(a,b){var t=b.pop()
if(0===t){b.push(A.bl(a.u,1,"0&"))
return}if(1===t){b.push(A.bl(a.u,4,"1&"))
return}throw A.b(A.bp("Unexpected extended operation "+A.t(t)))},
e6(a,b){var t=b.splice(a.p)
A.ea(a.u,a.e,t)
a.p=b.pop()
return t},
ao(a,b,c){if(typeof c=="string")return A.bk(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.fz(a,b,c)}else return c},
ea(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.ao(a,b,c[t])},
fA(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.ao(a,b,c[t])},
fz(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.b(A.bp("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.b(A.bp("Bad index "+c+" for "+b.j(0)))},
ew(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.x(a,b,null,c,null)
s.set(c,t)}return t},
x(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.as(d))return!0
t=b.w
if(t===4)return!0
if(A.as(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.x(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.x(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.x(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.x(a,b.x,c,d,e))return!1
return A.x(a,A.dj(a,b),c,d,e)}if(t===6)return A.x(a,q,c,d,e)&&A.x(a,b.x,c,d,e)
if(r===7){if(A.x(a,b,c,d.x,e))return!0
return A.x(a,b,c,A.dj(a,d),e)}if(r===6)return A.x(a,b,c,q,e)||A.x(a,b,c,d.x,e)
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
if(!A.x(a,k,c,j,e)||!A.x(a,j,e,k,c))return!1}return A.el(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.el(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.h0(a,b,c,d,e)}if(p&&r===10)return A.h5(a,b,c,d,e)
return!1},
el(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
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
h0(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bm(a,b,s[p])
return A.eh(a,q,null,c,d.y,e)}return A.eh(a,b.y,null,c,d.y,e)},
eh(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.x(a,b[t],d,e[t],f))return!1
return!0},
h5(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.x(a,s[t],c,r[t],e))return!1
return!0},
aI(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.as(a))if(t!==6)s=t===7&&A.aI(a.x)
return s},
as(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
eg(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
cT(a){return a>0?new Array(a):v.typeUniverse.sEA},
V:function V(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
c_:function c_(){this.c=this.b=this.a=null},
cR:function cR(a){this.a=a},
bZ:function bZ(){},
aE:function aE(a){this.a=a},
fg(a,b){return new A.a3(a.i("@<0>").H(b).i("a3<1,2>"))},
H(a,b,c){return b.i("@<0>").H(c).i("dT<1,2>").a(A.hm(a,new A.a3(b.i("@<0>").H(c).i("a3<1,2>"))))},
dU(a,b){return new A.a3(a.i("@<0>").H(b).i("a3<1,2>"))},
de(a){return new A.bc(a.i("bc<0>"))},
dn(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
fu(a,b,c){var t=new A.an(a,b,c.i("an<0>"))
t.c=a.e
return t},
dh(a){var t,s
if(A.dy(a))return"{...}"
t=new A.aA("")
try{s={}
B.a.m($.L,a)
t.a+="{"
s.a=!0
a.N(0,new A.cz(s,t))
t.a+="}"}finally{if(0>=$.L.length)return A.j($.L,-1)
$.L.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
bc:function bc(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
c2:function c2(a){this.a=a
this.c=this.b=null},
an:function an(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
i:function i(){},
K:function K(){},
cz:function cz(a,b){this.a=a
this.b=b},
az:function az(){},
bi:function bi(){},
hb(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.eD(s)
r=A.O(String(t))
throw A.b(r)}r=A.cV(q)
return r},
cV(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.c0(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.cV(a[t])
return a},
dS(a,b,c){return new A.aU(a,b)},
fR(a){return a.W()},
fs(a,b){return new A.cN(a,[],A.hj())},
ft(a,b,c){var t,s=new A.aA(""),r=A.fs(s,b)
r.a9(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
c0:function c0(a,b){this.a=a
this.b=b
this.c=null},
c1:function c1(a){this.a=a},
bs:function bs(){},
bu:function bu(){},
aU:function aU(a,b){this.a=a
this.b=b},
bF:function bF(a,b){this.a=a
this.b=b},
cv:function cv(){},
cx:function cx(a){this.b=a},
cw:function cw(a){this.a=a},
cO:function cO(){},
cP:function cP(a,b){this.a=a
this.b=b},
cN:function cN(a,b,c){this.c=a
this.a=b
this.b=c},
dg(a,b,c,d){var t,s=c?J.dQ(a,d):J.dP(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
dV(a,b,c){var t,s,r=A.m([],c.i("l<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.S)(a),++s)B.a.m(r,c.a(a[s]))
if(b)return r
r.$flags=1
return r},
df(a,b){var t,s=A.m([],b.i("l<0>"))
for(t=a.gv(a);t.n();)B.a.m(s,t.gq())
return s},
e1(a,b,c){var t=J.d8(b)
if(!t.n())return a
if(c.length===0){do a+=A.t(t.gq())
while(t.n())}else{a+=A.t(t.gq())
while(t.n())a=a+c+A.t(t.gq())}return a},
bw(a){if(typeof a=="number"||A.cW(a)||a==null)return J.bn(a)
if(typeof a=="string")return JSON.stringify(a)
return A.dZ(a)},
bp(a){return new A.bo(a)},
c5(a){return new A.a0(!1,null,null,a)},
eV(a,b,c){return new A.a0(!0,a,b,c)},
b3(a,b,c,d,e){return new A.b2(b,c,!0,a,d,"Invalid value")},
fk(a,b,c){if(0>a||a>c)throw A.b(A.b3(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.b(A.b3(b,a,c,"end",null))
return b}return c},
di(a,b){if(a<0)throw A.b(A.b3(a,0,null,b,null))
return a},
d9(a,b,c,d){return new A.by(b,!0,a,d,"Index out of range")},
dm(a){return new A.ba(a)},
e4(a){return new A.bX(a)},
bU(a){return new A.b6(a)},
U(a){return new A.bt(a)},
O(a){return new A.a1(a)},
fa(a,b,c){var t,s
if(A.dy(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.m([],u.s)
B.a.m($.L,a)
try{A.h9(a,t)}finally{if(0>=$.L.length)return A.j($.L,-1)
$.L.pop()}s=A.e1(b,u.R.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
da(a,b,c){var t,s
if(A.dy(a))return b+"..."+c
t=new A.aA(b)
B.a.m($.L,a)
try{s=t
s.a=A.e1(s.a,a,", ")}finally{if(0>=$.L.length)return A.j($.L,-1)
$.L.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
h9(a,b){var t,s,r,q,p,o,n,m=a.gv(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.n())return
t=A.t(m.gq())
B.a.m(b,t)
l+=t.length+2;++k}if(!m.n()){if(k<=5)return
if(0>=b.length)return A.j(b,-1)
s=b.pop()
if(0>=b.length)return A.j(b,-1)
r=b.pop()}else{q=m.gq();++k
if(!m.n()){if(k<=4){B.a.m(b,A.t(q))
return}s=A.t(q)
if(0>=b.length)return A.j(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gq();++k
for(;m.n();q=p,p=o){o=m.gq();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.j(b,-1)
l-=b.pop().length+2;--k}B.a.m(b,"...")
return}}r=A.t(q)
s=A.t(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.j(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.m(b,n)
B.a.m(b,r)
B.a.m(b,s)},
dX(a,b,c,d){var t
if(B.f===c){t=J.M(a)
b=J.M(b)
return A.dl(A.ad(A.ad($.d6(),t),b))}if(B.f===d){t=J.M(a)
b=J.M(b)
c=J.M(c)
return A.dl(A.ad(A.ad(A.ad($.d6(),t),b),c))}t=J.M(a)
b=J.M(b)
c=J.M(c)
d=J.M(d)
d=A.dl(A.ad(A.ad(A.ad(A.ad($.d6(),t),b),c),d))
return d},
p:function p(){},
bo:function bo(a){this.a=a},
b8:function b8(){},
a0:function a0(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
b2:function b2(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
by:function by(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
ba:function ba(a){this.a=a},
bX:function bX(a){this.a=a},
b6:function b6(a){this.a=a},
bt:function bt(a){this.a=a},
b5:function b5(){},
a1:function a1(a){this.a=a},
e:function e(){},
b0:function b0(){},
o:function o(){},
cH:function cH(){this.b=this.a=0},
aA:function aA(a){this.a=a},
f2(a){var t,s,r,q,p,o,n,m,l,k,j=null,i=a.h(0,"aspects")
if(i==null)i=a.h(0,"enemyAspects")
if(u.j.b(i)&&J.eS(i)){t=J.eU(i,new A.c8(),u.i)
s=A.df(t,t.$ti.i("F.E"))}else s=B.o
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
l=A.R(a.h(0,"collideWithEachOther"))
if(l==null)l=A.R(a.h(0,"enemiesCollide"))
k=A.q(a.h(0,"spinDegPerSec"))
if(k==null)k=j
if(k==null)k=0
return new A.bv(t,s,r,q,p,o,n,m,l===!0,k)},
dL(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=null,c="warning",b=A.R(a0.h(0,"startHintEnabled")),a=A.q(a0.h(0,"idleSpeedMultiplier"))
if(a==null)a=d
if(a==null)a=0.5
t=A.R(a0.h(0,"idleEnemiesMove"))
s=A.q(a0.h(0,"speedRampSeconds"))
if(s==null)s=d
if(s==null)s=0.5
r=A.R(a0.h(0,"jumpEnabled"))
if(r==null)r=A.R(a0.h(0,"jumpsEnabled"))
q=A.q(a0.h(0,"jumpDurationSec"))
if(q==null)q=d
if(q==null)q=0.38
p=A.q(a0.h(0,"jumpCooldownSec"))
if(p==null)p=d
if(p==null)p=2
o=A.q(a0.h(0,"jumpScale"))
if(o==null)o=d
if(o==null)o=1.32
n=A.R(a0.h(0,"helmetEnabled"))
m=A.q(a0.h(0,"helmetInvulnSec"))
if(m==null)m=d
if(m==null)m=0.3
l=A.q(a0.h(0,"startInvulnSec"))
if(l==null)l=d
if(l==null)l=1
k=A.R(a0.h(0,"heartbeatHaptic"))
j=A.R(a0.h(0,"timerHaptic"))
i=A.c3(a0.h(0,"timerHapticStyle"))
if(i==null)i=c
h=A.c3(a0.h(0,"timerHapticStyle5"))
if(h==null)h=c
g=A.c3(a0.h(0,"timerHapticStyle10"))
if(g==null)g=c
f=A.q(a0.h(0,"hudSpeedScaleMax"))
if(f==null)f=d
if(f==null)f=400
e=A.R(a0.h(0,"wallsKillPlayer"))
return new A.cf(b!==!1,a,t!==!1,s,r!==!1,q,p,o,n!==!1,m,l,k!==!1,j!==!1,i,h,g,f,e!==!1)},
dW(a,b){if(a==null)return b
if(typeof a!="number"||!isFinite(a)||a<0||a>0.5)throw A.b(B.B)
return a},
cs:function cs(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bv:function bv(a,b,c,d,e,f,g,h,i,j){var _=this
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
c8:function c8(){},
cC:function cC(a,b){this.a=a
this.b=b},
ce:function ce(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cf:function cf(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r){var _=this
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
c6:function c6(){},
cA:function cA(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
f3(a){var t=new A.ca()
t.b2(a)
return t},
ca:function ca(){var _=this
_.y=_.x=_.w=_.r=_.f=_.e=_.d=_.c=_.b=_.a=$
_.as=_.Q=_.z=0
_.at=-100
_.cx=_.CW=_.ch=_.ay=0},
cc:function cc(a){this.a=a},
cb:function cb(a){this.a=a},
dN(a,b){return new A.w(Math.max(a.a,b.a),Math.max(a.b,b.b),Math.min(a.c,b.c),Math.min(a.d,b.d))},
c:function c(a,b){this.a=a
this.b=b},
cG:function cG(a,b){this.a=a
this.b=b},
w:function w(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bx(a,b){var t
if(isFinite(a)&&a>0)t=isFinite(b)&&b>0&&Math.abs(a/b-1)<=0.030000001
else t=!1
return t},
f6(a3,a4,a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
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
if(!A.bx(c,380)||!A.bx(d.b,380))return"world_scale"
if(!A.bx(g,a5.b)||!A.bx(a4.c-f,a4.d-e))return"field_distorted"
t=A.dN(a4,a6)
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
if(A.bx(s,r)){a0=s
if(typeof a0!=="number")return a0.aa()
if(!(a0<0.03)){a=s
if(typeof a!=="number")return a.bM()
a=a>0.25}}if(a)return"hero_scale"
q=(a4.c-f)/c
p=(a4.d-e)/d.b
o=new A.ci(a7)
n=new A.ch(q,p,a3)
f=a7.e
f===$&&A.f()
e=f.a
f=f.b
if(!o.$1(new A.w(e,f,e+b,f+b))||!n.$2(b,b))return"hero_invisible"
g=g.a
f=g.b
e=A.B(f)
d=e.i("am<1>")
a1=A.df(new A.am(f,e.i("r(1)").a(new A.cg()),d),d.i("e.E"))
m=a1
if(J.N(m)===0)J.dB(m,A.m([1,0.25,0.5,3],u.n))
f=a7.f
if(f.length!==4||J.N(m)!==4)return"enemy_count"
l=b*b*B.b.l(g.a,0.2,20)
k=0
for(;;){g=k
if(typeof g!=="number")return g.aa()
if(!(g<4))break
j=B.a.h(f,k)
g=l
e=J.C(m,k)
if(typeof g!=="number")return g.a_()
i=Math.sqrt(g*e)
e=l
g=J.C(m,k)
if(typeof e!=="number")return e.au()
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
g===$&&A.f()
if(isFinite(g.a)&&isFinite(g.b))if(isFinite(j.CW))if(o.$1(j.gA())){g=j.c
g===$&&A.f()
g=g.a
e=j.c
e===$&&A.f()
e=e.b
g=!o.$1(new A.w(g,e,g+j.y,e+j.z))||!n.$2(j.y,j.z)}else g=e
else g=e
else g=e}else g=e
if(g)return"enemy_invisible"
g=j.b
if(isFinite(g.a)&&isFinite(g.b)){g=j.d
g===$&&A.f()
g=!(isFinite(g.a)&&isFinite(g.b))||!isFinite(j.ay)||j.ay<0||!isFinite(j.ch)||j.ch<0}else g=!0
if(g)return"enemy_motion"
g=k
if(typeof g!=="number")return g.G()
k=g+1}return null}catch(a2){return"world_not_ready"}},
ci:function ci(a){this.a=a},
ch:function ch(a,b,c){this.a=a
this.b=b
this.c=c},
cg:function cg(){},
hx(){var t,s,r={}
r.a=null
t=v.G.globalThis
r=new A.d4(r)
if(typeof r=="function")A.T(A.c5("Attempting to rewrap a JS function."))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.fQ,r)
s[$.dA()]=r
t.untouchKernel=s},
d4:function d4(a){this.a=a},
fl(a){var t,s,r,q
for(t=new A.aL(a),s=u.V,t=new A.a4(t,t.gk(0),s.i("a4<i.E>")),s=s.i("i.E"),r=2166136261;t.n();){q=t.d
r=(r^(q==null?s.a(q):q))>>>0
r=r*403+((r&255)<<24>>>0)>>>0}return r===0?1:r},
bS:function bS(a){this.a=a},
cd:function cd(a,b){this.a=a
this.b=b},
dI(a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=null,a0="startPose",a1=new A.c7(A.m([],u.U)),a2=u.c,a3=a2.a(a4.h(0,"config"))
if(J.A(a4.h(0,"proofVersion"),2))a1.a=A.f3(a3.h(0,"enemyPace"))
t=A.f2(a2.a(a3.h(0,"enemies")))
s=a2.a(a3.h(0,"player"))
r=A.q(s.h(0,"size"))
if(r==null)r=a
if(r==null){r=A.q(s.h(0,"playerSize"))
if(r==null)r=a}if(r==null)r=36
q=A.R(s.h(0,"showFace"))
s=q==null?A.R(s.h(0,"playerShowFace")):q
q=a2.a(a3.h(0,"field"))
p=q.h(0,"color")
o=p==null?q.h(0,"colorHex"):p
if(o==null)o=q.h(0,"surfaceColor")
n=typeof o=="string"&&B.e.aW(o).length!==0?B.e.aW(o):a
p=A.q(q.h(0,"borderWidth"))
if(p==null)p=a
if(p==null)p=3
m=A.q(q.h(0,"brightness"))
if(m==null)m=a
if(m==null){m=A.q(q.h(0,"fieldBrightness"))
if(m==null)m=a}if(m==null)m=1
q=A.q(q.h(0,"shadowBrightness"))
if(q==null)q=a
if(q==null)q=1
l=A.dL(a2.a(a3.h(0,"game")))
a2=a2.a(a3.h(0,"mobileEnemies"))
k=a2.h(0,"startSpeedSteps")
j=a2.h(0,"accelerationSteps")
if(typeof k!="number"||typeof j!="number"||!isFinite(k)||!isFinite(j)||k<0.01||k>250||j<0||j>50)A.T(B.E)
i=A.dW(a2.h(0,"speedVariation"),0.05)
a2=A.dW(a2.h(0,"accelerationVariation"),0.08)
h=r*1.2
g=Math.max(0.000001,(h===0?36:h)*0.1)
f=k*g
e=j*g
d=l.W()
d.u(0,"speedRampSeconds",0)
l=A.dL(d)
a2=new A.cs(new A.bv(t.a,t.b,t.c,t.d,f*(1-i),f*(1+i),e*(1-a2),e*(1+a2),t.x,t.y),new A.cC(r,s===!0),new A.ce(p,m,q,n),l,B.u,new A.cA(k,j,i,a2))
a1.b=a2
i=A.fl(A.af(a4.h(0,"requestId")))
p/=2
q=B.b.l(p+0.5,0.5,12)
m=A.m([],u.u)
s=new A.cH()
$.eF()
r=$.e_.$0()
s.a=r
s.b=null
r=A.m([],u.l)
c=u.S
b=A.de(c)
c=A.de(c)
a2=new A.cj(a2,B.r,new A.bS(i),q+p,m,s,r,b,c)
h=(380-h)/2
a2.e=new A.c(h,h)
B.a.F(r)
b.F(0)
c.F(0)
B.a.F(m)
B.a.L(m,a2.bf())
a1.c=a2
a1.d=J.A(a4.h(0,"hadHelmet"),!0)
a1.e=J.A(a4.h(0,"hadJump"),!0)
if(a4.h(0,a0)!=null)a2.bz(a4.h(0,a0))
a1.f=Math.max(0,l.z)
return a1},
c7:function c7(a){var _=this
_.a=null
_.f=_.e=_.d=_.c=_.b=$
_.w=_.r=0
_.z=_.y=_.x=!1
_.Q=null
_.ax=_.at=_.as=0
_.ay=a
_.ch=null},
dM(a,b){var t,s
if(a.Y(b))return 0
t=Math.max(0,Math.max(a.a-b.c,b.a-a.c))
s=Math.max(0,Math.max(a.b-b.d,b.b-a.d))
if(t>0&&s>0)return Math.sqrt(t*t+s*s)
return Math.max(t,s)},
aK:function aK(a,b){this.a=a
this.b=b},
ac:function ac(a){this.a=a
this.b=0},
aj:function aj(a,b,c,d,e,f,g,h){var _=this
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
c9:function c9(a,b,c){this.a=a
this.b=b
this.c=c},
cj:function cj(a,b,c,d,e,f,g,h,i){var _=this
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
cp:function cp(a){this.a=a},
co:function co(){},
cq:function cq(){},
ck:function ck(){},
cl:function cl(){},
cm:function cm(){},
cn:function cn(){},
cr:function cr(a){this.a=a},
fQ(a,b,c){u.Z.a(a)
if(A.cU(c)>=1)return a.$1(b)
return a.$0()},
ey(a,b,c){A.et(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
ex(a,b,c){A.et(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.dc.prototype={}
J.bA.prototype={
K(a,b){return a===b},
gt(a){return A.bQ(a)},
j(a){return"Instance of '"+A.bR(a)+"'"},
gp(a){return A.a6(A.ds(this))}}
J.bC.prototype={
j(a){return String(a)},
gt(a){return a?519018:218159},
gp(a){return A.a6(u.y)},
$ik:1,
$ir:1}
J.aQ.prototype={
K(a,b){return null==b},
j(a){return"null"},
gt(a){return 0},
$ik:1}
J.aS.prototype={$iv:1}
J.ab.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.bP.prototype={}
J.aB.prototype={}
J.a9.prototype={
j(a){var t=a[$.eE()]
if(t==null)t=a[$.dA()]
if(t==null)return this.b1(a)
return"JavaScript function for "+J.bn(t)},
$ia2:1}
J.aR.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.aT.prototype={
gt(a){return 0},
j(a){return String(a)}}
J.l.prototype={
m(a,b){A.B(a).c.a(b)
a.$flags&1&&A.aJ(a,29)
a.push(b)},
bd(a,b,c){var t,s,r,q,p
A.B(a).i("r(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.b(A.U(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
L(a,b){A.B(a).i("e<1>").a(b)
a.$flags&1&&A.aJ(a,"addAll",2)
this.b4(a,b)
return},
b4(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.b(A.U(a))
for(s=0;s<t;++s)a.push(b[s])},
F(a){a.$flags&1&&A.aJ(a,"clear","clear")
a.length=0},
aS(a,b,c){var t=A.B(a)
return new A.P(a,t.H(c).i("1(2)").a(b),t.i("@<1>").H(c).i("P<1,2>"))},
br(a,b){var t,s=A.dg(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.u(s,t,A.t(a[t]))
return s.join(b)},
B(a,b){if(!(b>=0&&b<a.length))return A.j(a,b)
return a[b]},
gJ(a){if(a.length>0)return a[0]
throw A.b(A.dO())},
al(a,b){var t,s
A.B(a).i("r(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.b(A.U(a))}return!1},
av(a,b){var t,s,r,q
a.$flags&2&&A.aJ(a,"shuffle")
t=a.length
while(t>1){s=b.bu(t);--t
r=a.length
if(!(t<r))return A.j(a,t)
q=a[t]
if(!(s>=0&&s<r))return A.j(a,s)
a[t]=a[s]
a[s]=q}},
gC(a){return a.length===0},
gar(a){return a.length!==0},
j(a){return A.da(a,"[","]")},
gv(a){return new J.ai(a,a.length,A.B(a).i("ai<1>"))},
gt(a){return A.bQ(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.aJ(a,"set length","change the length of")
if(b>a.length)A.B(a).c.a(null)
a.length=b},
h(a,b){if(!(b>=0&&b<a.length))throw A.b(A.cY(a,b))
return a[b]},
u(a,b,c){A.B(a).c.a(c)
a.$flags&2&&A.aJ(a)
if(!(b>=0&&b<a.length))throw A.b(A.cY(a,b))
a[b]=c},
$ie:1,
$ih:1}
J.bB.prototype={
bG(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bR(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.ct.prototype={}
J.ai.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.S(r)
throw A.b(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$ia8:1}
J.av.prototype={
am(a,b){var t
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gaq(b)
if(this.gaq(a)===t)return 0
if(this.gaq(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gaq(a){return a===0?1/a<0:a<0},
bi(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.b(A.dm(""+a+".ceil()"))},
ao(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.b(A.dm(""+a+".floor()"))},
bA(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.b(A.dm(""+a+".round()"))},
l(a,b,c){if(this.am(b,c)>0)throw A.b(A.er(b))
if(this.am(a,b)<0)return b
if(this.am(a,c)>0)return c
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
ab(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
aK(a,b){var t
if(a>0)t=this.be(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
be(a,b){return b>31?0:a>>>b},
gp(a){return A.a6(u.H)},
$id:1,
$iW:1}
J.aP.prototype={
gp(a){return A.a6(u.S)},
$ik:1,
$ia:1}
J.bD.prototype={
gp(a){return A.a6(u.i)},
$ik:1}
J.aw.prototype={
a2(a,b,c){return a.substring(b,A.fk(b,c,a.length))},
aW(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.j(q,0)
if(q.charCodeAt(0)===133){t=J.fc(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.j(q,s)
r=q.charCodeAt(s)===133?J.fd(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
j(a){return a},
gt(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gp(a){return A.a6(u.N)},
gk(a){return a.length},
$ik:1,
$in:1}
A.aa.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.aL.prototype={
gk(a){return this.a.length},
h(a,b){var t=this.a
if(!(b>=0&&b<t.length))return A.j(t,b)
return t.charCodeAt(b)}}
A.cF.prototype={}
A.aO.prototype={}
A.F.prototype={
gv(a){var t=this
return new A.a4(t,t.gk(t),A.I(t).i("a4<F.E>"))},
gC(a){return this.gk(this)===0},
a8(a,b){var t,s,r,q=this
A.I(q).i("F.E(F.E,F.E)").a(b)
t=q.gk(q)
if(t===0)throw A.b(A.dO())
s=q.B(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.B(0,r))
if(t!==q.gk(q))throw A.b(A.U(q))}return s}}
A.b7.prototype={
gb7(){var t=J.N(this.a),s=this.c
if(s==null||s>t)return t
return s},
gbg(){var t=J.N(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.N(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
B(a,b){var t=this,s=t.gbg()+b
if(b<0||s>=t.gb7())throw A.b(A.d9(b,t.gk(0),t,"index"))
return J.dD(t.a,s)},
bF(a,b){var t,s,r,q=this,p=q.b,o=q.a,n=J.aH(o),m=n.gk(o),l=q.c
if(l!=null&&l<m)m=l
t=m-p
if(t<=0){o=q.$ti.c
return b?J.dQ(0,o):J.dP(0,o)}s=A.dg(t,n.B(o,p),b,q.$ti.c)
for(r=1;r<t;++r){B.a.u(s,r,n.B(o,p+r))
if(n.gk(o)<m)throw A.b(A.U(q))}return s},
aV(a){return this.bF(0,!0)}}
A.a4.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t,s=this,r=s.a,q=J.aH(r),p=q.gk(r)
if(s.b!==p)throw A.b(A.U(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.B(r,t);++s.c
return!0},
$ia8:1}
A.P.prototype={
gk(a){return J.N(this.a)},
B(a,b){return this.b.$1(J.dD(this.a,b))}}
A.am.prototype={
gv(a){return new A.bb(J.d8(this.a),this.b,this.$ti.i("bb<1>"))}}
A.bb.prototype={
n(){var t,s
for(t=this.a,s=this.b;t.n();)if(s.$1(t.gq()))return!0
return!1},
gq(){return this.a.gq()},
$ia8:1}
A.E.prototype={}
A.b9.prototype={}
A.aC.prototype={}
A.bh.prototype={$r:"+(1,2)",$s:1}
A.aM.prototype={
gC(a){return this.gk(this)===0},
j(a){return A.dh(this)},
$iY:1}
A.aN.prototype={
gk(a){return this.b.length},
gb9(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
I(a){if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
h(a,b){if(!this.I(b))return null
return this.b[this.a[b]]},
N(a,b){var t,s,r,q
this.$ti.i("~(1,2)").a(b)
t=this.gb9()
s=this.b
for(r=t.length,q=0;q<r;++q)b.$2(t[q],s[q])}}
A.bz.prototype={
K(a,b){if(b==null)return!1
return b instanceof A.ak&&this.a.K(0,b.a)&&A.dw(this)===A.dw(b)},
gt(a){return A.dX(this.a,A.dw(this),B.f,B.f)},
j(a){var t=B.a.br([A.a6(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.ak.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hu(A.cX(this.a),this.$ti)}}
A.cD.prototype={
$0(){return B.b.ao(1000*this.a.now())},
$S:1}
A.b4.prototype={}
A.cI.prototype={
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
A.b1.prototype={
j(a){return"Null check operator used on a null value"}}
A.bE.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bY.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.cB.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.D.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.eC(s==null?"unknown":s)+"'"},
$ia2:1,
gbL(){return this},
$C:"$1",
$R:1,
$D:null}
A.bq.prototype={$C:"$0",$R:0}
A.br.prototype={$C:"$2",$R:2}
A.bW.prototype={}
A.bV.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.eC(t)+"'"}}
A.au.prototype={
K(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.au))return!1
return this.$_target===b.$_target&&this.a===b.a},
gt(a){return(A.ez(this.a)^A.bQ(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bR(this.a)+"'")}}
A.bT.prototype={
j(a){return"RuntimeError: "+this.a}}
A.a3.prototype={
gk(a){return this.a},
gC(a){return this.a===0},
gO(){return new A.al(this,A.I(this).i("al<1>"))},
I(a){var t=this.b
if(t==null)return!1
return t[a]!=null},
L(a,b){A.I(this).i("Y<1,2>").a(b).N(0,new A.cu(this))},
h(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.bp(b)},
bp(a){var t,s,r=this.d
if(r==null)return null
t=r[this.aN(a)]
s=this.aO(t,a)
if(s<0)return null
return t[s].b},
u(a,b,c){var t,s,r=this,q=A.I(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.aA(t==null?r.b=r.aj():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.aA(s==null?r.c=r.aj():s,b,c)}else r.bq(b,c)},
bq(a,b){var t,s,r,q,p=this,o=A.I(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.aj()
s=p.aN(a)
r=t[s]
if(r==null)t[s]=[p.ak(a,b)]
else{q=p.aO(r,a)
if(q>=0)r[q].b=b
else r.push(p.ak(a,b))}},
N(a,b){var t,s,r=this
A.I(r).i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.b(A.U(r))
t=t.c}},
aA(a,b,c){var t,s=A.I(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.ak(b,c)
else t.b=c},
ak(a,b){var t=this,s=A.I(t),r=new A.cy(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
aN(a){return J.M(a)&1073741823},
aO(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.A(a[s].a,b))return s
return-1},
j(a){return A.dh(this)},
aj(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$idT:1}
A.cu.prototype={
$2(a,b){var t=this.a,s=A.I(t)
t.u(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.I(this.a).i("~(1,2)")}}
A.cy.prototype={}
A.al.prototype={
gk(a){return this.a.a},
gC(a){return this.a.a===0},
gv(a){var t=this.a
return new A.aW(t,t.r,t.e,this.$ti.i("aW<1>"))},
V(a,b){return this.a.I(b)}}
A.aW.prototype={
gq(){return this.d},
n(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.b(A.U(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$ia8:1}
A.d0.prototype={
$1(a){return this.a(a)},
$S:2}
A.d1.prototype={
$2(a,b){return this.a(a,b)},
$S:6}
A.d2.prototype={
$1(a){return this.a(A.af(a))},
$S:7}
A.ap.prototype={
j(a){return this.aL(!1)},
aL(a){var t,s,r,q,p,o=this.b8(),n=this.aF(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.j(n,r)
p=n[r]
m=a?m+A.dZ(p):m+A.t(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
b8(){var t,s=this.$s
while($.cQ.length<=s)B.a.m($.cQ,null)
t=$.cQ[s]
if(t==null){t=this.b5()
B.a.u($.cQ,s,t)}return t},
b5(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=u.K,k=J.db(m,l)
for(t=0;t<m;++t)k[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.u(k,r,s[t])}}k=A.dV(k,!1,l)
k.$flags=3
return k}}
A.aD.prototype={
aF(){return[this.a,this.b]},
K(a,b){if(b==null)return!1
return b instanceof A.aD&&this.$s===b.$s&&J.A(this.a,b.a)&&J.A(this.b,b.b)},
gt(a){return A.dX(this.$s,this.a,this.b,B.f)}}
A.cK.prototype={
R(){var t=this.b
if(t===this)throw A.b(new A.aa("Local '' has not been initialized."))
return t}}
A.ax.prototype={
gp(a){return B.Q},
$ik:1}
A.aZ.prototype={}
A.bG.prototype={
gp(a){return B.R},
$ik:1}
A.ay.prototype={
gk(a){return a.length},
$iJ:1}
A.aX.prototype={
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ie:1,
$ih:1}
A.aY.prototype={$ie:1,$ih:1}
A.bH.prototype={
gp(a){return B.S},
$ik:1}
A.bI.prototype={
gp(a){return B.T},
$ik:1}
A.bJ.prototype={
gp(a){return B.U},
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ik:1}
A.bK.prototype={
gp(a){return B.V},
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ik:1}
A.bL.prototype={
gp(a){return B.W},
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ik:1}
A.bM.prototype={
gp(a){return B.Y},
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ik:1}
A.bN.prototype={
gp(a){return B.Z},
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ik:1}
A.b_.prototype={
gp(a){return B.a_},
gk(a){return a.length},
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ik:1}
A.bO.prototype={
gp(a){return B.a0},
gk(a){return a.length},
h(a,b){A.aq(b,a,a.length)
return a[b]},
$ik:1}
A.bd.prototype={}
A.be.prototype={}
A.bf.prototype={}
A.bg.prototype={}
A.V.prototype={
i(a){return A.bm(v.typeUniverse,this,a)},
H(a){return A.ef(v.typeUniverse,this,a)}}
A.c_.prototype={}
A.cR.prototype={
j(a){return A.G(this.a,null)}}
A.bZ.prototype={
j(a){return this.a}}
A.aE.prototype={}
A.bc.prototype={
gv(a){var t=this,s=new A.an(t,t.r,t.$ti.i("an<1>"))
s.c=t.e
return s},
gk(a){return this.a},
V(a,b){var t
if((b&1073741823)===b){t=this.c
if(t==null)return!1
return u.L.a(t[b])!=null}else return this.b6(b)},
b6(a){var t=this.d
if(t==null)return!1
return this.aE(t[B.c.gt(a)&1073741823],a)>=0},
m(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.aB(t==null?r.b=A.dn():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.aB(s==null?r.c=A.dn():s,b)}else return r.b3(b)},
b3(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.dn()
s=J.M(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.af(a)]
else{if(q.aE(r,a)>=0)return!1
r.push(q.af(a))}return!0},
F(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.aG()}},
aB(a,b){this.$ti.c.a(b)
if(u.L.a(a[b])!=null)return!1
a[b]=this.af(b)
return!0},
aG(){this.r=this.r+1&1073741823},
af(a){var t,s=this,r=new A.c2(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.aG()
return r},
aE(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.A(a[s].a,b))return s
return-1}}
A.c2.prototype={}
A.an.prototype={
gq(){var t=this.d
return t==null?this.$ti.c.a(t):t},
n(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.b(A.U(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.i("1?").a(s.a)
t.c=s.b
return!0}},
$ia8:1}
A.i.prototype={
gv(a){return new A.a4(a,this.gk(a),A.ah(a).i("a4<i.E>"))},
B(a,b){return this.h(a,b)},
gC(a){return this.gk(a)===0},
gar(a){return this.gk(a)!==0},
al(a,b){var t,s
A.ah(a).i("r(i.E)").a(b)
t=this.gk(a)
for(s=0;s<t;++s){if(b.$1(this.h(a,s)))return!0
if(t!==this.gk(a))throw A.b(A.U(a))}return!1},
aS(a,b,c){var t=A.ah(a)
return new A.P(a,t.H(c).i("1(i.E)").a(b),t.i("@<i.E>").H(c).i("P<1,2>"))},
j(a){return A.da(a,"[","]")},
$ie:1,
$ih:1}
A.K.prototype={
N(a,b){var t,s,r,q=A.I(this)
q.i("~(K.K,K.V)").a(b)
for(t=this.gO(),t=t.gv(t),q=q.i("K.V");t.n();){s=t.gq()
r=this.h(0,s)
b.$2(s,r==null?q.a(r):r)}},
I(a){return this.gO().V(0,a)},
gk(a){var t=this.gO()
return t.gk(t)},
gC(a){var t=this.gO()
return t.gC(t)},
j(a){return A.dh(this)},
$iY:1}
A.cz.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.t(a)
s.a=(s.a+=t)+": "
t=A.t(b)
s.a+=t},
$S:3}
A.az.prototype={
L(a,b){var t,s,r
this.$ti.i("e<1>").a(b)
for(t=A.fu(b,b.r,b.$ti.c),s=t.$ti.c;t.n();){r=t.d
this.m(0,r==null?s.a(r):r)}},
j(a){return A.da(this,"{","}")},
$ie:1,
$idk:1}
A.bi.prototype={}
A.c0.prototype={
h(a,b){var t,s=this.b
if(s==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.bb(b):t}},
gk(a){return this.b==null?this.c.a:this.a4().length},
gC(a){return this.gk(0)===0},
gO(){if(this.b==null){var t=this.c
return new A.al(t,A.I(t).i("al<1>"))}return new A.c1(this)},
I(a){if(this.b==null)return this.c.I(a)
return Object.prototype.hasOwnProperty.call(this.a,a)},
N(a,b){var t,s,r,q,p=this
u.D.a(b)
if(p.b==null)return p.c.N(0,b)
t=p.a4()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.cV(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.b(A.U(p))}},
a4(){var t=u._.a(this.c)
if(t==null)t=this.c=A.m(Object.keys(this.a),u.s)
return t},
bb(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.cV(this.a[a])
return this.b[a]=t}}
A.c1.prototype={
gk(a){return this.a.gk(0)},
B(a,b){var t=this.a
if(t.b==null)t=t.gO().B(0,b)
else{t=t.a4()
if(!(b>=0&&b<t.length))return A.j(t,b)
t=t[b]}return t},
gv(a){var t=this.a
if(t.b==null){t=t.gO()
t=t.gv(t)}else{t=t.a4()
t=new J.ai(t,t.length,A.B(t).i("ai<1>"))}return t},
V(a,b){return this.a.I(b)}}
A.bs.prototype={}
A.bu.prototype={}
A.aU.prototype={
j(a){var t=A.bw(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.bF.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.cv.prototype={
bk(a,b){var t=A.hb(a,this.gbl().a)
return t},
X(a,b){var t=A.ft(a,this.gbn().b,null)
return t},
gbn(){return B.L},
gbl(){return B.K}}
A.cx.prototype={}
A.cw.prototype={}
A.cO.prototype={
aY(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.e.a2(a,s,r)
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
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.e.a2(a,s,r)
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
break}}else if(q===34||q===92){if(r>s)t.a+=B.e.a2(a,s,r)
s=r+1
p=A.z(92)
t.a+=p
p=A.z(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.e.a2(a,s,n)},
ae(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.b(new A.bF(a,null))}B.a.m(t,a)},
a9(a){var t,s,r,q,p=this
if(p.aX(a))return
p.ae(a)
try{t=p.b.$1(a)
if(!p.aX(t)){r=A.dS(a,null,p.gaI())
throw A.b(r)}r=p.a
if(0>=r.length)return A.j(r,-1)
r.pop()}catch(q){s=A.eD(q)
r=A.dS(a,s,p.gaI())
throw A.b(r)}},
aX(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.aY(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.ae(a)
r.bJ(a)
t=r.a
if(0>=t.length)return A.j(t,-1)
t.pop()
return!0}else if(u.f.b(a)){r.ae(a)
s=r.bK(a)
t=r.a
if(0>=t.length)return A.j(t,-1)
t.pop()
return s}else return!1},
bJ(a){var t,s,r=this.c
r.a+="["
t=J.aH(a)
if(t.gar(a)){this.a9(t.h(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.a9(t.h(a,s))}}r.a+="]"},
bK(a){var t,s,r,q,p,o,n=this,m={}
if(a.gC(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.dg(t,null,!1,u.X)
r=m.a=0
m.b=!0
a.N(0,new A.cP(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.aY(A.af(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.j(s,o)
n.a9(s[o])}q.a+="}"
return!0}}
A.cP.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.u(t,s.a++,a)
B.a.u(t,s.a++,b)},
$S:3}
A.cN.prototype={
gaI(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.p.prototype={}
A.bo.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bw(t)
return"Assertion failed"}}
A.b8.prototype={}
A.a0.prototype={
gah(){return"Invalid argument"+(!this.a?"(s)":"")},
gag(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+A.t(q),o=t.gah()+r+p
if(!t.a)return o
return o+t.gag()+": "+A.bw(t.gap())},
gap(){return this.b}}
A.b2.prototype={
gap(){return A.q(this.b)},
gah(){return"RangeError"},
gag(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.t(r):""
else if(r==null)t=": Not greater than or equal to "+A.t(s)
else if(r>s)t=": Not in inclusive range "+A.t(s)+".."+A.t(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.t(s)
return t}}
A.by.prototype={
gap(){return A.cU(this.b)},
gah(){return"RangeError"},
gag(){if(A.cU(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.ba.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bX.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.b6.prototype={
j(a){return"Bad state: "+this.a}}
A.bt.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bw(t)+"."}}
A.b5.prototype={
j(a){return"Stack Overflow"},
$ip:1}
A.a1.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.e.prototype={
gk(a){var t,s=this.gv(this)
for(t=0;s.n();)++t
return t},
B(a,b){var t,s
A.di(b,"index")
t=this.gv(this)
for(s=b;t.n();){if(s===0)return t.gq();--s}throw A.b(A.d9(b,b-s,this,"index"))},
j(a){return A.fa(this,"(",")")}}
A.b0.prototype={
gt(a){return A.o.prototype.gt.call(this,0)},
j(a){return"null"}}
A.o.prototype={$io:1,
K(a,b){return this===b},
gt(a){return A.bQ(this)},
j(a){return"Instance of '"+A.bR(this)+"'"},
gp(a){return A.ho(this)},
toString(){return this.j(this)}}
A.cH.prototype={}
A.aA.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$ifn:1}
A.cs.prototype={}
A.bv.prototype={
W(){var t=this
return A.H(["areaMultiplier",t.a,"aspects",t.b,"angleMinDeg",t.c,"angleMaxDeg",t.d,"speedMin",t.e,"speedMax",t.f,"accelMin",t.r,"accelMax",t.w,"collideWithEachOther",t.x,"spinDegPerSec",t.y],u.N,u.z)}}
A.c8.prototype={
$1(a){return A.u(a)},
$S:8}
A.cC.prototype={
W(){return A.H(["size",this.a,"showFace",this.b],u.N,u.z)}}
A.ce.prototype={
W(){var t,s=this,r=A.dU(u.N,u.z)
r.u(0,"borderWidth",s.a)
r.u(0,"brightness",s.b)
r.u(0,"shadowBrightness",s.c)
t=s.d
if(t!=null&&t.length!==0)r.u(0,"color",t)
return r}}
A.cf.prototype={
W(){var t=this
return A.H(["startHintEnabled",t.a,"idleSpeedMultiplier",t.b,"idleEnemiesMove",t.c,"speedRampSeconds",t.d,"jumpEnabled",t.e,"jumpDurationSec",t.f,"jumpCooldownSec",t.r,"jumpScale",t.w,"helmetEnabled",t.x,"helmetInvulnSec",t.y,"startInvulnSec",t.z,"heartbeatHaptic",t.Q,"timerHaptic",t.as,"timerHapticStyle",t.at,"timerHapticStyle5",t.ax,"timerHapticStyle10",t.ay,"hudSpeedScaleMax",t.ch,"wallsKillPlayer",t.CW],u.N,u.z)}}
A.c6.prototype={
W(){return A.H(["sfxMobWall",!0,"sfxMobCollide",!0,"sfxHeroMob",!0,"sfxHeroWall",!0,"sfxNearMiss",!0,"sfxHelmet",!0,"sfxJump",!0,"sfxStart",!0,"music",!0,"sfxVolume",1,"musicVolume",0.08],u.N,u.z)}}
A.cA.prototype={}
A.ca.prototype={
b2(a){var t=this,s=u.f.b(a)?a:B.M,r=new A.cc(s),q=new A.cb(s),p=A.dr(q.$1("brakeEnabled"))
t.a!==$&&A.a7()
t.a=p
q=A.dr(q.$1("speedBarEnabled"))
t.b!==$&&A.a7()
t.b=q
q=A.Z(r.$4("initialSpeed",0,0,150))
t.c!==$&&A.a7()
t.c=q
q=A.Z(r.$4("growthMultiplier",70,0,200))
t.d!==$&&A.a7()
t.d=q
q=A.Z(r.$4("growthExponent",0.2,0.01,1))
t.e!==$&&A.a7()
t.e=q
q=A.Z(r.$4("startSmoothingSec",3,0.01,60))
t.f!==$&&A.a7()
t.f=q
q=A.Z(r.$4("initialCompensation",1,0,10))
t.r!==$&&A.a7()
t.r=q
q=A.Z(r.$4("brakeCooldownSec",6,0.1,120))
t.w!==$&&A.a7()
t.w=q
q=A.Z(r.$4("brakeFirstReadySec",6,0.1,120))
t.x!==$&&A.a7()
t.x=q
r=A.Z(r.$4("brakeRewindSec",6,0,120))
t.y!==$&&A.a7()
t.y=r
t.as=q},
ac(a){var t,s,r,q,p=this,o=p.c
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
ga0(){var t=this
return t.ac(t.Q)+t.ay*B.b.l(1-(t.z-t.at)/0.18,0,1)},
gZ(){var t=this.a
t===$&&A.f()
return t&&this.z+1e-9>=this.as},
bw(){var t,s,r=this
if(!r.gZ())return!1
r.ch=r.ga0()
t=r.Q
s=r.y
s===$&&A.f()
s=Math.max(0,t-s)
r.Q=s
s=r.ac(s)
r.CW=s
r.ay=Math.max(0,r.ch-s)
s=r.z
r.at=s
t=r.w
t===$&&A.f()
r.as=s+t;++r.cx
return!0},
bx(a,b,c,d,e,f){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this.a
g===$&&A.f()
if(!g||!this.gZ()||!c)return!1
t=d/2
for(g=u.n,g=[A.m([a+t,e+t],g),A.m([b+t,f+t],g)],s=190-d,r=190+d,q=0,p=1,o=0;o<2;++o){n=g[o]
if(1>=n.length)return A.j(n,1)
m=n[1]
l=n[0]
k=m-l
if(Math.abs(k)<1e-9){if(l<=s||l>=r)return!1}else{j=(s-l)/k
i=(r-l)/k
if(j>i){h=i
i=j
j=h}q=Math.max(q,j)
p=Math.min(p,i)}}return q<=p&&this.bw()}}
A.cc.prototype={
$4(a,b,c,d){var t=this.a.h(0,a)
if(t==null)t=b
if(typeof t!="number"||!isFinite(t)||t<c||t>d)throw A.b(A.O("enemy_pace_"+a))
return t},
$S:9}
A.cb.prototype={
$1(a){var t=this.a,s=!t.I(a)||t.h(0,a)
if(!A.cW(s))throw A.b(A.O("enemy_pace_"+a))
return s},
$S:10}
A.c.prototype={
G(a,b){return new A.c(this.a+b.a,this.b+b.b)},
a1(a,b){return new A.c(this.a-b.a,this.b-b.b)},
a_(a,b){return new A.c(this.a*b,this.b*b)},
au(a,b){return new A.c(this.a/b,this.b/b)},
gbm(){var t=this.a,s=this.b
return Math.sqrt(t*t+s*s)}}
A.cG.prototype={}
A.w.prototype={
gU(){var t=this
return new A.c((t.a+t.c)/2,(t.b+t.d)/2)},
Y(a){var t=this
return t.a<a.c&&t.c>a.a&&t.b<a.d&&t.d>a.b}}
A.ci.prototype={
$1(a){var t,s,r,q=a.a,p=a.b
if(isFinite(q)&&isFinite(p)){s=a.c-q
r=a.d-p
r=!(isFinite(s)&&s>0&&isFinite(r)&&r>0)
s=r}else s=!0
if(s)return!1
s=this.a.b
t=A.dN(a,new A.w(0,0,0+s.a,0+s.b))
s=t
if(!(s.c-s.a<=0||s.d-s.b<=0)){s=t
r=t
p=(s.c-s.a)*(r.d-r.b)/((a.c-q)*(a.d-p))>=0.97
q=p}else q=!1
return q},
$S:11}
A.ch.prototype={
$2(a,b){return Math.min(a*this.a,b*this.b)*this.c>=8},
$S:12}
A.cg.prototype={
$1(a){A.Z(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.d4.prototype={
$1(a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=null,a4="events",a5="startPose"
A.af(a6)
try{j=u.c
t=j.a(B.d.bk(a6,a3))
s=J.C(t,"op")
if(J.A(s,"verify")){r=J.C(t,"proof")
k=!0
if(u.f.b(r))if(J.A(r.h(0,"version"),2)){k=u.j
k=!k.b(r.h(0,a4))||J.N(k.a(r.h(0,a4)))>6e5||!k.b(r.h(0,a5))}if(k){q=A.O("proof")
throw A.b(q)}k=u.N
j=u.z
i=A.fg(k,j)
i.L(0,t)
q=i
J.d7(q,"proofVersion",2)
J.d7(q,a5,r.h(0,a5))
p=A.dI(q)
p.az()
for(q=J.d8(u.R.a(r.h(0,a4))),i=u.j;q.n();){o=q.gq()
if(!i.b(o)||J.eR(o)){q=A.O("event")
throw A.b(q)}if(J.A(J.C(o,0),2)){if(J.N(o)!==1){q=A.O("jump")
throw A.b(q)}n=p.ax
p.aP()
h=p.ax
g=n
if(typeof g!=="number")return g.G()
if(h!==g+1){q=A.O("jump")
throw A.b(q)}}else{if(!(J.A(J.C(o,0),0)&&J.N(o)!==2))h=J.A(J.C(o,0),1)&&J.N(o)!==3
else h=!0
if(h){q=A.O("event")
throw A.b(q)}p.a5(o)}}if(!p.y){q=A.O("unfinished")
throw A.b(q)}m=p.gaw()
f=B.d.X(A.H(["ok",!0,"timeMs",J.C(m,"timeMs"),"runDistance",J.C(m,"runDistance"),"riskCount",J.C(m,"riskCount")],k,j),a3)
return f}if(J.A(s,"rewardFrame")){q=A.u(J.C(t,"p"))
k=J.A(J.C(t,"reduced"),!0)
l=new A.cd(B.b.l(q,0,1),k)
k=l.a
q=B.b.l(l.a/0.1125,0,1)
j=l.gM()
i=l.gaM()
h=l
if(h.b)h=1
else{g=B.b.l(h.a/0.1125,0,1)-1
h=(0.82+0.18*(1+2.70158*Math.pow(g,3)+1.70158*Math.pow(g,2)))*(1-0.78*h.gaM())}g=l
e=B.b.l(g.a/0.1125,0,1)
g=B.b.l((g.gM()-0.76)/0.24,0,1)
d=l
c=d.b
d=d.a
d=c?d:B.b.l((d-0.8)/0.2,0,1)
c=l
c=c.b?0:Math.sin(3.141592653589793*B.b.l((c.a-0.83)/0.17,0,1))
f=B.d.X(A.H(["ok",!0,"p",k,"appearance",q,"flight",j,"fly",i,"scale",h,"opacity",e*(1-g),"roll",d,"hit",c],u.N,u.K),a3)
return f}if(J.A(s,"create")){q=this.a
q.a=A.dI(t)}else{q=this.a
i=q.a
if(i==null){q=A.bU("session_missing")
throw A.b(q)}switch(s){case"idle":j=A.u(J.C(t,"ms"))
if(i.x||i.y||!isFinite(j)||j<=0||j>50)A.T(A.bU("idle"))
h=i.c
h===$&&A.f()
b=h.bB(j/1000)
i.as=b.a
i.at=b.b
break
case"start":i.az()
break
case"tick":i.a5([0,J.C(t,"ms")])
break
case"move":j=A.u(J.C(t,"dx"))
h=A.u(J.C(t,"dy"))
if(!i.x)A.T(A.bU("move"))
if(i.w===0)i.a5([0,1])
if(!i.y)i.a5([1,j,h])
break
case"jump":i.aP()
break
case"snapshot":break
case"proof":q=i.a==null?1:2
k=u.N
f=B.d.X(A.H(["ok",!0,"proof",A.H(["version",q,"events",i.ay,"startPose",i.ch],k,u.z)],k,u.K),a3)
return f
case"guard":q=j.a(t)
k=u.j
a=k.a(q.h(0,"field"))
a0=k.a(q.h(0,"visible"))
i=i.c
i===$&&A.f()
k=J.a_(a)
j=A.u(k.h(a,0))
h=A.u(k.h(a,1))
g=A.u(k.h(a,2))
k=A.u(k.h(a,3))
e=J.a_(a0)
d=A.u(e.h(a0,0))
c=A.u(e.h(a0,1))
a1=A.u(e.h(a0,2))
e=A.u(e.h(a0,3))
f=B.d.X(A.H(["ok",!0,"issue",A.f6(A.u(q.h(0,"dpr")),new A.w(j,h,j+g,h+k),B.r,new A.w(d,c,d+a1,c+e),i)],u.N,u.X),a3)
return f
default:q=A.O("unknown_operation")
throw A.b(q)}}k=A.dU(u.N,u.z)
J.d7(k,"ok",!0)
J.dB(k,q.a.gaw())
f=B.d.X(k,a3)
return f}catch(a2){return'{"ok":false,"error":"invalid_kernel_operation"}'}},
$S:13}
A.bS.prototype={
ba(){var t=this.a
t^=t<<13
t^=t>>>17
return this.a=(t^t<<5)>>>0},
E(){var t=this.a
t^=t<<13
t^=t>>>17
t=(t^t<<5)>>>0
this.a=t
return t/4294967296},
bu(a){if(a<=0)throw A.b(A.eV(a,null,null))
return B.b.ao(this.ba()/4294967296*a)},
$ifj:1}
A.cd.prototype={
gM(){return this.b?0:B.b.l((this.a-0.4)/0.4,0,1)},
gaM(){var t=this
return t.gM()<0.5?4*t.gM()*t.gM()*t.gM():1-Math.pow(-2*t.gM()+2,3)/2}}
A.c7.prototype={
ga6(){var t=this.f
t===$&&A.f()
return t>0||this.r>0},
az(){var t,s=this
if(s.x||s.y)throw A.b(A.bU("start"))
t=s.c
t===$&&A.f()
t.b_()
s.ch=t.gb0()
s.at=s.as=0
s.x=!0},
bj(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this
if(e.ga6())return
t=e.c
t===$&&A.f()
s=t.a.d.CW&&t.aU()
r=!s
if(r&&!t.bv())return
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
i=m}}else{h=new A.w(p,q,p+o,q+o)
q=t.f
p=q.length
g=0
for(;;){if(!(g<q.length)){j=l
i=m
break}f=q[g]
if(h.Y(f.gA())){q=f.gA()
i=(m+(q.a+q.c)/2)/2
q=f.gA()
j=(l+(q.b+q.d)/2)/2
break}q.length===p||(0,A.S)(q);++g}}e.Q=A.H(["x",i,"y",j],u.N,u.i)
q=e.d
q===$&&A.f()
if(q){e.d=!1
q=e.b
q===$&&A.f()
e.r=Math.max(0,q.d.y)
if(r)t.by()}else{e.y=!0
e.x=!1}},
aP(){var t,s=this,r=!0
if(s.x){t=s.e
t===$&&A.f()
if(t){r=s.c
r===$&&A.f()
r=!r.bH(s.w)}}if(r)return;++s.ax
B.a.m(s.ay,A.m([2],u.a))},
a5(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g=this,f=g.c
f===$&&A.f()
t=f.e
t===$&&A.f()
if(!g.x||g.y||g.ay.length>=6e5)throw A.b(A.bU("event"))
s=J.a_(a)
if(J.A(s.h(a,0),0)){r=A.u(s.h(a,1))
if(!isFinite(r)||r<=0||r>50||g.w+r>36e5)throw A.b(A.O("tick"))
B.a.m(g.ay,A.m([0,r],u.a))
g.w+=r
q=r/1000
s=g.a
if(s!=null){s.z+=q
s.Q+=q}f.bC(q)
s=g.w
p=g.ga6()
o=g.a
o=o==null?null:o.ga0()*(f.a.b.a*1.2)*0.1
n=f.bE(q,s/1000,!p,o)
g.as=n.a
g.at=n.b
o=g.f
o===$&&A.f()
g.f=Math.max(0,o-q)
g.r=Math.max(0,g.r-q)}else if(J.A(s.h(a,0),1)){m=A.u(s.h(a,1))
l=A.u(s.h(a,2))
if(!isFinite(m)||!isFinite(l)||Math.abs(m)>2000||Math.abs(l)>2000)throw A.b(A.O("move"))
B.a.m(g.ay,A.m([1,m,l],u.a))
f.bs(new A.c(m,l),!g.ga6())}else throw A.b(A.O("event"))
s=f.a
if(!s.d.CW&&f.aU()){k=s.b.a*1.2
j=f.d
s=f.b
i=Math.max(j,s.a-j-k)
h=Math.max(j,s.b-j-k)
s=f.e
s===$&&A.f()
f.e=new A.c(B.b.l(s.a,j,i),B.b.l(f.e.b,j,h))}g.bj()
if(!g.y){s=g.a
if(s!=null){p=f.e
p===$&&A.f()
s.bx(t.a,t.b,!(f.r>0),f.a.b.a*1.2,p.a,p.b)}}},
gaw(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7=this,a8=a7.a
if(a8==null)a8=null
else{t=a8.a
t===$&&A.f()
s=a8.b
s===$&&A.f()
r=a8.Q
q=a8.ga0()
p=a8.ac(a8.Q)
if(!t)o=0
else if(a8.gZ())o=1
else{o=a8.z
n=a8.cx===0
m=n?0:a8.at
if(n){n=a8.x
n===$&&A.f()}else{n=a8.w
n===$&&A.f()}n=B.b.l((o-m)/n,0,1)
o=n}n=a8.gZ()
m=a8.cx
l=m===0?-1:(a8.z-a8.at)*1000
k=a8.gZ()?(a8.z-a8.as)*1000:-1
a8=A.H(["enabled",t,"speedBarEnabled",s,"effectiveSec",r,"speed",q,"targetSpeed",p,"charge",o,"ready",n,"presses",m,"pressAgeMs",l,"readyAgeMs",k,"beforeSpeed",a8.ch,"afterSpeed",a8.CW],u.N,u.z)}t=a7.x
s=a7.y
r=B.b.ao(a7.w)
q=a7.c
q===$&&A.f()
p=B.b.bA(Math.max(0,q.y/Math.max(0.000001,q.a.b.a*1.2*0.1)))
o=q.z
n=a7.d
n===$&&A.f()
m=a7.ga6()
l=q.aQ(a7.w)
k=a7.ax
j=a7.e
j===$&&A.f()
if(j){j=a7.b
j===$&&A.f()
j=j.d.e}else j=!1
i=q.r
h=q.e
h===$&&A.f()
g=u.N
f=u.i
h=A.H(["x",h.a,"y",h.b,"size",q.a.b.a*1.2,"visualScale",q.gbI(),"jumpLift",q.gaR()],g,f)
e=u.O
d=A.m([],e)
for(c=q.f,b=c.length,a=0;a<c.length;c.length===b||(0,A.S)(c),++a){a0=c[a]
a1=a0.a
a2=a0.CW
a3=a7.a
a3=a3==null?a0.ay+a0.ch*(a7.w/1000):a3.ga0()*(q.a.b.a*1.2)*0.1
d.push(A.H(["x",a1.a,"y",a1.b,"w",a0.y,"h",a0.z,"angle",a2,"speed",a3],g,f))}c=a7.as
b=a7.at
a1=a7.z
a2=a7.Q
a3=q.gbo()
e=A.m([],e)
for(q=q.Q,a4=q.length,a=0;a<q.length;q.length===a4||(0,A.S)(q),++a){a5=q[a]
a6=a5.a
e.push(A.H(["x",a6.a,"y",a6.b,"age",a5.b],g,f))}return A.H(["brake",a8,"playing",t,"dead",s,"timeMs",r,"runDistance",p,"riskCount",o,"helmet",n,"invulnerable",m,"jumpCooldownMs",l,"jumpCount",k,"jumpEnabled",j,"jumpRemainingMs",i*1000,"player",h,"enemies",d,"wallBounces",c,"enemyBounces",b,"againstWall",a1,"impactOrigin",a2,"startled",a3,"nearMissFx",e],g,u.z)}}
A.aK.prototype={}
A.ac.prototype={}
A.aj.prototype={
gU(){var t=this.a
return new A.c(t.a+this.y*0.5,t.b+this.z*0.5)},
aZ(a){this.a=new A.c(a.a-this.y*0.5,a.b-this.z*0.5)},
gS(){var t=this.CW*3.141592653589793/180
return new A.c(Math.cos(t),Math.sin(t))},
gT(){var t=this.CW*3.141592653589793/180
return new A.c(-Math.sin(t),Math.cos(t))},
gan(){var t=this,s=t.y*0.5,r=t.z*0.5,q=new A.c9(t.gU(),t.gS(),t.gT()),p=-s,o=-r
return A.m([q.$2(p,o),q.$2(s,o),q.$2(s,r),q.$2(p,r)],u.M)},
gA(){var t,s,r,q,p=this.gan(),o=B.a.gJ(p).a,n=B.a.gJ(p).a,m=B.a.gJ(p).b,l=B.a.gJ(p).b
for(t=0;t<4;++t){s=p[t]
r=s.a
if(r<o)o=r
if(r>n)n=r
q=s.b
if(q<m)m=q
if(q>l)l=q}return new A.w(o,m,n,l)},
a7(a){var t=this,s=t.gU(),r=t.gS(),q=t.gT(),p=a.a,o=a.b,n=s.a*p+s.b*o,m=t.y*0.5*Math.abs(p*r.a+o*r.b)+t.z*0.5*Math.abs(p*q.a+o*q.b)
return new A.bh(n-m,n+m)},
ad(a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
for(t=[B.h,B.i,this.gS(),this.gT()],s=a1.a,r=a1.c,q=(s+r)/2,p=a1.b,o=a1.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,o=a2.a,r=a2.b,m=0,l=1,k=0;k<4;++k){j=t[k]
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
aT(a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[B.h,B.i,b.gS(),b.gT()],a0=a3.gU(),a1=(a3.c-a3.a)*0.5,a2=(a3.d-a3.b)*0.5
for(t=a0.a,s=a0.b,r=b.y*0.5,q=b.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.c(l,k)
g=b.a7(h)
f=t*l+s*k
e=a1*Math.abs(l)+a2*Math.abs(k)
d=Math.min(g.b,f+e)-Math.max(g.a,f-e)
if(d<=0)return null
if(d<p){c=b.a
o=(c.a+r-t)*l+(c.b+q-s)*k>=0?h:new A.c(-l,-k)
p=d}}if(o==null)return null
return o.a_(0,p+0.5)},
bt(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[b.gS(),b.gT(),a0.gS(),a0.gT()]
for(t=b.y*0.5,s=a0.y*0.5,r=b.z*0.5,q=a0.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.c(l,k)
g=b.a7(h)
f=a0.a7(h)
e=Math.min(g.b,f.b)-Math.max(g.a,f.a)
if(e<=0)return null
if(e<p){d=b.a
c=a0.a
o=(d.a+t-(c.a+s))*l+(d.b+r-(c.b+q))*k>=0?h:new A.c(-l,-k)
p=e}}if(o==null)return null
return o.a_(0,p+0.5)},
P(a){var t,s,r,q,p,o=a.a,n=a.b,m=o*o+n*n
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
this.b=new A.c(n-p*s,o-p*r)}}
A.c9.prototype={
$2(a,b){var t=this.a,s=this.b,r=this.c
return new A.c(t.a+s.a*a+r.a*b,t.b+s.b*a+r.b*b)},
$S:14}
A.cj.prototype={
aQ(a){var t=this.x
return Math.max(0,t-a)},
gbo(){var t,s,r=this.e
r===$&&A.f()
t=r.a
r=r.b
s=this.a.b.a*1.2
return B.a.al(this.f,new A.cp(new A.w(t,r,t+s,r+s)))},
gaR(){var t=this.r
if(!(t>0))return 0
return Math.sin(3.141592653589793*B.b.l(1-t/Math.max(0.05,this.a.d.f),0,1))},
gbI(){if(!(this.r>0))return 1
return 1+(B.b.l(this.a.d.w,1.05,1.8)-1)*this.gaR()},
bH(a){var t,s,r=this
if(!isFinite(a)||!r.a.d.e||r.r>0||r.aQ(a)>0)return!1
t=r.a.d
r.r=Math.max(0.12,t.f)
s=t.r
t=isFinite(s)?s:2
r.x=a+Math.max(0,t)*1000
r.at.F(0)
r.as.F(0)
r.ai()
return!0},
bC(a){var t=this,s=t.r
if(s<=0)return
s=Math.max(0,s-a)
t.r=s
if(s>0)t.ai()
else t.at.F(0)},
bf(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=a9.a,b1=b0.a,b2=A.dV(b1.b,!0,u.i),b3=A.B(b2),b4=b3.i("am<1>"),b5=A.df(new A.am(b2,b3.i("r(1)").a(new A.co()),b4),b4.i("e.E"))
if(b5.length===0)B.a.L(b5,B.o)
t=b5.length
s=Math.max(t,4)
b2=u.S
b3=J.db(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.ab(r,4)
b4=a9.c
B.a.av(b3,b4)
q=A.e2(b3,0,A.es(t,"count",b2),A.B(b3).c).aV(0)
b3=J.db(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.ab(r,4)
B.a.av(b3,b4)
p=A.e2(b3,0,A.es(t,"count",b2),A.B(b3).c).aV(0)
o=A.m([],u.u)
for(b2=b1.e,b3=b1.f,n=b1.r,m=b1.w,l=b1.y,b0=b0.b.a*1.2,b0*=b0,k=b1.a,j=b1.c,b1=b1.d,r=0;r<t;++r){if(!(r<b5.length))return A.j(b5,r)
i=b5[r]
if(!(r<q.length))return A.j(q,r)
h=q[r]
if(!(r<p.length))return A.j(p,r)
g=p[r]
f=Math.max(1,b0)*B.b.l(k,0.2,20)
e=B.b.l(i,0.05,50)
d=Math.sqrt(f/e)
c=Math.sqrt(f*e)
b=a9.bc(g,d,c)
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
a8=new A.aj(b,new A.c(h*a5,g*a5),c,d,a5,a3+i*(a4-a3),a7,l)
if(a6)a9.aH(a8)
a8.c=a8.a
a8.d=a8.b
a8.w=b4.E()*3.141592653589793*2
a8.x=b4.E()*3.141592653589793*2
a8.f=1.15+b4.E()*0.85
a8.r=0.85+b4.E()*0.85
B.a.m(o,a8)}return o},
bB(a){var t,s,r,q,p,o,n,m,l,k,j,i=this,h=B.b.l(a,0,0.05),g=i.a,f=g.d
if(!f.c)return i.bh(h)
t=B.b.l(f.b,0.05,1)
for(f=i.f,s=f.length,r=0,q=0;q<f.length;f.length===s||(0,A.S)(f),++q){p=f[q]
o=B.b.l(p.ay*t,0,2000)
n=p.b
m=n.a
n=n.b
l=Math.sqrt(m*m+n*n)
if(l<0.000001)k=B.p
else{n=p.b
k=new A.c(n.a/l,n.b/l)}n=k.a*o
m=k.b*o
p.b=new A.c(n,m)
j=p.a
p.a=new A.c(j.a+n*h,j.b+m*h)
n=p.cx
if(Math.abs(n)>0.01)p.CW=p.CW+n*h
if(i.a3(p))++r}return new A.aK(r,g.a.x?i.aJ():0)},
b_(){var t,s,r,q,p,o,n,m
for(t=this.f,s=t.length,r=0;r<t.length;t.length===s||(0,A.S)(t),++r){q=t[r]
p=q.b
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.b
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
m=new A.c(o/n,p/n)}else{p=q.d
p===$&&A.f()
o=p.a
p=p.b
if(Math.sqrt(o*o+p*p)>0.000001){p=q.d
o=p.a
p=p.b
n=Math.sqrt(o*o+p*p)
n=new A.c(o/n,p/n)
m=n}else m=B.h}p=q.ay
q.b=new A.c(m.a*p,m.b*p)}},
gb0(){var t,s,r,q,p,o,n,m=A.m([],u.q)
for(t=this.f,s=t.length,r=u.n,q=0;q<t.length;t.length===s||(0,A.S)(t),++q){p=t[q]
o=p.a
n=p.b
m.push(A.m([o.a,o.b,n.a,n.b,p.CW],r))}return m},
bz(a){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f=u.j
if(!f.b(a)||J.N(a)!==this.f.length)throw A.b(B.D)
for(t=this.f,s=J.a_(a),r=this.b,q=r.a+0.0001,r=r.b+0.0001,p=0;p<t.length;++p){o=s.h(a,p)
if(f.b(o)){n=J.aH(o)
n=n.gk(o)!==5||n.al(o,new A.cq())}else n=!0
if(n)throw A.b(B.C)
if(!(p<t.length))return A.j(t,p)
m=t[p]
n=J.a_(o)
l=A.u(n.h(o,0))
k=A.u(n.h(o,1))
j=A.u(n.h(o,2))
i=A.u(n.h(o,3))
h=A.u(n.h(o,4))
n=m.ay
if(Math.abs(Math.sqrt(j*j+i*i)-n)>Math.max(0.0001,n*0.000001)||Math.abs(h)>1e9)throw A.b(B.G)
m.a=new A.c(l,k)
m.b=new A.c(j,i)
m.CW=h
g=m.gA()
if(g.a<-0.0001||g.b<-0.0001||g.c>q||g.d>r)throw A.b(B.F)}},
bh(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.f,s=t.length,r=0;r<t.length;t.length===s||(0,A.S)(t),++r){q=t[r]
q.e+=a
p=Math.min(q.y,q.z)*0.5
o=q.d
o===$&&A.f()
n=o.a
o=o.b
m=Math.sqrt(n*n+o*o)
if(m<0.000001)l=B.h
else{o=q.d
l=new A.c(o.a/m,o.b/m)}o=l.b
n=l.a
k=Math.cos(q.e*q.f+q.w)*p
j=Math.sin(q.e*q.r+q.x)*p*0.35
i=n*k+-o*j
n=o*k+n*j
h=new A.c(i,n)
o=i*i+n*n
if(Math.sqrt(o)>p&&Math.sqrt(o)>0.000001){o=p/Math.sqrt(o)
h=new A.c(i*o,n*o)}o=q.c
o===$&&A.f()
q.a=new A.c(o.a+h.a,o.b+h.b)
o=q.cx
if(Math.abs(o)>0.01)q.CW=q.CW+o*a*0.35
this.aH(q)}return B.t},
aH(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
for(t=this.d,s=this.b,r=s.a-t,q=s.b-t,p=0;p<3;++p){o=a.gan()
s=A.B(o)
n=s.i("d(1)")
s=s.i("P<1,d>")
m=new A.P(o,n.a(new A.ck()),s).a8(0,B.k)
l=new A.P(o,n.a(new A.cl()),s).a8(0,B.l)
k=new A.P(o,n.a(new A.cm()),s).a8(0,B.k)
j=new A.P(o,n.a(new A.cn()),s).a8(0,B.l)
if(m<t)i=t-m
else i=l>r?r-l:0
if(k<t)h=t-k
else h=j>q?q-j:0
if(i===0&&h===0)break
s=a.a
a.a=new A.c(s.a+i,s.b+h)}},
bE(a7,a8,a9,b0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=this,a4=B.b.l(a7,0,0.05),a5=B.c.l(1,0,2),a6=B.b.l(a8,0,3600)
for(t=a3.f,s=t.length,r=a3.a,q=r.b.a*1.2,p=b0==null,o=0,n=0;n<t.length;t.length===s||(0,A.S)(t),++n){m=t[n]
l=B.b.l((p?m.ay+m.ch*a6:b0)*a5,0,4000)
k=m.b
j=k.a
k=k.b
i=Math.sqrt(j*j+k*k)
if(i<0.000001)h=B.p
else{k=m.b
h=new A.c(k.a/i,k.b/i)}m.b=new A.c(h.a*l,h.b*l)
k=m.cx
j=Math.abs(k)
g=Math.max(1,B.b.bi(j*a4/5))
for(j=j>0.01,f=a4/g,k=k*a4/g,e=0;e<g;++e){d=m.b
c=d.a*f
d=d.b*f
if(j)m.CW+=k
if(a9&&!(a3.r>0)){b=a3.e
b===$&&A.f()
a=b.a
b=b.b
a0=m.ad(new A.w(a,b,a+q,b+q),new A.c(-c,-d))}else a0=null
b=m.a
a=a0==null
if(a)a1=1
else a1=a0===0?0:Math.min(1,a0+1e-7)
m.a=new A.c(b.a+c*a1,b.b+d*a1)
if(a3.a3(m))++o
if(!a)break}}a2=r.a.x?a3.aJ():0
a3.bD(a4)
return new A.aK(o,a2)},
bs(a,b){var t,s,r,q,p,o,n,m,l,k,j,i=this,h=a.a,g=!0
if(isFinite(h)){t=a.b
if(isFinite(t))h=h===0&&t===0
else h=g}else h=g
if(h)return
h=i.e
h===$&&A.f()
s=h.G(0,a)
g=i.a
if(!g.d.CW){t=i.d
r=i.b
q=g.b.a*1.2
s=new A.c(B.b.l(s.a,t,Math.max(t,r.a-t-q)),B.b.l(s.b,t,Math.max(t,r.b-t-q)))}p=s.a1(0,h)
t=i.e
r=t.a
t=t.b
g=g.b.a*1.2
o=new A.w(r,t,r+g,t+g)
n=1
if(b&&!(i.r>0))for(g=i.f,t=g.length,m=0;m<g.length;g.length===t||(0,A.S)(g),++m){l=g[m].ad(o,p)
if(l!=null){r=l===0?0:l+1e-7
n=Math.min(n,r)}}g=h.G(0,p.a_(0,Math.min(1,n)))
i.e=g
k=g.a1(0,h).gbm()
if(k===0)return
i.y+=k
if(i.r>0){for(h=i.f,j=0;j<h.length;++j)if(h[j].ad(o,p)!=null)i.aC(j)}else i.aD()},
bD(a){var t=this,s=t.Q,r=A.B(s).i("r(1)").a(new A.cr(a))
s.$flags&1&&A.aJ(s,16)
B.a.bd(s,r,!0)
if(t.r>0)t.ai()
else t.aD()},
ai(){var t,s,r,q,p,o=this
if(!(o.r>0))return
t=o.e
t===$&&A.f()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.w(s,t,s+r,t+r)
for(t=o.f,s=o.at,p=0;p<t.length;++p){if(s.V(0,p))continue
if(!(p<t.length))return A.j(t,p)
if(!q.Y(t[p].gA()))continue
o.aC(p)}},
aC(a){var t,s,r,q=this
if(!q.at.m(0,a))return;++q.z
t=q.e
t===$&&A.f()
s=q.a.b.a*1.2/2
r=t.G(0,new A.c(s,s))
s=q.f
if(!(a<s.length))return A.j(s,a)
B.a.m(q.Q,new A.ac(r.G(0,s[a].gA().gU()).au(0,2)))},
aD(){var t,s,r,q,p,o,n,m,l,k,j,i=this
if(i.r>0)return
t=i.e
t===$&&A.f()
s=t.a
t=t.b
r=i.a.b.a*1.2
q=s+r
r=t+r
p=new A.w(s,t,q,r)
o=A.de(u.S)
for(n=i.f,m=i.as,q=(s+q)/2,r=(t+r)/2,t=i.Q,l=0;l<n.length;++l){k=A.dM(p,n[l].gA())
if(k<=0)continue
if(k<=14){m.m(0,l)
o.m(0,l)}else if(k>=22&&m.V(0,l)){++i.z
if(!(l<n.length))return A.j(n,l)
s=n[l].gA()
if(!(l<n.length))return A.j(n,l)
j=n[l].gA()
B.a.m(t,new A.ac(new A.c((q+(s.a+s.c)/2)/2,(r+(j.b+j.d)/2)/2)))}else if(m.V(0,l))o.m(0,l)}m.F(0)
m.L(0,o)},
aU(){var t,s,r,q,p=this,o=p.e
o===$&&A.f()
t=o.a
s=p.d
r=!0
if(!(t<=s)){o=o.b
if(!(o<=s)){r=p.a.b.a*1.2
q=p.b
o=t+r>=q.a-s||o+r>=q.b-s}else o=r}else o=r
return o},
bv(){var t,s,r,q,p,o=this
if(o.r>0)return!1
t=o.e
t===$&&A.f()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.w(s,t,s+r,t+r)
for(t=o.f,s=t.length,p=0;p<t.length;t.length===s||(0,A.S)(t),++p)if(t[p].aT(q)!=null)return!0
return!1},
by(){var t,s,r,q,p,o,n,m=this.e
m===$&&A.f()
t=m.a
m=m.b
s=this.a.b.a*1.2
r=new A.w(t,m,t+s,m+s)
for(m=this.f,t=m.length,q=0,p=0;p<m.length;m.length===t||(0,A.S)(m),++p){o=m[p]
n=o.aT(r)
if(n==null)continue
s=o.a
o.a=new A.c(s.a+n.a,s.b+n.b)
o.P(n);++q}return q},
bc(a0,a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=this,d=Math.max(8,e.d+2),c=e.b,b=c.a,a=b/2
c=c.b
t=c/2
s=A.cL()
r=A.cL()
q=A.cL()
p=A.cL()
switch(B.c.ab(a0,4)){case 0:s.b=d
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
p.b=c-a1-d}o=r.R()
n=s.R()
if(typeof o!=="number")return o.aa()
if(typeof n!=="number")return A.d_(n)
if(o<n){s.b=d
r.b=Math.max(d,b-a2-d)}o=p.R()
n=q.R()
if(typeof o!=="number")return o.aa()
if(typeof n!=="number")return A.d_(n)
if(o<n){q.b=d
p.b=Math.max(d,c-a1-d)}o=e.e
o===$&&A.f()
n=o.a
o=o.b
m=e.a.b.a*1.2
l=m*0.6
k=new A.w(n-l,o-l,n+m+l,o+m+l)
for(o=e.c,j=0;j<12;++j){n=s.b
if(n===s)A.T(A.aV(""))
m=o.E()
l=r.b
if(l===r)A.T(A.aV(""))
i=s.b
if(i===s)A.T(A.aV(""))
if(typeof l!=="number")return l.a1()
if(typeof i!=="number")return A.d_(i)
l=Math.max(1,l-i)
if(typeof n!=="number")return n.G()
h=n+m*l
n=q.b
if(n===q)A.T(A.aV(""))
m=o.E()
l=p.b
if(l===p)A.T(A.aV(""))
i=q.b
if(i===q)A.T(A.aV(""))
if(typeof l!=="number")return l.a1()
if(typeof i!=="number")return A.d_(i)
l=Math.max(1,l-i)
if(typeof n!=="number")return n.G()
g=n+m*l
f=new A.c(h,g)
if(!new A.w(h,g,h+a2,g+a1).Y(k))return f}return new A.c(J.dC(s.R(),d,b-a2-d),J.dC(q.R(),d,c-a1-d))},
a3(a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=a2.gU()
for(t=this.d,s=this.b,r=s.a-t,q=s.b-t,s=a2.y*0.5,p=a2.z*0.5,o=!1,n=0;n<3;++n){m=a1.a
l=a1.b
a2.a=new A.c(m-s,l-p)
k=a2.gan()
j=B.a.gJ(k).a
i=B.a.gJ(k).a
h=B.a.gJ(k).b
g=B.a.gJ(k).b
for(f=0;f<4;++f){e=k[f]
d=e.a
if(d<j)j=d
if(d>i)i=d
c=e.b
if(c<h)h=c
if(c>g)g=c}b=!0
if(j<t){a=t-j
a2.P(B.h)
o=b}else if(i>r){a=r-i
a2.P(B.P)
o=b}else a=0
if(h<t){a0=t-h
a2.P(B.i)
o=b}else if(g>q){a0=q-g
a2.P(B.O)
o=b}else a0=0
if(a===0&&a0===0)break
a1=new A.c(m+a,l+a0)}a2.aZ(a1)
return o},
aJ(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f
for(t=this.f,s=0,r=0;r<t.length;r=q)for(q=r+1,p=q;o=t.length,p<o;++p){if(!(r<o))return A.j(t,r)
n=t[r]
m=t[p]
if(!n.gA().Y(m.gA()))continue
l=n.bt(m)
if(l==null)continue;++s
o=l.a
k=o*0.5
j=l.b
i=j*0.5
h=n.a
g=n.y*0.5
f=n.z*0.5
n.a=new A.c(h.a+g+k-g,h.b+f+i-f)
f=m.a
h=m.y*0.5
g=m.z*0.5
m.a=new A.c(f.a+h-k-h,f.b+g-i-g)
n.P(l)
m.P(new A.c(-o,-j))
this.a3(n)
this.a3(m)}return s}}
A.cp.prototype={
$1(a){return A.dM(this.a,u.W.a(a).gA())<=14},
$S:15}
A.co.prototype={
$1(a){A.Z(a)
return isFinite(a)&&a>0.05&&a<50},
$S:4}
A.cq.prototype={
$1(a){return typeof a!="number"||!isFinite(a)},
$S:16}
A.ck.prototype={
$1(a){return u.o.a(a).a},
$S:0}
A.cl.prototype={
$1(a){return u.o.a(a).a},
$S:0}
A.cm.prototype={
$1(a){return u.o.a(a).b},
$S:0}
A.cn.prototype={
$1(a){return u.o.a(a).b},
$S:0}
A.cr.prototype={
$1(a){return!((u.Y.a(a).b+=this.a)<0.42)},
$S:17};(function aliases(){var t=J.ab.prototype
t.b1=t.j})();(function installTearOffs(){var t=hunkHelpers._static_0,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(A,"ha","fh",1)
s(A,"hj","fR",2)
r(A,"hA",2,null,["$1$2","$2"],["ey",function(a,b){return A.ey(a,b,u.H)}],5,0)
r(A,"hz",2,null,["$1$2","$2"],["ex",function(a,b){return A.ex(a,b,u.H)}],5,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.o,null)
r(A.o,[A.dc,J.bA,A.b4,J.ai,A.p,A.i,A.cF,A.e,A.a4,A.bb,A.E,A.b9,A.ap,A.aM,A.D,A.cI,A.cB,A.K,A.cy,A.aW,A.cK,A.V,A.c_,A.cR,A.az,A.c2,A.an,A.bs,A.bu,A.cO,A.b5,A.a1,A.b0,A.cH,A.aA,A.cs,A.bv,A.cC,A.ce,A.cf,A.c6,A.cA,A.ca,A.c,A.cG,A.w,A.bS,A.cd,A.c7,A.aK,A.ac,A.aj,A.cj])
r(J.bA,[J.bC,J.aQ,J.aS,J.aR,J.aT,J.av,J.aw])
r(J.aS,[J.ab,J.l,A.ax,A.aZ])
r(J.ab,[J.bP,J.aB,J.a9])
s(J.bB,A.b4)
s(J.ct,J.l)
r(J.av,[J.aP,J.bD])
r(A.p,[A.aa,A.b8,A.bE,A.bY,A.bT,A.bZ,A.aU,A.bo,A.a0,A.ba,A.bX,A.b6,A.bt])
s(A.aC,A.i)
s(A.aL,A.aC)
r(A.e,[A.aO,A.am])
r(A.aO,[A.F,A.al])
r(A.F,[A.b7,A.P,A.c1])
s(A.aD,A.ap)
s(A.bh,A.aD)
s(A.aN,A.aM)
r(A.D,[A.bz,A.bq,A.br,A.bW,A.d0,A.d2,A.c8,A.cc,A.cb,A.ci,A.cg,A.d4,A.cp,A.co,A.cq,A.ck,A.cl,A.cm,A.cn,A.cr])
s(A.ak,A.bz)
s(A.cD,A.bq)
s(A.b1,A.b8)
r(A.bW,[A.bV,A.au])
r(A.K,[A.a3,A.c0])
r(A.br,[A.cu,A.d1,A.cz,A.cP,A.ch,A.c9])
r(A.aZ,[A.bG,A.ay])
r(A.ay,[A.bd,A.bf])
s(A.be,A.bd)
s(A.aX,A.be)
s(A.bg,A.bf)
s(A.aY,A.bg)
r(A.aX,[A.bH,A.bI])
r(A.aY,[A.bJ,A.bK,A.bL,A.bM,A.bN,A.b_,A.bO])
s(A.aE,A.bZ)
s(A.bi,A.az)
s(A.bc,A.bi)
s(A.bF,A.aU)
s(A.cv,A.bs)
r(A.bu,[A.cx,A.cw])
s(A.cN,A.cO)
r(A.a0,[A.b2,A.by])
t(A.aC,A.b9)
t(A.bd,A.i)
t(A.be,A.E)
t(A.bf,A.i)
t(A.bg,A.E)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",d:"double",W:"num",n:"String",r:"bool",b0:"Null",h:"List",o:"Object",Y:"Map",v:"JSObject"},mangledNames:{},types:["d(c)","a()","@(@)","~(o?,o?)","r(d)","0^(0^,0^)<W>","@(@,n)","@(n)","d(@)","d(n,d,d,d)","r(n)","r(w)","r(d,d)","n(n)","c(d,d)","r(aj)","r(@)","r(ac)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.bh&&a.b(c.a)&&b.b(c.b)}}
A.fI(v.typeUniverse,JSON.parse('{"a9":"ab","bP":"ab","aB":"ab","hI":"ax","bC":{"r":[],"k":[]},"aQ":{"k":[]},"aS":{"v":[]},"ab":{"v":[]},"l":{"h":["1"],"v":[],"e":["1"]},"bB":{"b4":[]},"ct":{"l":["1"],"h":["1"],"v":[],"e":["1"]},"ai":{"a8":["1"]},"av":{"d":[],"W":[]},"aP":{"d":[],"a":[],"W":[],"k":[]},"bD":{"d":[],"W":[],"k":[]},"aw":{"n":[],"k":[]},"aa":{"p":[]},"aL":{"i":["a"],"b9":["a"],"h":["a"],"e":["a"],"i.E":"a"},"aO":{"e":["1"]},"F":{"e":["1"]},"b7":{"F":["1"],"e":["1"],"e.E":"1","F.E":"1"},"a4":{"a8":["1"]},"P":{"F":["2"],"e":["2"],"e.E":"2","F.E":"2"},"am":{"e":["1"],"e.E":"1"},"bb":{"a8":["1"]},"aC":{"i":["1"],"b9":["1"],"h":["1"],"e":["1"]},"bh":{"aD":[],"ap":[]},"aM":{"Y":["1","2"]},"aN":{"aM":["1","2"],"Y":["1","2"]},"bz":{"D":[],"a2":[]},"ak":{"D":[],"a2":[]},"b1":{"p":[]},"bE":{"p":[]},"bY":{"p":[]},"D":{"a2":[]},"bq":{"D":[],"a2":[]},"br":{"D":[],"a2":[]},"bW":{"D":[],"a2":[]},"bV":{"D":[],"a2":[]},"au":{"D":[],"a2":[]},"bT":{"p":[]},"a3":{"K":["1","2"],"dT":["1","2"],"Y":["1","2"],"K.K":"1","K.V":"2"},"al":{"e":["1"],"e.E":"1"},"aW":{"a8":["1"]},"aD":{"ap":[]},"ax":{"v":[],"k":[]},"aZ":{"v":[]},"bG":{"v":[],"k":[]},"ay":{"J":["1"],"v":[]},"aX":{"i":["d"],"h":["d"],"J":["d"],"v":[],"e":["d"],"E":["d"]},"aY":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"]},"bH":{"i":["d"],"h":["d"],"J":["d"],"v":[],"e":["d"],"E":["d"],"k":[],"i.E":"d"},"bI":{"i":["d"],"h":["d"],"J":["d"],"v":[],"e":["d"],"E":["d"],"k":[],"i.E":"d"},"bJ":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"],"k":[],"i.E":"a"},"bK":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"],"k":[],"i.E":"a"},"bL":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"],"k":[],"i.E":"a"},"bM":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"],"k":[],"i.E":"a"},"bN":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"],"k":[],"i.E":"a"},"b_":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"],"k":[],"i.E":"a"},"bO":{"i":["a"],"h":["a"],"J":["a"],"v":[],"e":["a"],"E":["a"],"k":[],"i.E":"a"},"bZ":{"p":[]},"aE":{"p":[]},"bc":{"az":["1"],"dk":["1"],"e":["1"]},"an":{"a8":["1"]},"i":{"h":["1"],"e":["1"]},"K":{"Y":["1","2"]},"az":{"dk":["1"],"e":["1"]},"bi":{"az":["1"],"dk":["1"],"e":["1"]},"c0":{"K":["n","@"],"Y":["n","@"],"K.K":"n","K.V":"@"},"c1":{"F":["n"],"e":["n"],"e.E":"n","F.E":"n"},"aU":{"p":[]},"bF":{"p":[]},"d":{"W":[]},"a":{"W":[]},"h":{"e":["1"]},"bo":{"p":[]},"b8":{"p":[]},"a0":{"p":[]},"b2":{"p":[]},"by":{"p":[]},"ba":{"p":[]},"bX":{"p":[]},"b6":{"p":[]},"bt":{"p":[]},"b5":{"p":[]},"aA":{"fn":[]},"bS":{"fj":[]},"f9":{"h":["a"],"e":["a"]},"fr":{"h":["a"],"e":["a"]},"fq":{"h":["a"],"e":["a"]},"f7":{"h":["a"],"e":["a"]},"fo":{"h":["a"],"e":["a"]},"f8":{"h":["a"],"e":["a"]},"fp":{"h":["a"],"e":["a"]},"f4":{"h":["d"],"e":["d"]},"f5":{"h":["d"],"e":["d"]}}'))
A.fH(v.typeUniverse,JSON.parse('{"aO":1,"aC":1,"ay":1,"bi":1,"bs":2,"bu":2}'))
var u=(function rtii(){var t=A.c4
return{V:t("aL"),W:t("aj"),C:t("p"),Z:t("a2"),t:t("ak<d>"),R:t("e<@>"),u:t("l<aj>"),q:t("l<h<d>>"),U:t("l<h<W>>"),O:t("l<Y<n,d>>"),l:t("l<ac>"),M:t("l<c>"),s:t("l<n>"),n:t("l<d>"),b:t("l<@>"),a:t("l<W>"),T:t("aQ"),m:t("v"),g:t("a9"),p:t("J<@>"),j:t("h<@>"),c:t("Y<n,@>"),f:t("Y<@,@>"),Y:t("ac"),P:t("b0"),K:t("o"),o:t("c"),J:t("hJ"),F:t("+()"),N:t("n"),k:t("k"),A:t("aB"),y:t("r"),i:t("d"),z:t("@"),S:t("a"),Q:t("dK<b0>?"),B:t("v?"),_:t("h<@>?"),X:t("o?"),v:t("n?"),L:t("c2?"),d:t("r?"),I:t("d?"),w:t("a?"),x:t("W?"),H:t("W"),D:t("~(n,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.H=J.bA.prototype
B.a=J.l.prototype
B.c=J.aP.prototype
B.b=J.av.prototype
B.e=J.aw.prototype
B.I=J.a9.prototype
B.J=J.aS.prototype
B.q=J.bP.prototype
B.j=J.aB.prototype
B.t=new A.aK(0,0)
B.l=new A.ak(A.hz(),u.t)
B.k=new A.ak(A.hA(),u.t)
B.u=new A.c6()
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

B.d=new A.cv()
B.f=new A.cF()
B.B=new A.a1("Invalid mobile enemy variation")
B.C=new A.a1("start pose values")
B.D=new A.a1("start pose count")
B.E=new A.a1("Invalid mobile enemy pace")
B.F=new A.a1("start pose bounds")
B.G=new A.a1("start pose speed")
B.K=new A.cw(null)
B.L=new A.cx(null)
B.o=t([1,0.25,0.5,3],u.n)
B.N={}
B.M=new A.aN(B.N,[],A.c4("aN<@,@>"))
B.i=new A.c(0,1)
B.O=new A.c(0,-1)
B.h=new A.c(1,0)
B.p=new A.c(1,1)
B.P=new A.c(-1,0)
B.r=new A.cG(380,380)
B.Q=A.X("hE")
B.R=A.X("hF")
B.S=A.X("f4")
B.T=A.X("f5")
B.U=A.X("f7")
B.V=A.X("f8")
B.W=A.X("f9")
B.X=A.X("o")
B.Y=A.X("fo")
B.Z=A.X("fp")
B.a_=A.X("fq")
B.a0=A.X("fr")})();(function staticFields(){$.cM=null
$.L=A.m([],A.c4("l<o>"))
$.dY=null
$.cE=0
$.e_=A.ha()
$.dG=null
$.dF=null
$.ev=null
$.eq=null
$.eB=null
$.cZ=null
$.d3=null
$.dx=null
$.cQ=A.m([],A.c4("l<h<o>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hH","eE",()=>A.eu("_$dart_dartClosure"))
t($,"hG","dA",()=>A.eu("_$dart_dartClosure_dartJSInterop"))
t($,"hW","eQ",()=>A.m([new J.bB()],A.c4("l<b4>")))
t($,"hL","eG",()=>A.a5(A.cJ({
toString:function(){return"$receiver$"}})))
t($,"hM","eH",()=>A.a5(A.cJ({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hN","eI",()=>A.a5(A.cJ(null)))
t($,"hO","eJ",()=>A.a5(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hR","eM",()=>A.a5(A.cJ(void 0)))
t($,"hS","eN",()=>A.a5(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hQ","eL",()=>A.a5(A.e3(null)))
t($,"hP","eK",()=>A.a5(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"hU","eP",()=>A.a5(A.e3(void 0)))
t($,"hT","eO",()=>A.a5(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"hV","d6",()=>A.ez(B.X))
t($,"hK","eF",()=>{A.fi()
return $.cE})})();(function nativeSupport(){!function(){var t=function(a){var n={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.ax,SharedArrayBuffer:A.ax,ArrayBufferView:A.aZ,DataView:A.bG,Float32Array:A.bH,Float64Array:A.bI,Int16Array:A.bJ,Int32Array:A.bK,Int8Array:A.bL,Uint16Array:A.bM,Uint32Array:A.bN,Uint8ClampedArray:A.b_,CanvasPixelArray:A.b_,Uint8Array:A.bO})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.ay.$nativeSuperclassTag="ArrayBufferView"
A.bd.$nativeSuperclassTag="ArrayBufferView"
A.be.$nativeSuperclassTag="ArrayBufferView"
A.aX.$nativeSuperclassTag="ArrayBufferView"
A.bf.$nativeSuperclassTag="ArrayBufferView"
A.bg.$nativeSuperclassTag="ArrayBufferView"
A.aY.$nativeSuperclassTag="ArrayBufferView"})()
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
var t=A.hx
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
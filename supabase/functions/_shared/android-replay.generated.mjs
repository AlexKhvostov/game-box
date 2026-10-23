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
if(a[b]!==t){A.hk(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.w(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.da(b)
return new t(c,this)}:function(){if(t===null)t=A.da(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.da(a).prototype
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
df(a,b,c,d){return{i:a,p:b,e:c,x:d}},
db(a){var t,s,r,q,p,o=a[v.dispatchPropertyName]
if(o==null)if($.dd==null){A.h8()
o=a[v.dispatchPropertyName]}if(o!=null){t=o.p
if(!1===t)return o.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return o.i
if(o.e===s)throw A.b(A.dK("Return interceptor for "+A.o(t(a,o))))}r=a.constructor
if(r==null)q=null
else{p=$.cw
if(p==null)p=$.cw=v.getIsolateTag("_$dart_js")
q=r[p]}if(q!=null)return q
q=A.hd(a)
if(q!=null)return q
if(typeof a=="function")return B.Q
t=Object.getPrototypeOf(a)
if(t==null)return B.q
if(t===Object.prototype)return B.q
if(typeof r=="function"){p=$.cw
if(p==null)p=$.cw=v.getIsolateTag("_$dart_js")
Object.defineProperty(r,p,{value:B.i,enumerable:false,writable:true,configurable:true})
return B.i}return B.i},
ds(a,b){if(a<0||a>4294967295)throw A.b(A.aT(a,0,4294967295,"length",null))
return J.eS(new Array(a),b)},
dt(a,b){if(a<0)throw A.b(A.bZ("Length must be a non-negative integer: "+a))
return A.w(new Array(a),b.i("n<0>"))},
cV(a,b){if(a<0)throw A.b(A.bZ("Length must be a non-negative integer: "+a))
return A.w(new Array(a),b.i("n<0>"))},
eS(a,b){var t=A.w(a,b.i("n<0>"))
t.$flags=1
return t},
du(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
eT(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.du(s))break;++b}return b},
eU(a,b){var t,s,r
for(t=a.length;b>0;b=s){s=b-1
if(!(s<t))return A.i(a,s)
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.du(r))break}return b},
ai(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aD.prototype
return J.bt.prototype}if(typeof a=="string")return J.ao.prototype
if(a==null)return J.aE.prototype
if(typeof a=="boolean")return J.bs.prototype
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a1.prototype
if(typeof a=="symbol")return J.aH.prototype
if(typeof a=="bigint")return J.aF.prototype
return a}if(a instanceof A.k)return a
return J.db(a)},
Y(a){if(typeof a=="string")return J.ao.prototype
if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a1.prototype
if(typeof a=="symbol")return J.aH.prototype
if(typeof a=="bigint")return J.aF.prototype
return a}if(a instanceof A.k)return a
return J.db(a)},
bY(a){if(a==null)return a
if(Array.isArray(a))return J.n.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a1.prototype
if(typeof a=="symbol")return J.aH.prototype
if(typeof a=="bigint")return J.aF.prototype
return a}if(a instanceof A.k)return a
return J.db(a)},
h4(a){if(typeof a=="number")return J.an.prototype
if(a==null)return a
if(!(a instanceof A.k))return J.at.prototype
return a},
al(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.ai(a).H(a,b)},
cR(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string"||A.hc(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.Y(a).h(a,b)},
ex(a,b,c){return J.bY(a).t(a,b,c)},
ey(a,b){return J.bY(a).I(a,b)},
dh(a,b,c){return J.h4(a).v(a,b,c)},
di(a,b){return J.bY(a).A(a,b)},
I(a){return J.ai(a).gq(a)},
ez(a){return J.Y(a).gah(a)},
cS(a){return J.bY(a).gu(a)},
a9(a){return J.Y(a).gk(a)},
eA(a){return J.ai(a).gn(a)},
eB(a,b,c){return J.bY(a).aD(a,b,c)},
bd(a){return J.ai(a).j(a)},
bq:function bq(){},
bs:function bs(){},
aE:function aE(){},
aG:function aG(){},
a2:function a2(){},
bG:function bG(){},
at:function at(){},
a1:function a1(){},
aF:function aF(){},
aH:function aH(){},
n:function n(a){this.$ti=a},
br:function br(){},
cd:function cd(a){this.$ti=a},
aa:function aa(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
an:function an(){},
aD:function aD(){},
bt:function bt(){},
ao:function ao(){}},A={cW:function cW(){},
eV(a){return new A.ac("Field '"+a+"' has not been initialized.")},
aJ(a){return new A.ac("Local '"+a+"' has not been initialized.")},
a4(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
d2(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
e8(a,b,c){return a},
de(a){var t,s
for(t=$.H.length,s=0;s<t;++s)if(a===$.H[s])return!0
return!1},
dI(a,b,c,d){A.d_(b,"start")
if(c!=null){A.d_(c,"end")
if(b>c)A.Q(A.aT(b,0,c,"start",null))}return new A.aW(a,b,c,d.i("aW<0>"))},
dr(){return new A.bL("No element")},
ac:function ac(a){this.a=a},
aB:function aB(a){this.a=a},
cp:function cp(){},
aC:function aC(){},
A:function A(){},
aW:function aW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
U:function U(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
J:function J(a,b,c){this.a=a
this.b=b
this.$ti=c},
b_:function b_(a,b,c){this.a=a
this.b=b
this.$ti=c},
b0:function b0(a,b,c){this.a=a
this.b=b
this.$ti=c},
z:function z(){},
aY:function aY(){},
au:function au(){},
ei(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
hc(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
o(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.bd(a)
return t},
bH(a){var t,s=$.dD
if(s==null)s=$.dD=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bI(a){var t,s,r,q
if(a instanceof A.k)return A.C(A.a8(a),null)
t=J.ai(a)
if(t===B.P||t===B.R||u.o.b(a)){s=B.l(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.C(A.a8(a),null)},
dE(a){var t,s,r
if(a==null||typeof a=="number"||A.d8(a))return J.bd(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.y)return a.j(0)
if(a instanceof A.ag)return a.aw(!0)
t=$.ew()
for(s=0;s<1;++s){r=t[s].bj(a)
if(r!=null)return r}return"Instance of '"+A.bI(a)+"'"},
eX(){return Date.now()},
eY(){var t,s
if($.co!==0)return
$.co=1000
if(typeof window=="undefined")return
t=window
if(t==null)return
if(!!t.dartUseDateNowForTicks)return
s=t.performance
if(s==null)return
if(typeof s.now!="function")return
$.co=1e6
$.dF=new A.cn(s)},
v(a){var t
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){t=a-65536
return String.fromCharCode((B.c.av(t,10)|55296)>>>0,t&1023|56320)}throw A.b(A.aT(a,0,1114111,null,null))},
cH(a){throw A.b(A.e7(a))},
i(a,b){if(a==null)J.a9(a)
throw A.b(A.bW(a,b))},
bW(a,b){var t,s="index"
if(!A.e2(b))return new A.R(!0,b,s,null)
t=J.a9(a)
if(b<0||b>=t)return A.cT(b,t,a,s)
return A.f_(b,s)},
e7(a){return new A.R(!0,a,null,null)},
b(a){return A.u(a,new Error())},
u(a,b){var t
if(a==null)a=new A.aX()
b.dartException=a
t=A.hl
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hl(){return J.bd(this.dartException)},
Q(a,b){throw A.u(a,b==null?new Error():b)},
aA(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.Q(A.fz(a,b,c),t)},
fz(a,b,c){var t,s,r,q,p,o,n,m,l
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
return new A.aZ("'"+t+"': Cannot "+p+" "+m+l+o)},
bc(a){throw A.b(A.M(a))},
V(a){var t,s,r,q,p,o
a=A.hi(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.w([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.cs(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
ct(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
dJ(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
cX(a,b){var t=b==null,s=t?null:b.method
return new A.bu(a,s,t?null:b.receiver)},
ej(a){if(a==null)return new A.cl(a)
if(typeof a!=="object")return a
if("dartException" in a)return A.ak(a,a.dartException)
return A.h_(a)},
ak(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
h_(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.c.av(s,16)&8191)===10)switch(r){case 438:return A.ak(a,A.cX(A.o(t)+" (Error "+r+")",null))
case 445:case 5007:A.o(t)
return A.ak(a,new A.aR())}}if(a instanceof TypeError){q=$.em()
p=$.en()
o=$.eo()
n=$.ep()
m=$.es()
l=$.et()
k=$.er()
$.eq()
j=$.ev()
i=$.eu()
h=q.B(t)
if(h!=null)return A.ak(a,A.cX(A.a6(t),h))
else{h=p.B(t)
if(h!=null){h.method="call"
return A.ak(a,A.cX(A.a6(t),h))}else if(o.B(t)!=null||n.B(t)!=null||m.B(t)!=null||l.B(t)!=null||k.B(t)!=null||n.B(t)!=null||j.B(t)!=null||i.B(t)!=null){A.a6(t)
return A.ak(a,new A.aR())}}return A.ak(a,new A.bP(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.aV()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.ak(a,new A.R(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.aV()
return a},
ef(a){if(a==null)return J.I(a)
if(typeof a=="object")return A.bH(a)
return J.I(a)},
h3(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.t(0,a[t],a[s])}return b},
eJ(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bM().constructor.prototype):Object.create(new A.am(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.dn(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.eF(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.dn(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
eF(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.b("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.eD)}throw A.b("Error in functionType of tearoff")},
eG(a,b,c,d){var t=A.dm
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
dn(a,b,c,d){if(c)return A.eI(a,b,d)
return A.eG(b.length,d,a,b)},
eH(a,b,c,d){var t=A.dm,s=A.eE
switch(b?-1:a){case 0:throw A.b(new A.bK("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
eI(a,b,c){var t,s
if($.dk==null)$.dk=A.dj("interceptor")
if($.dl==null)$.dl=A.dj("receiver")
t=b.length
s=A.eH(t,c,a,b)
return s},
da(a){return A.eJ(a)},
eD(a,b){return A.bb(v.typeUniverse,A.a8(a.a),b)},
dm(a){return a.a},
eE(a){return a.b},
dj(a){var t,s,r,q=new A.am("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.b(A.bZ("Field name "+a+" not found."))},
ea(a){return v.getIsolateTag(a)},
hd(a){var t,s,r,q,p,o=A.a6($.eb.$1(a)),n=$.cG[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cL[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=A.bV($.e6.$2(a,o))
if(r!=null){n=$.cG[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cL[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.cN(t)
$.cG[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.cL[o]=t
return t}if(q==="-"){p=A.cN(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.eg(a,t)
if(q==="*")throw A.b(A.dK(o))
if(v.leafTags[o]===true){p=A.cN(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.eg(a,t)},
eg(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.df(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
cN(a){return J.df(a,!1,null,!!a.$iG)},
hf(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.cN(t)
else return J.df(t,c,null,null)},
h8(){if(!0===$.dd)return
$.dd=!0
A.h9()},
h9(){var t,s,r,q,p,o,n,m
$.cG=Object.create(null)
$.cL=Object.create(null)
A.h7()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.eh.$1(p)
if(o!=null){n=A.hf(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
h7(){var t,s,r,q,p,o,n=B.r()
n=A.ay(B.t,A.ay(B.u,A.ay(B.m,A.ay(B.m,A.ay(B.v,A.ay(B.w,A.ay(B.x(B.l),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.eb=new A.cI(q)
$.e6=new A.cJ(p)
$.eh=new A.cK(o)},
ay(a,b){return a(b)||b},
h1(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
hi(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
b6:function b6(a,b){this.a=a
this.b=b},
bp:function bp(){},
ab:function ab(a,b){this.a=a
this.$ti=b},
cn:function cn(a){this.a=a},
aU:function aU(){},
cs:function cs(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
aR:function aR(){},
bu:function bu(a,b,c){this.a=a
this.b=b
this.c=c},
bP:function bP(a){this.a=a},
cl:function cl(a){this.a=a},
y:function y(){},
bg:function bg(){},
bh:function bh(){},
bN:function bN(){},
bM:function bM(){},
am:function am(a,b){this.a=a
this.b=b},
bK:function bK(a){this.a=a},
T:function T(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ce:function ce(a){this.a=a},
ci:function ci(a,b){this.a=a
this.b=b
this.c=null},
ad:function ad(a,b){this.a=a
this.$ti=b},
aK:function aK(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
cI:function cI(a){this.a=a},
cJ:function cJ(a){this.a=a},
cK:function cK(a){this.a=a},
ag:function ag(){},
av:function av(){},
hk(a){throw A.u(new A.ac("Field '"+a+"' has been assigned during initialization."),new Error())},
a_(){throw A.u(A.eV(""),new Error())},
cv(){var t=new A.cu()
return t.b=t},
cu:function cu(){this.b=null},
ah(a,b,c){if(a>>>0!==a||a>=c)throw A.b(A.bW(b,a))},
ap:function ap(){},
aO:function aO(){},
bx:function bx(){},
aq:function aq(){},
aM:function aM(){},
aN:function aN(){},
by:function by(){},
bz:function bz(){},
bA:function bA(){},
bB:function bB(){},
bC:function bC(){},
bD:function bD(){},
bE:function bE(){},
aP:function aP(){},
bF:function bF(){},
b2:function b2(){},
b3:function b3(){},
b4:function b4(){},
b5:function b5(){},
d0(a,b){var t=b.c
return t==null?b.c=A.b9(a,"dp",[b.x]):t},
dG(a){var t=a.w
if(t===6||t===7)return A.dG(a.x)
return t===11||t===12},
f2(a){return a.as},
bX(a){return A.cC(v.typeUniverse,a,!1)},
hb(a,b){var t,s,r,q,p
if(a==null)return null
t=b.y
s=a.Q
if(s==null)s=a.Q=new Map()
r=b.as
q=s.get(r)
if(q!=null)return q
p=A.a7(v.typeUniverse,a.x,t,0)
s.set(r,p)
return p},
a7(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.a7(a0,t,a2,a3)
if(s===t)return a1
return A.dT(a0,s,!0)
case 7:t=a1.x
s=A.a7(a0,t,a2,a3)
if(s===t)return a1
return A.dS(a0,s,!0)
case 8:r=a1.y
q=A.ax(a0,r,a2,a3)
if(q===r)return a1
return A.b9(a0,a1.x,q)
case 9:p=a1.x
o=A.a7(a0,p,a2,a3)
n=a1.y
m=A.ax(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.d5(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.ax(a0,k,a2,a3)
if(j===k)return a1
return A.dU(a0,l,j)
case 11:i=a1.x
h=A.a7(a0,i,a2,a3)
g=a1.y
f=A.fX(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.dR(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.ax(a0,e,a2,a3)
p=a1.x
o=A.a7(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.d6(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.b(A.bf("Attempted to substitute unexpected RTI kind "+a))}},
ax(a,b,c,d){var t,s,r,q,p=b.length,o=A.cD(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.a7(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
fY(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.cD(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.a7(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
fX(a,b,c,d){var t,s=b.a,r=A.ax(a,s,c,d),q=b.b,p=A.ax(a,q,c,d),o=b.c,n=A.fY(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.bR()
t.a=r
t.b=p
t.c=n
return t},
w(a,b){a[v.arrayRti]=b
return a},
cF(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.h6(t)
return a.$S()}return null},
ha(a,b){var t
if(A.dG(b))if(a instanceof A.y){t=A.cF(a)
if(t!=null)return t}return A.a8(a)},
a8(a){if(a instanceof A.k)return A.F(a)
if(Array.isArray(a))return A.B(a)
return A.d7(J.ai(a))},
B(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
F(a){var t=a.$ti
return t!=null?t:A.d7(a)},
d7(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.fG(a,t)},
fG(a,b){var t=a instanceof A.y?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fp(v.typeUniverse,t.name)
b.$ccache=s
return s},
h6(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.cC(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
h5(a){return A.X(A.F(a))},
dc(a){var t=A.cF(a)
return A.X(t==null?A.a8(a):t)},
d9(a){var t
if(a instanceof A.ag)return A.h2(a.$r,a.aq())
t=a instanceof A.y?A.cF(a):null
if(t!=null)return t
if(u.R.b(a))return J.eA(a).a
if(Array.isArray(a))return A.B(a)
return A.a8(a)},
X(a){var t=a.r
return t==null?a.r=new A.cB(a):t},
h2(a,b){var t,s,r=b,q=r.length
if(q===0)return u.F
if(0>=q)return A.i(r,0)
t=A.bb(v.typeUniverse,A.d9(r[0]),"@<0>")
for(s=1;s<q;++s){if(!(s<r.length))return A.i(r,s)
t=A.dV(v.typeUniverse,t,A.d9(r[s]))}return A.bb(v.typeUniverse,t,a)},
P(a){return A.X(A.cC(v.typeUniverse,a,!1))},
fF(a){var t=this
t.b=A.fW(t)
return t.b(a)},
fW(a){var t,s,r,q,p
if(a===u.K)return A.fM
if(A.aj(a))return A.fQ
t=a.w
if(t===6)return A.fD
if(t===1)return A.e4
if(t===7)return A.fH
s=A.fV(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.aj)){a.f="$i"+r
if(r==="h")return A.fK
if(a===u.m)return A.fJ
return A.fP}}else if(t===10){q=A.h1(a.x,a.y)
p=q==null?A.e4:q
return p==null?A.dZ(p):p}return A.fB},
fV(a){if(a.w===8){if(a===u.S)return A.e2
if(a===u.i||a===u.H)return A.fL
if(a===u.N)return A.fO
if(a===u.y)return A.d8}return null},
fE(a){var t=this,s=A.fA
if(A.aj(t))s=A.fw
else if(t===u.K)s=A.dZ
else if(A.az(t)){s=A.fC
if(t===u.w)s=A.ft
else if(t===u.v)s=A.bV
else if(t===u.c)s=A.L
else if(t===u.x)s=A.m
else if(t===u.I)s=A.fs
else if(t===u.A)s=A.fv}else if(t===u.S)s=A.E
else if(t===u.N)s=A.a6
else if(t===u.y)s=A.fr
else if(t===u.H)s=A.W
else if(t===u.i)s=A.dY
else if(t===u.m)s=A.fu
t.a=s
return t.a(a)},
fB(a){var t=this
if(a==null)return A.az(t)
return A.ec(v.typeUniverse,A.ha(a,t),t)},
fD(a){if(a==null)return!0
return this.x.b(a)},
fP(a){var t,s=this
if(a==null)return A.az(s)
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.ai(a)[t]},
fK(a){var t,s=this
if(a==null)return A.az(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.ai(a)[t]},
fJ(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.k)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
e3(a){if(typeof a=="object"){if(a instanceof A.k)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
fA(a){var t=this
if(a==null){if(A.az(t))return a}else if(t.b(a))return a
throw A.u(A.e_(a,t),new Error())},
fC(a){var t=this
if(a==null||t.b(a))return a
throw A.u(A.e_(a,t),new Error())},
e_(a,b){return new A.aw("TypeError: "+A.dL(a,A.C(b,null)))},
e9(a,b,c,d){if(A.ec(v.typeUniverse,a,b))return a
throw A.u(A.fh("The type argument '"+A.C(a,null)+"' is not a subtype of the type variable bound '"+A.C(b,null)+"' of type variable '"+c+"' in '"+d+"'."),new Error())},
dL(a,b){return A.bn(a)+": type '"+A.C(A.d9(a),null)+"' is not a subtype of type '"+b+"'"},
fh(a){return new A.aw("TypeError: "+a)},
K(a,b){return new A.aw("TypeError: "+A.dL(a,b))},
fH(a){var t=this
return t.x.b(a)||A.d0(v.typeUniverse,t).b(a)},
fM(a){return a!=null},
dZ(a){if(a!=null)return a
throw A.u(A.K(a,"Object"),new Error())},
fQ(a){return!0},
fw(a){return a},
e4(a){return!1},
d8(a){return!0===a||!1===a},
fr(a){if(!0===a)return!0
if(!1===a)return!1
throw A.u(A.K(a,"bool"),new Error())},
L(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.u(A.K(a,"bool?"),new Error())},
dY(a){if(typeof a=="number")return a
throw A.u(A.K(a,"double"),new Error())},
fs(a){if(typeof a=="number")return a
if(a==null)return a
throw A.u(A.K(a,"double?"),new Error())},
e2(a){return typeof a=="number"&&Math.floor(a)===a},
E(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.u(A.K(a,"int"),new Error())},
ft(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.u(A.K(a,"int?"),new Error())},
fL(a){return typeof a=="number"},
W(a){if(typeof a=="number")return a
throw A.u(A.K(a,"num"),new Error())},
m(a){if(typeof a=="number")return a
if(a==null)return a
throw A.u(A.K(a,"num?"),new Error())},
fO(a){return typeof a=="string"},
a6(a){if(typeof a=="string")return a
throw A.u(A.K(a,"String"),new Error())},
bV(a){if(typeof a=="string")return a
if(a==null)return a
throw A.u(A.K(a,"String?"),new Error())},
fu(a){if(A.e3(a))return a
throw A.u(A.K(a,"JSObject"),new Error())},
fv(a){if(a==null)return a
if(A.e3(a))return a
throw A.u(A.K(a,"JSObject?"),new Error())},
e5(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.C(a[r],b)
return t},
fU(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.e5(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.C(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
e0(a2,a3,a4){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=", ",a1=null
if(a4!=null){t=a4.length
if(a3==null)a3=A.w([],u.s)
else a1=a3.length
s=a3.length
for(r=t;r>0;--r)B.a.l(a3,"T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=a0){n=a3.length
m=n-1-r
if(!(m>=0))return A.i(a3,m)
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
if(m===8){q=A.fZ(a.x)
p=a.y
return p.length>0?q+("<"+A.e5(p,b)+">"):q}if(m===10)return A.fU(a,b)
if(m===11)return A.e0(a,b,null)
if(m===12)return A.e0(a.x,b,a.y)
if(m===13){o=a.x
n=b.length
o=n-1-o
if(!(o>=0&&o<n))return A.i(b,o)
return b[o]}return"?"},
fZ(a){var t=v.mangledGlobalNames[a]
if(t!=null)return t
return"minified:"+a},
fq(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fp(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.cC(a,b,!1)
else if(typeof n=="number"){t=n
s=A.ba(a,5,"#")
r=A.cD(t)
for(q=0;q<t;++q)r[q]=s
p=A.b9(a,b,r)
o[b]=p
return p}else return n},
fo(a,b){return A.dW(a.tR,b)},
fn(a,b){return A.dW(a.eT,b)},
cC(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.dP(A.dN(a,null,b,!1))
s.set(b,t)
return t},
bb(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.dP(A.dN(a,b,c,!0))
r.set(c,s)
return s},
dV(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.d5(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
a5(a,b){b.a=A.fE
b.b=A.fF
return b},
ba(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.O(null,null)
t.w=b
t.as=c
s=A.a5(a,t)
a.eC.set(c,s)
return s},
dT(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fl(a,b,s,c)
a.eC.set(s,t)
return t},
fl(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.aj(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.az(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.O(null,null)
r.w=6
r.x=b
r.as=c
return A.a5(a,r)},
dS(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fj(a,b,s,c)
a.eC.set(s,t)
return t},
fj(a,b,c,d){var t,s
if(d){t=b.w
if(A.aj(b)||b===u.K)return b
else if(t===1)return A.b9(a,"dp",[b])
else if(b===u.P||b===u.T)return u.O}s=new A.O(null,null)
s.w=7
s.x=b
s.as=c
return A.a5(a,s)},
fm(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.O(null,null)
t.w=13
t.x=b
t.as=r
s=A.a5(a,t)
a.eC.set(r,s)
return s},
b8(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
fi(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
b9(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.b8(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.O(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.a5(a,s)
a.eC.set(q,r)
return r},
d5(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.b8(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.O(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.a5(a,p)
a.eC.set(r,o)
return o},
dU(a,b,c){var t,s,r="+"+(b+"("+A.b8(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.O(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.a5(a,t)
a.eC.set(r,s)
return s},
dR(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.b8(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.b8(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.fi(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.O(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.a5(a,q)
a.eC.set(s,p)
return p},
d6(a,b,c,d){var t,s=b.as+("<"+A.b8(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fk(a,b,c,s,d)
a.eC.set(s,t)
return t},
fk(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.cD(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.a7(a,b,s,0)
n=A.ax(a,c,s,0)
return A.d6(a,o,n,c!==n)}}m=new A.O(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.a5(a,m)},
dN(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
dP(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.fc(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.dO(a,s,m,l,!1)
else if(r===46)s=A.dO(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.af(a.u,a.e,l.pop()))
break
case 94:l.push(A.fm(a.u,l.pop()))
break
case 35:l.push(A.ba(a.u,5,"#"))
break
case 64:l.push(A.ba(a.u,2,"@"))
break
case 126:l.push(A.ba(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.fe(a,l)
break
case 38:A.fd(a,l)
break
case 63:q=a.u
l.push(A.dT(q,A.af(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.dS(q,A.af(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.fb(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.dQ(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.fg(a.u,a.e,p)
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
return A.af(a.u,a.e,n)},
fc(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
dO(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fq(t,p.x)[q]
if(o==null)A.Q('No "'+q+'" in "'+A.f2(p)+'"')
d.push(A.bb(t,p,o))}else d.push(q)
return n},
fe(a,b){var t,s=a.u,r=A.dM(a,b),q=b.pop()
if(typeof q=="string")b.push(A.b9(s,q,r))
else{t=A.af(s,a.e,q)
switch(t.w){case 11:b.push(A.d6(s,t,r,a.n))
break
default:b.push(A.d5(s,t,r))
break}}},
fb(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.dM(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.af(q,a.e,p)
r=new A.bR()
r.a=t
r.b=o
r.c=n
b.push(A.dR(q,s,r))
return
case-4:b.push(A.dU(q,b.pop(),t))
return
default:throw A.b(A.bf("Unexpected state under `()`: "+A.o(p)))}},
fd(a,b){var t=b.pop()
if(0===t){b.push(A.ba(a.u,1,"0&"))
return}if(1===t){b.push(A.ba(a.u,4,"1&"))
return}throw A.b(A.bf("Unexpected extended operation "+A.o(t)))},
dM(a,b){var t=b.splice(a.p)
A.dQ(a.u,a.e,t)
a.p=b.pop()
return t},
af(a,b,c){if(typeof c=="string")return A.b9(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.ff(a,b,c)}else return c},
dQ(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.af(a,b,c[t])},
fg(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.af(a,b,c[t])},
ff(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.b(A.bf("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.b(A.bf("Bad index "+c+" for "+b.j(0)))},
ec(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.r(a,b,null,c,null)
s.set(c,t)}return t},
r(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.aj(d))return!0
t=b.w
if(t===4)return!0
if(A.aj(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.r(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.r(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.r(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.r(a,b.x,c,d,e))return!1
return A.r(a,A.d0(a,b),c,d,e)}if(t===6)return A.r(a,q,c,d,e)&&A.r(a,b.x,c,d,e)
if(r===7){if(A.r(a,b,c,d.x,e))return!0
return A.r(a,b,c,A.d0(a,d),e)}if(r===6)return A.r(a,b,c,q,e)||A.r(a,b,c,d.x,e)
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
if(!A.r(a,k,c,j,e)||!A.r(a,j,e,k,c))return!1}return A.e1(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.e1(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.fI(a,b,c,d,e)}if(p&&r===10)return A.fN(a,b,c,d,e)
return!1},
e1(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.r(a2,a3.x,a4,a5.x,a6))return!1
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
if(!A.r(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.r(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.r(a2,l[i],a6,h,a4))return!1}g=t.c
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
if(!A.r(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
fI(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.bb(a,b,s[p])
return A.dX(a,q,null,c,d.y,e)}return A.dX(a,b.y,null,c,d.y,e)},
dX(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.r(a,b[t],d,e[t],f))return!1
return!0},
fN(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.r(a,s[t],c,r[t],e))return!1
return!0},
az(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.aj(a))if(t!==6)s=t===7&&A.az(a.x)
return s},
aj(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
dW(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
cD(a){return a>0?new Array(a):v.typeUniverse.sEA},
O:function O(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
bR:function bR(){this.c=this.b=this.a=null},
cB:function cB(a){this.a=a},
bQ:function bQ(){},
aw:function aw(a){this.a=a},
eW(a,b){return new A.T(a.i("@<0>").E(b).i("T<1,2>"))},
cj(a,b,c){return b.i("@<0>").E(c).i("dw<1,2>").a(A.h3(a,new A.T(b.i("@<0>").E(c).i("T<1,2>"))))},
dx(a,b){return new A.T(a.i("@<0>").E(b).i("T<1,2>"))},
cY(a){return new A.b1(a.i("b1<0>"))},
d4(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
fa(a,b,c){var t=new A.ae(a,b,c.i("ae<0>"))
t.c=a.e
return t},
dA(a){var t,s
if(A.de(a))return"{...}"
t=new A.as("")
try{s={}
B.a.l($.H,a)
t.a+="{"
s.a=!0
a.P(0,new A.ck(s,t))
t.a+="}"}finally{if(0>=$.H.length)return A.i($.H,-1)
$.H.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
b1:function b1(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
bU:function bU(a){this.a=a
this.c=this.b=null},
ae:function ae(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
f:function f(){},
D:function D(){},
ck:function ck(a,b){this.a=a
this.b=b},
ar:function ar(){},
b7:function b7(){},
fT(a,b){var t,s,r,q=null
try{q=JSON.parse(a)}catch(s){t=A.ej(s)
r=String(t)
throw A.b(new A.t(r))}r=A.cE(q)
return r},
cE(a){var t
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.bS(a,Object.create(null))
for(t=0;t<a.length;++t)a[t]=A.cE(a[t])
return a},
dv(a,b,c){return new A.aI(a,b)},
fy(a){return a.T()},
f8(a,b){return new A.cx(a,[],A.h0())},
f9(a,b,c){var t,s=new A.as(""),r=A.f8(s,b)
r.a_(a)
t=s.a
return t.charCodeAt(0)==0?t:t},
bS:function bS(a,b){this.a=a
this.b=b
this.c=null},
bT:function bT(a){this.a=a},
bi:function bi(){},
bk:function bk(){},
aI:function aI(a,b){this.a=a
this.b=b},
bv:function bv(a,b){this.a=a
this.b=b},
cf:function cf(){},
ch:function ch(a){this.b=a},
cg:function cg(a){this.a=a},
cy:function cy(){},
cz:function cz(a,b){this.a=a
this.b=b},
cx:function cx(a,b,c){this.c=a
this.a=b
this.b=c},
cZ(a,b,c,d){var t,s=c?J.dt(a,d):J.ds(a,d)
if(a!==0&&b!=null)for(t=0;t<s.length;++t)s[t]=b
return s},
dz(a,b,c){var t,s,r=A.w([],c.i("n<0>"))
for(t=a.length,s=0;s<a.length;a.length===t||(0,A.bc)(a),++s)B.a.l(r,c.a(a[s]))
if(b)return r
r.$flags=1
return r},
dy(a,b){var t,s=A.w([],b.i("n<0>"))
for(t=a.gu(a);t.m();)B.a.l(s,t.gp())
return s},
dH(a,b,c){var t=J.cS(b)
if(!t.m())return a
if(c.length===0){do a+=A.o(t.gp())
while(t.m())}else{a+=A.o(t.gp())
while(t.m())a=a+c+A.o(t.gp())}return a},
bn(a){if(typeof a=="number"||A.d8(a)||a==null)return J.bd(a)
if(typeof a=="string")return JSON.stringify(a)
return A.dE(a)},
bf(a){return new A.be(a)},
bZ(a){return new A.R(!1,null,null,a)},
eC(a,b,c){return new A.R(!0,a,b,c)},
f_(a,b){return new A.aS(null,null,!0,a,b,"Value not in range")},
aT(a,b,c,d,e){return new A.aS(b,c,!0,a,d,"Invalid value")},
f0(a,b,c){if(0>a||a>c)throw A.b(A.aT(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.b(A.aT(b,a,c,"end",null))
return b}return c},
d_(a,b){if(a<0)throw A.b(A.aT(a,0,null,b,null))
return a},
cT(a,b,c,d){return new A.bo(b,!0,a,d,"Index out of range")},
d3(a){return new A.aZ(a)},
dK(a){return new A.bO(a)},
M(a){return new A.bj(a)},
eR(a,b,c){var t,s
if(A.de(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.w([],u.s)
B.a.l($.H,a)
try{A.fR(a,t)}finally{if(0>=$.H.length)return A.i($.H,-1)
$.H.pop()}s=A.dH(b,u.U.a(t),", ")+c
return s.charCodeAt(0)==0?s:s},
cU(a,b,c){var t,s
if(A.de(a))return b+"..."+c
t=new A.as(b)
B.a.l($.H,a)
try{s=t
s.a=A.dH(s.a,a,", ")}finally{if(0>=$.H.length)return A.i($.H,-1)
$.H.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
fR(a,b){var t,s,r,q,p,o,n,m=a.gu(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.m())return
t=A.o(m.gp())
B.a.l(b,t)
l+=t.length+2;++k}if(!m.m()){if(k<=5)return
if(0>=b.length)return A.i(b,-1)
s=b.pop()
if(0>=b.length)return A.i(b,-1)
r=b.pop()}else{q=m.gp();++k
if(!m.m()){if(k<=4){B.a.l(b,A.o(q))
return}s=A.o(q)
if(0>=b.length)return A.i(b,-1)
r=b.pop()
l+=s.length+2}else{p=m.gp();++k
for(;m.m();q=p,p=o){o=m.gp();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
if(0>=b.length)return A.i(b,-1)
l-=b.pop().length+2;--k}B.a.l(b,"...")
return}}r=A.o(q)
s=A.o(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
if(0>=b.length)return A.i(b,-1)
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)B.a.l(b,n)
B.a.l(b,r)
B.a.l(b,s)},
dC(a,b,c,d){var t
if(B.e===c){t=J.I(a)
b=J.I(b)
return A.d2(A.a4(A.a4($.cQ(),t),b))}if(B.e===d){t=J.I(a)
b=J.I(b)
c=J.I(c)
return A.d2(A.a4(A.a4(A.a4($.cQ(),t),b),c))}t=J.I(a)
b=J.I(b)
c=J.I(c)
d=J.I(d)
d=A.d2(A.a4(A.a4(A.a4(A.a4($.cQ(),t),b),c),d))
return d},
l:function l(){},
be:function be(a){this.a=a},
aX:function aX(){},
R:function R(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
aS:function aS(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bo:function bo(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
aZ:function aZ(a){this.a=a},
bO:function bO(a){this.a=a},
bL:function bL(a){this.a=a},
bj:function bj(a){this.a=a},
aV:function aV(){},
t:function t(a){this.a=a},
c:function c(){},
aQ:function aQ(){},
k:function k(){},
cr:function cr(){this.b=this.a=0},
as:function as(a){this.a=a},
eK(a){var t,s,r,q,p,o,n,m,l,k,j=null,i=a.h(0,"aspects")
if(i==null)i=a.h(0,"enemyAspects")
if(u.j.b(i)&&J.ez(i)){t=J.eB(i,new A.c0(),u.i)
s=A.dy(t,t.$ti.i("A.E"))}else s=B.o
t=A.m(a.h(0,"areaMultiplier"))
if(t==null)t=j
if(t==null){t=A.m(a.h(0,"enemyAreaMultiplier"))
if(t==null)t=j}if(t==null)t=2
r=A.m(a.h(0,"angleMinDeg"))
if(r==null)r=j
if(r==null)r=30
q=A.m(a.h(0,"angleMaxDeg"))
if(q==null)q=j
if(q==null)q=60
p=A.m(a.h(0,"speedMin"))
if(p==null)p=j
if(p==null)p=75
o=A.m(a.h(0,"speedMax"))
if(o==null)o=j
if(o==null)o=105
n=A.m(a.h(0,"accelMin"))
if(n==null)n=j
if(n==null)n=9
m=A.m(a.h(0,"accelMax"))
if(m==null)m=j
if(m==null)m=15
l=A.L(a.h(0,"collideWithEachOther"))
if(l==null)l=A.L(a.h(0,"enemiesCollide"))
k=A.m(a.h(0,"spinDegPerSec"))
if(k==null)k=j
if(k==null)k=0
return new A.bl(t,s,r,q,p,o,n,m,l===!0,k)},
dq(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=null,c="warning",b=A.L(a0.h(0,"startHintEnabled")),a=A.m(a0.h(0,"idleSpeedMultiplier"))
if(a==null)a=d
if(a==null)a=0.5
t=A.L(a0.h(0,"idleEnemiesMove"))
s=A.m(a0.h(0,"speedRampSeconds"))
if(s==null)s=d
if(s==null)s=0.5
r=A.L(a0.h(0,"jumpEnabled"))
if(r==null)r=A.L(a0.h(0,"jumpsEnabled"))
q=A.m(a0.h(0,"jumpDurationSec"))
if(q==null)q=d
if(q==null)q=0.38
p=A.m(a0.h(0,"jumpCooldownSec"))
if(p==null)p=d
if(p==null)p=2
o=A.m(a0.h(0,"jumpScale"))
if(o==null)o=d
if(o==null)o=1.32
n=A.L(a0.h(0,"helmetEnabled"))
m=A.m(a0.h(0,"helmetInvulnSec"))
if(m==null)m=d
if(m==null)m=0.3
l=A.m(a0.h(0,"startInvulnSec"))
if(l==null)l=d
if(l==null)l=1
k=A.L(a0.h(0,"heartbeatHaptic"))
j=A.L(a0.h(0,"timerHaptic"))
i=A.bV(a0.h(0,"timerHapticStyle"))
if(i==null)i=c
h=A.bV(a0.h(0,"timerHapticStyle5"))
if(h==null)h=c
g=A.bV(a0.h(0,"timerHapticStyle10"))
if(g==null)g=c
f=A.m(a0.h(0,"hudSpeedScaleMax"))
if(f==null)f=d
if(f==null)f=400
e=A.L(a0.h(0,"wallsKillPlayer"))
return new A.c3(b!==!1,a,t!==!1,s,r!==!1,q,p,o,n!==!1,m,l,k!==!1,j!==!1,i,h,g,f,e!==!1)},
dB(a,b){if(a==null)return b
if(typeof a!="number"||!isFinite(a)||a<0||a>0.5)throw A.b(B.z)
return a},
cc:function cc(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.f=e},
bl:function bl(a,b,c,d,e,f,g,h,i,j){var _=this
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
c0:function c0(){},
cm:function cm(a,b){this.a=a
this.b=b},
c2:function c2(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
c3:function c3(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r){var _=this
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
bw:function bw(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
d:function d(a,b){this.a=a
this.b=b},
cq:function cq(){},
N:function N(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
he(){var t,s=v.G.globalThis,r=new A.cM()
if(typeof r=="function")A.Q(A.bZ("Attempting to rewrap a JS function."))
t=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.fx,r)
t[$.dg()]=r
s.untouchReplay=t},
cM:function cM(){},
f1(a){var t,s,r,q
for(t=new A.aB(a),s=u.V,t=new A.U(t,t.gk(0),s.i("U<f.E>")),s=s.i("f.E"),r=2166136261;t.m();){q=t.d
r=(r^(q==null?s.a(q):q))>>>0
r=r*403+((r&255)<<24>>>0)>>>0}return r===0?1:r},
bJ:function bJ(a){this.a=a},
hj(b9){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0=null,b1="mobileEnemies",b2="proof",b3={},b4=u.a,b5=b4.a(b9.h(0,"config")),b6=A.eK(b4.a(b5.h(0,"enemies"))),b7=b4.a(b5.h(0,"player")),b8=A.m(b7.h(0,"size"))
if(b8==null)b8=b0
if(b8==null){b8=A.m(b7.h(0,"playerSize"))
if(b8==null)b8=b0}if(b8==null)b8=36
t=A.L(b7.h(0,"showFace"))
b7=t==null?A.L(b7.h(0,"playerShowFace")):t
t=b4.a(b5.h(0,"field"))
s=t.h(0,"color")
r=s==null?t.h(0,"colorHex"):s
if(r==null)r=t.h(0,"surfaceColor")
q=typeof r=="string"&&B.d.aG(r).length!==0?B.d.aG(r):b0
s=A.m(t.h(0,"borderWidth"))
if(s==null)s=b0
if(s==null)s=3
p=A.m(t.h(0,"brightness"))
if(p==null)p=b0
if(p==null){p=A.m(t.h(0,"fieldBrightness"))
if(p==null)p=b0}if(p==null)p=1
t=A.m(t.h(0,"shadowBrightness"))
if(t==null)t=b0
if(t==null)t=1
o=A.dq(b4.a(b5.h(0,"game")))
if(b4.b(b5.h(0,b1))){b4=b4.a(b5.h(0,b1))
n=b4.h(0,"startSpeedSteps")
m=b4.h(0,"accelerationSteps")
if(typeof n!="number"||typeof m!="number"||!isFinite(n)||!isFinite(m)||n<0.01||n>250||m<0||m>50)A.Q(B.G)
l=new A.bw(n,m,A.dB(b4.h(0,"speedVariation"),0.05),A.dB(b4.h(0,"accelerationVariation"),0.08))}else l=B.p
b4=b8*1.2
k=b4*0.1
j=l.a*k
i=l.c
h=l.b*k
g=l.d
o=o.T()
f=u.N
e=u.z
d=A.eW(f,e)
d.I(0,o)
d.t(0,"speedRampSeconds",0)
d=A.dq(d)
c=new A.cc(new A.bl(b6.a,b6.b,b6.c,b6.d,j*(1-i),j*(1+i),h*(1-g),h*(1+g),b6.x,b6.y),new A.cm(b8,b7===!0),new A.c2(s,p,t,q),d,B.p)
s/=2
t=B.b.v(s+0.5,0.5,12)
p=A.f1(A.a6(b9.h(0,"requestId")))
b7=A.w([],u.u)
b8=new A.cr()
$.el()
b6=$.dF.$0()
b8.a=b6
b8.b=null
b6=A.w([],u.l)
o=u.S
j=A.cY(o)
o=A.cY(o)
b=new A.c4(c,B.y,new A.bJ(p),t+s,b7,b8,b6,j,o)
b4=(380-b4)/2
b.e=new A.d(b4,b4)
B.a.D(b6)
j.D(0)
o.D(0)
B.a.D(b7)
B.a.I(b7,b.aY())
a=J.cR(b9.h(0,b2),"startPose")
if(a!=null)b.bd(a)
b3.a=J.al(b9.h(0,"hadHelmet"),!0)
b3.b=!1
a0=J.al(b9.h(0,"hadJump"),!0)
b3.c=Math.max(0,d.z)
b3.d=0
a1=new A.cP(b3)
a2=new A.cO(b3,a1,b,c)
b4=u.j
a3=b4.a(J.cR(b9.h(0,b2),"events"))
if(!J.al(J.cR(b9.h(0,b2),"version"),1)||J.a9(a3)>6e5)throw A.b(B.M)
for(b6=J.cS(a3),d=!d.CW,a4=0;b6.m();){a5=b6.gp()
if(b3.b)throw A.b(B.I)
b4.a(a5)
b7=J.Y(a5)
switch(b7.h(a5,0)){case 0:if(b7.gk(a5)!==2||typeof b7.h(a5,1)!="number")throw A.b(B.O)
a6=A.W(b7.h(a5,1))
if(!isFinite(a6)||a6<=0||a6>50)throw A.b(B.A)
a4+=a6
if(a4>36e5)throw A.b(B.F)
a7=a6/1000
b.bf(a7)
b.bh(a7,a4/1000,!a1.$0())
b3.c=Math.max(0,b3.c-a7)
b3.d=Math.max(0,b3.d-a7)
if(d&&b.ai())b.aA()
a2.$0()
break
case 1:if(b7.gk(a5)!==3||typeof b7.h(a5,1)!="number"||typeof b7.h(a5,2)!="number")throw A.b(B.K)
a8=A.W(b7.h(a5,1))
a9=A.W(b7.h(a5,2))
if(!isFinite(a8)||!isFinite(a9)||Math.abs(a8)>2000||Math.abs(a9)>2000)throw A.b(B.L)
b.b8(new A.d(a8,a9),!a1.$0())
if(d&&b.ai())b.aA()
a2.$0()
break
case 2:if(b7.gk(a5)!==1||!a0||!b.bk(a4))throw A.b(B.B)
break
default:throw A.b(B.J)}}if(!b3.b)throw A.b(B.D)
return A.cj(["timeMs",B.b.ae(a4),"runDistance",B.b.be(Math.max(0,b.y/Math.max(0.000001,k))),"riskCount",b.z],f,e)},
cP:function cP(a){this.a=a},
cO:function cO(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eN(a,b){var t,s
if(a.X(b))return 0
t=Math.max(0,Math.max(a.a-b.c,b.a-a.c))
s=Math.max(0,Math.max(a.b-b.d,b.b-a.d))
if(t>0&&s>0)return Math.sqrt(t*t+s*s)
return Math.max(t,s)},
c_:function c_(){},
a3:function a3(){this.b=0},
bm:function bm(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.y=c
_.z=d
_.ay=e
_.ch=f
_.CW=g
_.cx=h},
c1:function c1(a,b,c){this.a=a
this.b=b
this.c=c},
c4:function c4(a,b,c,d,e,f,g,h,i){var _=this
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
c9:function c9(){},
ca:function ca(){},
c5:function c5(){},
c6:function c6(){},
c7:function c7(){},
c8:function c8(){},
cb:function cb(a){this.a=a},
fx(a,b,c){u.Z.a(a)
if(A.E(c)>=1)return a.$1(b)
return a.$0()},
ee(a,b,c){A.e9(c,u.H,"T","min")
return Math.min(c.a(a),c.a(b))},
ed(a,b,c){A.e9(c,u.H,"T","max")
return Math.max(c.a(a),c.a(b))}},B={}
var w=[A,J,B]
var $={}
A.cW.prototype={}
J.bq.prototype={
H(a,b){return a===b},
gq(a){return A.bH(a)},
j(a){return"Instance of '"+A.bI(a)+"'"},
gn(a){return A.X(A.d7(this))}}
J.bs.prototype={
j(a){return String(a)},
gq(a){return a?519018:218159},
gn(a){return A.X(u.y)},
$ij:1,
$ix:1}
J.aE.prototype={
H(a,b){return null==b},
j(a){return"null"},
gq(a){return 0},
$ij:1}
J.aG.prototype={$ip:1}
J.a2.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.bG.prototype={}
J.at.prototype={}
J.a1.prototype={
j(a){var t=a[$.ek()]
if(t==null)t=a[$.dg()]
if(t==null)return this.aK(a)
return"JavaScript function for "+J.bd(t)},
$iS:1}
J.aF.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.aH.prototype={
gq(a){return 0},
j(a){return String(a)}}
J.n.prototype={
l(a,b){A.B(a).c.a(b)
a.$flags&1&&A.aA(a,29)
a.push(b)},
aV(a,b,c){var t,s,r,q,p
A.B(a).i("x(1)").a(b)
t=[]
s=a.length
for(r=0;r<s;++r){q=a[r]
if(!b.$1(q))t.push(q)
if(a.length!==s)throw A.b(A.M(a))}p=t.length
if(p===s)return
this.sk(a,p)
for(r=0;r<t.length;++r)a[r]=t[r]},
I(a,b){A.B(a).i("c<1>").a(b)
a.$flags&1&&A.aA(a,"addAll",2)
this.aM(a,b)
return},
aM(a,b){var t,s
u.b.a(b)
t=b.length
if(t===0)return
if(a===b)throw A.b(A.M(a))
for(s=0;s<t;++s)a.push(b[s])},
D(a){a.$flags&1&&A.aA(a,"clear","clear")
a.length=0},
aD(a,b,c){var t=A.B(a)
return new A.J(a,t.E(c).i("1(2)").a(b),t.i("@<1>").E(c).i("J<1,2>"))},
b7(a,b){var t,s=A.cZ(a.length,"",!1,u.N)
for(t=0;t<a.length;++t)this.t(s,t,A.o(a[t]))
return s.join(b)},
A(a,b){if(!(b>=0&&b<a.length))return A.i(a,b)
return a[b]},
gF(a){if(a.length>0)return a[0]
throw A.b(A.dr())},
az(a,b){var t,s
A.B(a).i("x(1)").a(b)
t=a.length
for(s=0;s<t;++s){if(b.$1(a[s]))return!0
if(a.length!==t)throw A.b(A.M(a))}return!1},
ak(a,b){var t,s,r,q
a.$flags&2&&A.aA(a,"shuffle")
t=a.length
while(t>1){s=b.ba(t);--t
r=a.length
if(!(t<r))return A.i(a,t)
q=a[t]
if(!(s>=0&&s<r))return A.i(a,s)
a[t]=a[s]
a[s]=q}},
gah(a){return a.length!==0},
j(a){return A.cU(a,"[","]")},
gu(a){return new J.aa(a,a.length,A.B(a).i("aa<1>"))},
gq(a){return A.bH(a)},
gk(a){return a.length},
sk(a,b){a.$flags&1&&A.aA(a,"set length","change the length of")
if(b>a.length)A.B(a).c.a(null)
a.length=b},
h(a,b){A.E(b)
if(!(b>=0&&b<a.length))throw A.b(A.bW(a,b))
return a[b]},
t(a,b,c){A.B(a).c.a(c)
a.$flags&2&&A.aA(a)
if(!(b>=0&&b<a.length))throw A.b(A.bW(a,b))
a[b]=c},
$ic:1,
$ih:1}
J.br.prototype={
bj(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bI(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.cd.prototype={}
J.aa.prototype={
gp(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t,s=this,r=s.a,q=r.length
if(s.b!==q){r=A.bc(r)
throw A.b(r)}t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0},
$ia0:1}
J.an.prototype={
ab(a,b){var t
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){t=this.gag(b)
if(this.gag(a)===t)return 0
if(this.gag(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gag(a){return a===0?1/a<0:a<0},
b_(a){var t,s
if(a>=0){if(a<=2147483647){t=a|0
return a===t?t:t+1}}else if(a>=-2147483648)return a|0
s=Math.ceil(a)
if(isFinite(s))return s
throw A.b(A.d3(""+a+".ceil()"))},
ae(a){var t,s
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){t=a|0
return a===t?t:t-1}s=Math.floor(a)
if(isFinite(s))return s
throw A.b(A.d3(""+a+".floor()"))},
be(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.b(A.d3(""+a+".round()"))},
v(a,b,c){if(this.ab(b,c)>0)throw A.b(A.e7(b))
if(this.ab(a,b)<0)return b
if(this.ab(a,c)>0)return c
return a},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gq(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
a0(a,b){var t=a%b
if(t===0)return 0
if(t>0)return t
return t+b},
av(a,b){var t
if(a>0)t=this.aX(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
aX(a,b){return b>31?0:a>>>b},
gn(a){return A.X(u.H)},
$ie:1,
$iZ:1}
J.aD.prototype={
gn(a){return A.X(u.S)},
$ij:1,
$ia:1}
J.bt.prototype={
gn(a){return A.X(u.i)},
$ij:1}
J.ao.prototype={
V(a,b,c){return a.substring(b,A.f0(b,c,a.length))},
aG(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(0>=p)return A.i(q,0)
if(q.charCodeAt(0)===133){t=J.eT(q,1)
if(t===p)return""}else t=0
s=p-1
if(!(s>=0))return A.i(q,s)
r=q.charCodeAt(s)===133?J.eU(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
j(a){return a},
gq(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gn(a){return A.X(u.N)},
gk(a){return a.length},
h(a,b){A.E(b)
if(!(b.bo(0,0)&&b.aj(0,a.length)))throw A.b(A.bW(a,b))
return a[b]},
$ij:1,
$iq:1}
A.ac.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.aB.prototype={
gk(a){return this.a.length},
h(a,b){var t
A.E(b)
t=this.a
if(!(b>=0&&b<t.length))return A.i(t,b)
return t.charCodeAt(b)}}
A.cp.prototype={}
A.aC.prototype={}
A.A.prototype={
gu(a){var t=this
return new A.U(t,t.gk(t),A.F(t).i("U<A.E>"))},
gR(a){return this.gk(this)===0},
Z(a,b){var t,s,r,q=this
A.F(q).i("A.E(A.E,A.E)").a(b)
t=q.gk(q)
if(t===0)throw A.b(A.dr())
s=q.A(0,0)
for(r=1;r<t;++r){s=b.$2(s,q.A(0,r))
if(t!==q.gk(q))throw A.b(A.M(q))}return s}}
A.aW.prototype={
gaP(){var t=J.a9(this.a),s=this.c
if(s==null||s>t)return t
return s},
gaZ(){var t=J.a9(this.a),s=this.b
if(s>t)return t
return s},
gk(a){var t,s=J.a9(this.a),r=this.b
if(r>=s)return 0
t=this.c
if(t==null||t>=s)return s-r
return t-r},
A(a,b){var t=this,s=t.gaZ()+b
if(b<0||s>=t.gaP())throw A.b(A.cT(b,t.gk(0),t,"index"))
return J.di(t.a,s)},
bi(a,b){var t,s,r,q=this,p=q.b,o=q.a,n=J.Y(o),m=n.gk(o),l=q.c
if(l!=null&&l<m)m=l
t=m-p
if(t<=0){o=q.$ti.c
return b?J.dt(0,o):J.ds(0,o)}s=A.cZ(t,n.A(o,p),b,q.$ti.c)
for(r=1;r<t;++r){B.a.t(s,r,n.A(o,p+r))
if(n.gk(o)<m)throw A.b(A.M(q))}return s},
aF(a){return this.bi(0,!0)}}
A.U.prototype={
gp(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t,s=this,r=s.a,q=J.Y(r),p=q.gk(r)
if(s.b!==p)throw A.b(A.M(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.A(r,t);++s.c
return!0},
$ia0:1}
A.J.prototype={
gk(a){return J.a9(this.a)},
A(a,b){return this.b.$1(J.di(this.a,b))}}
A.b_.prototype={
gu(a){return new A.b0(J.cS(this.a),this.b,this.$ti.i("b0<1>"))}}
A.b0.prototype={
m(){var t,s
for(t=this.a,s=this.b;t.m();)if(s.$1(t.gp()))return!0
return!1},
gp(){return this.a.gp()},
$ia0:1}
A.z.prototype={}
A.aY.prototype={}
A.au.prototype={}
A.b6.prototype={$r:"+(1,2)",$s:1}
A.bp.prototype={
H(a,b){if(b==null)return!1
return b instanceof A.ab&&this.a.H(0,b.a)&&A.dc(this)===A.dc(b)},
gq(a){return A.dC(this.a,A.dc(this),B.e,B.e)},
j(a){var t=B.a.b7([A.X(this.$ti.c)],", ")
return this.a.j(0)+" with "+("<"+t+">")}}
A.ab.prototype={
$2(a,b){return this.a.$1$2(a,b,this.$ti.y[0])},
$S(){return A.hb(A.cF(this.a),this.$ti)}}
A.cn.prototype={
$0(){return B.b.ae(1000*this.a.now())},
$S:1}
A.aU.prototype={}
A.cs.prototype={
B(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
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
A.aR.prototype={
j(a){return"Null check operator used on a null value"}}
A.bu.prototype={
j(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bP.prototype={
j(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.cl.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.y.prototype={
j(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.ei(s==null?"unknown":s)+"'"},
$iS:1,
gbn(){return this},
$C:"$1",
$R:1,
$D:null}
A.bg.prototype={$C:"$0",$R:0}
A.bh.prototype={$C:"$2",$R:2}
A.bN.prototype={}
A.bM.prototype={
j(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.ei(t)+"'"}}
A.am.prototype={
H(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.am))return!1
return this.$_target===b.$_target&&this.a===b.a},
gq(a){return(A.ef(this.a)^A.bH(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bI(this.a)+"'")}}
A.bK.prototype={
j(a){return"RuntimeError: "+this.a}}
A.T.prototype={
gk(a){return this.a},
gR(a){return this.a===0},
gS(){return new A.ad(this,A.F(this).i("ad<1>"))},
I(a,b){A.F(this).i("aL<1,2>").a(b).P(0,new A.ce(this))},
h(a,b){var t,s,r,q,p=null
if(typeof b=="string"){t=this.b
if(t==null)return p
s=t[b]
r=s==null?p:s.b
return r}else if(typeof b=="number"&&(b&0x3fffffff)===b){q=this.c
if(q==null)return p
s=q[b]
r=s==null?p:s.b
return r}else return this.b5(b)},
b5(a){var t,s,r=this.d
if(r==null)return null
t=r[this.aB(a)]
s=this.aC(t,a)
if(s<0)return null
return t[s].b},
t(a,b,c){var t,s,r=this,q=A.F(r)
q.c.a(b)
q.y[1].a(c)
if(typeof b=="string"){t=r.b
r.al(t==null?r.b=r.a9():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.al(s==null?r.c=r.a9():s,b,c)}else r.b6(b,c)},
b6(a,b){var t,s,r,q,p=this,o=A.F(p)
o.c.a(a)
o.y[1].a(b)
t=p.d
if(t==null)t=p.d=p.a9()
s=p.aB(a)
r=t[s]
if(r==null)t[s]=[p.aa(a,b)]
else{q=p.aC(r,a)
if(q>=0)r[q].b=b
else r.push(p.aa(a,b))}},
P(a,b){var t,s,r=this
A.F(r).i("~(1,2)").a(b)
t=r.e
s=r.r
while(t!=null){b.$2(t.a,t.b)
if(s!==r.r)throw A.b(A.M(r))
t=t.c}},
al(a,b,c){var t,s=A.F(this)
s.c.a(b)
s.y[1].a(c)
t=a[b]
if(t==null)a[b]=this.aa(b,c)
else t.b=c},
aa(a,b){var t=this,s=A.F(t),r=new A.ci(s.c.a(a),s.y[1].a(b))
if(t.e==null)t.e=t.f=r
else t.f=t.f.c=r;++t.a
t.r=t.r+1&1073741823
return r},
aB(a){return J.I(a)&1073741823},
aC(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.al(a[s].a,b))return s
return-1},
j(a){return A.dA(this)},
a9(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
$idw:1}
A.ce.prototype={
$2(a,b){var t=this.a,s=A.F(t)
t.t(0,s.c.a(a),s.y[1].a(b))},
$S(){return A.F(this.a).i("~(1,2)")}}
A.ci.prototype={}
A.ad.prototype={
gk(a){return this.a.a},
gR(a){return this.a.a===0},
gu(a){var t=this.a
return new A.aK(t,t.r,t.e,this.$ti.i("aK<1>"))}}
A.aK.prototype={
gp(){return this.d},
m(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.b(A.M(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=t.a
s.c=t.c
return!0}},
$ia0:1}
A.cI.prototype={
$1(a){return this.a(a)},
$S:2}
A.cJ.prototype={
$2(a,b){return this.a(a,b)},
$S:5}
A.cK.prototype={
$1(a){return this.a(A.a6(a))},
$S:6}
A.ag.prototype={
j(a){return this.aw(!1)},
aw(a){var t,s,r,q,p,o=this.aQ(),n=this.aq(),m=(a?"Record ":"")+"("
for(t=o.length,s="",r=0;r<t;++r,s=", "){m+=s
q=o[r]
if(typeof q=="string")m=m+q+": "
if(!(r<n.length))return A.i(n,r)
p=n[r]
m=a?m+A.dE(p):m+A.o(p)}m+=")"
return m.charCodeAt(0)==0?m:m},
aQ(){var t,s=this.$s
while($.cA.length<=s)B.a.l($.cA,null)
t=$.cA[s]
if(t==null){t=this.aN()
B.a.t($.cA,s,t)}return t},
aN(){var t,s,r,q=this.$r,p=q.indexOf("("),o=q.substring(1,p),n=q.substring(p),m=n==="()"?0:n.replace(/[^,]/g,"").length+1,l=u.K,k=J.cV(m,l)
for(t=0;t<m;++t)k[t]=t
if(o!==""){s=o.split(",")
t=s.length
for(r=m;t>0;){--r;--t
B.a.t(k,r,s[t])}}k=A.dz(k,!1,l)
k.$flags=3
return k}}
A.av.prototype={
aq(){return[this.a,this.b]},
H(a,b){if(b==null)return!1
return b instanceof A.av&&this.$s===b.$s&&J.al(this.a,b.a)&&J.al(this.b,b.b)},
gq(a){return A.dC(this.$s,this.a,this.b,B.e)}}
A.cu.prototype={
L(){var t=this.b
if(t===this)throw A.b(new A.ac("Local '' has not been initialized."))
return t}}
A.ap.prototype={
gn(a){return B.X},
$ij:1}
A.aO.prototype={}
A.bx.prototype={
gn(a){return B.Y},
$ij:1}
A.aq.prototype={
gk(a){return a.length},
$iG:1}
A.aM.prototype={
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ic:1,
$ih:1}
A.aN.prototype={$ic:1,$ih:1}
A.by.prototype={
gn(a){return B.Z},
$ij:1}
A.bz.prototype={
gn(a){return B.a_},
$ij:1}
A.bA.prototype={
gn(a){return B.a0},
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ij:1}
A.bB.prototype={
gn(a){return B.a1},
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ij:1}
A.bC.prototype={
gn(a){return B.a2},
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ij:1}
A.bD.prototype={
gn(a){return B.a4},
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ij:1}
A.bE.prototype={
gn(a){return B.a5},
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ij:1}
A.aP.prototype={
gn(a){return B.a6},
gk(a){return a.length},
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ij:1}
A.bF.prototype={
gn(a){return B.a7},
gk(a){return a.length},
h(a,b){A.E(b)
A.ah(b,a,a.length)
return a[b]},
$ij:1}
A.b2.prototype={}
A.b3.prototype={}
A.b4.prototype={}
A.b5.prototype={}
A.O.prototype={
i(a){return A.bb(v.typeUniverse,this,a)},
E(a){return A.dV(v.typeUniverse,this,a)}}
A.bR.prototype={}
A.cB.prototype={
j(a){return A.C(this.a,null)}}
A.bQ.prototype={
j(a){return this.a}}
A.aw.prototype={}
A.b1.prototype={
gu(a){var t=this,s=new A.ae(t,t.r,t.$ti.i("ae<1>"))
s.c=t.e
return s},
gk(a){return this.a},
ac(a,b){var t
if((b&1073741823)===b){t=this.c
if(t==null)return!1
return u.L.a(t[b])!=null}else return this.aO(b)},
aO(a){var t=this.d
if(t==null)return!1
return this.ap(t[B.c.gq(a)&1073741823],a)>=0},
l(a,b){var t,s,r=this
r.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.am(t==null?r.b=A.d4():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.am(s==null?r.c=A.d4():s,b)}else return r.aL(b)},
aL(a){var t,s,r,q=this
q.$ti.c.a(a)
t=q.d
if(t==null)t=q.d=A.d4()
s=J.I(a)&1073741823
r=t[s]
if(r==null)t[s]=[q.a5(a)]
else{if(q.ap(r,a)>=0)return!1
r.push(q.a5(a))}return!0},
D(a){var t=this
if(t.a>0){t.b=t.c=t.d=t.e=t.f=null
t.a=0
t.ar()}},
am(a,b){this.$ti.c.a(b)
if(u.L.a(a[b])!=null)return!1
a[b]=this.a5(b)
return!0},
ar(){this.r=this.r+1&1073741823},
a5(a){var t,s=this,r=new A.bU(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.ar()
return r},
ap(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.al(a[s].a,b))return s
return-1}}
A.bU.prototype={}
A.ae.prototype={
gp(){var t=this.d
return t==null?this.$ti.c.a(t):t},
m(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.b(A.M(r))
else if(s==null){t.d=null
return!1}else{t.d=t.$ti.i("1?").a(s.a)
t.c=s.b
return!0}},
$ia0:1}
A.f.prototype={
gu(a){return new A.U(a,this.gk(a),A.a8(a).i("U<f.E>"))},
A(a,b){return this.h(a,b)},
gah(a){return this.gk(a)!==0},
az(a,b){var t,s
A.a8(a).i("x(f.E)").a(b)
t=this.gk(a)
for(s=0;s<t;++s){if(b.$1(this.h(a,s)))return!0
if(t!==this.gk(a))throw A.b(A.M(a))}return!1},
aD(a,b,c){var t=A.a8(a)
return new A.J(a,t.E(c).i("1(f.E)").a(b),t.i("@<f.E>").E(c).i("J<1,2>"))},
j(a){return A.cU(a,"[","]")},
$ic:1,
$ih:1}
A.D.prototype={
P(a,b){var t,s,r,q=A.F(this)
q.i("~(D.K,D.V)").a(b)
for(t=this.gS(),t=t.gu(t),q=q.i("D.V");t.m();){s=t.gp()
r=this.h(0,s)
b.$2(s,r==null?q.a(r):r)}},
gk(a){var t=this.gS()
return t.gk(t)},
gR(a){var t=this.gS()
return t.gR(t)},
j(a){return A.dA(this)},
$iaL:1}
A.ck.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.o(a)
s.a=(s.a+=t)+": "
t=A.o(b)
s.a+=t},
$S:3}
A.ar.prototype={
I(a,b){var t,s,r
this.$ti.i("c<1>").a(b)
for(t=A.fa(b,b.r,b.$ti.c),s=t.$ti.c;t.m();){r=t.d
this.l(0,r==null?s.a(r):r)}},
j(a){return A.cU(this,"{","}")},
$ic:1,
$id1:1}
A.b7.prototype={}
A.bS.prototype={
h(a,b){var t,s=this.b
if(s==null)return this.c.h(0,b)
else if(typeof b!="string")return null
else{t=s[b]
return typeof t=="undefined"?this.aT(b):t}},
gk(a){return this.b==null?this.c.a:this.W().length},
gR(a){return this.gk(0)===0},
gS(){if(this.b==null){var t=this.c
return new A.ad(t,A.F(t).i("ad<1>"))}return new A.bT(this)},
P(a,b){var t,s,r,q,p=this
u.B.a(b)
if(p.b==null)return p.c.P(0,b)
t=p.W()
for(s=0;s<t.length;++s){r=t[s]
q=p.b[r]
if(typeof q=="undefined"){q=A.cE(p.a[r])
p.b[r]=q}b.$2(r,q)
if(t!==p.c)throw A.b(A.M(p))}},
W(){var t=u.Q.a(this.c)
if(t==null)t=this.c=A.w(Object.keys(this.a),u.s)
return t},
aT(a){var t
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
t=A.cE(this.a[a])
return this.b[a]=t}}
A.bT.prototype={
gk(a){return this.a.gk(0)},
A(a,b){var t=this.a
if(t.b==null)t=t.gS().A(0,b)
else{t=t.W()
if(!(b>=0&&b<t.length))return A.i(t,b)
t=t[b]}return t},
gu(a){var t=this.a
if(t.b==null){t=t.gS()
t=t.gu(t)}else{t=t.W()
t=new J.aa(t,t.length,A.B(t).i("aa<1>"))}return t}}
A.bi.prototype={}
A.bk.prototype={}
A.aI.prototype={
j(a){var t=A.bn(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+t}}
A.bv.prototype={
j(a){return"Cyclic error in JSON stringify"}}
A.cf.prototype={
b0(a,b){var t=A.fT(a,this.gb1().a)
return t},
b3(a,b){var t=A.f9(a,this.gb4().b,null)
return t},
gb4(){return B.T},
gb1(){return B.S}}
A.ch.prototype={}
A.cg.prototype={}
A.cy.prototype={
aI(a){var t,s,r,q,p,o,n=a.length
for(t=this.c,s=0,r=0;r<n;++r){q=a.charCodeAt(r)
if(q>92){if(q>=55296){p=q&64512
if(p===55296){o=r+1
o=!(o<n&&(a.charCodeAt(o)&64512)===56320)}else o=!1
if(!o)if(p===56320){p=r-1
p=!(p>=0&&(a.charCodeAt(p)&64512)===55296)}else p=!1
else p=!0
if(p){if(r>s)t.a+=B.d.V(a,s,r)
s=r+1
p=A.v(92)
t.a+=p
p=A.v(117)
t.a+=p
p=A.v(100)
t.a+=p
p=q>>>8&15
p=A.v(p<10?48+p:87+p)
t.a+=p
p=q>>>4&15
p=A.v(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.v(p<10?48+p:87+p)
t.a+=p}}continue}if(q<32){if(r>s)t.a+=B.d.V(a,s,r)
s=r+1
p=A.v(92)
t.a+=p
switch(q){case 8:p=A.v(98)
t.a+=p
break
case 9:p=A.v(116)
t.a+=p
break
case 10:p=A.v(110)
t.a+=p
break
case 12:p=A.v(102)
t.a+=p
break
case 13:p=A.v(114)
t.a+=p
break
default:p=A.v(117)
t.a+=p
p=A.v(48)
t.a=(t.a+=p)+p
p=q>>>4&15
p=A.v(p<10?48+p:87+p)
t.a+=p
p=q&15
p=A.v(p<10?48+p:87+p)
t.a+=p
break}}else if(q===34||q===92){if(r>s)t.a+=B.d.V(a,s,r)
s=r+1
p=A.v(92)
t.a+=p
p=A.v(q)
t.a+=p}}if(s===0)t.a+=a
else if(s<n)t.a+=B.d.V(a,s,n)},
a4(a){var t,s,r,q
for(t=this.a,s=t.length,r=0;r<s;++r){q=t[r]
if(a==null?q==null:a===q)throw A.b(new A.bv(a,null))}B.a.l(t,a)},
a_(a){var t,s,r,q,p=this
if(p.aH(a))return
p.a4(a)
try{t=p.b.$1(a)
if(!p.aH(t)){r=A.dv(a,null,p.gau())
throw A.b(r)}r=p.a
if(0>=r.length)return A.i(r,-1)
r.pop()}catch(q){s=A.ej(q)
r=A.dv(a,s,p.gau())
throw A.b(r)}},
aH(a){var t,s,r=this
if(typeof a=="number"){if(!isFinite(a))return!1
r.c.a+=B.b.j(a)
return!0}else if(a===!0){r.c.a+="true"
return!0}else if(a===!1){r.c.a+="false"
return!0}else if(a==null){r.c.a+="null"
return!0}else if(typeof a=="string"){t=r.c
t.a+='"'
r.aI(a)
t.a+='"'
return!0}else if(u.j.b(a)){r.a4(a)
r.bl(a)
t=r.a
if(0>=t.length)return A.i(t,-1)
t.pop()
return!0}else if(a instanceof A.D){r.a4(a)
s=r.bm(a)
t=r.a
if(0>=t.length)return A.i(t,-1)
t.pop()
return s}else return!1},
bl(a){var t,s,r=this.c
r.a+="["
t=J.Y(a)
if(t.gah(a)){this.a_(t.h(a,0))
for(s=1;s<t.gk(a);++s){r.a+=","
this.a_(t.h(a,s))}}r.a+="]"},
bm(a){var t,s,r,q,p,o,n=this,m={}
if(a.gR(a)){n.c.a+="{}"
return!0}t=a.gk(a)*2
s=A.cZ(t,null,!1,u.X)
r=m.a=0
m.b=!0
a.P(0,new A.cz(m,s))
if(!m.b)return!1
q=n.c
q.a+="{"
for(p='"';r<t;r+=2,p=',"'){q.a+=p
n.aI(A.a6(s[r]))
q.a+='":'
o=r+1
if(!(o<t))return A.i(s,o)
n.a_(s[o])}q.a+="}"
return!0}}
A.cz.prototype={
$2(a,b){var t,s
if(typeof a!="string")this.a.b=!1
t=this.b
s=this.a
B.a.t(t,s.a++,a)
B.a.t(t,s.a++,b)},
$S:3}
A.cx.prototype={
gau(){var t=this.c.a
return t.charCodeAt(0)==0?t:t}}
A.l.prototype={}
A.be.prototype={
j(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.bn(t)
return"Assertion failed"}}
A.aX.prototype={}
A.R.prototype={
ga7(){return"Invalid argument"+(!this.a?"(s)":"")},
ga6(){return""},
j(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+A.o(q),o=t.ga7()+r+p
if(!t.a)return o
return o+t.ga6()+": "+A.bn(t.gaf())},
gaf(){return this.b}}
A.aS.prototype={
gaf(){return A.m(this.b)},
ga7(){return"RangeError"},
ga6(){var t,s=this.e,r=this.f
if(s==null)t=r!=null?": Not less than or equal to "+A.o(r):""
else if(r==null)t=": Not greater than or equal to "+A.o(s)
else if(r>s)t=": Not in inclusive range "+A.o(s)+".."+A.o(r)
else t=r<s?": Valid value range is empty":": Only valid value is "+A.o(s)
return t}}
A.bo.prototype={
gaf(){return A.E(this.b)},
ga7(){return"RangeError"},
ga6(){if(A.E(this.b)<0)return": index must not be negative"
var t=this.f
if(t===0)return": no indices are valid"
return": index should be less than "+t},
gk(a){return this.f}}
A.aZ.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.bO.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.bL.prototype={
j(a){return"Bad state: "+this.a}}
A.bj.prototype={
j(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.bn(t)+"."}}
A.aV.prototype={
j(a){return"Stack Overflow"},
$il:1}
A.t.prototype={
j(a){var t=this.a,s=""!==t?"FormatException: "+t:"FormatException"
return s}}
A.c.prototype={
gk(a){var t,s=this.gu(this)
for(t=0;s.m();)++t
return t},
A(a,b){var t,s
A.d_(b,"index")
t=this.gu(this)
for(s=b;t.m();){if(s===0)return t.gp();--s}throw A.b(A.cT(b,b-s,this,"index"))},
j(a){return A.eR(this,"(",")")}}
A.aQ.prototype={
gq(a){return A.k.prototype.gq.call(this,0)},
j(a){return"null"}}
A.k.prototype={$ik:1,
H(a,b){return this===b},
gq(a){return A.bH(this)},
j(a){return"Instance of '"+A.bI(this)+"'"},
gn(a){return A.h5(this)},
toString(){return this.j(this)}}
A.cr.prototype={}
A.as.prototype={
gk(a){return this.a.length},
j(a){var t=this.a
return t.charCodeAt(0)==0?t:t},
$if3:1}
A.cc.prototype={}
A.bl.prototype={
T(){var t=this
return A.cj(["areaMultiplier",t.a,"aspects",t.b,"angleMinDeg",t.c,"angleMaxDeg",t.d,"speedMin",t.e,"speedMax",t.f,"accelMin",t.r,"accelMax",t.w,"collideWithEachOther",t.x,"spinDegPerSec",t.y],u.N,u.z)}}
A.c0.prototype={
$1(a){return A.W(a)},
$S:7}
A.cm.prototype={
T(){return A.cj(["size",this.a,"showFace",this.b],u.N,u.z)}}
A.c2.prototype={
T(){var t,s=this,r=A.dx(u.N,u.z)
r.t(0,"borderWidth",s.a)
r.t(0,"brightness",s.b)
r.t(0,"shadowBrightness",s.c)
t=s.d
if(t!=null&&t.length!==0)r.t(0,"color",t)
return r}}
A.c3.prototype={
T(){var t=this
return A.cj(["startHintEnabled",t.a,"idleSpeedMultiplier",t.b,"idleEnemiesMove",t.c,"speedRampSeconds",t.d,"jumpEnabled",t.e,"jumpDurationSec",t.f,"jumpCooldownSec",t.r,"jumpScale",t.w,"helmetEnabled",t.x,"helmetInvulnSec",t.y,"startInvulnSec",t.z,"heartbeatHaptic",t.Q,"timerHaptic",t.as,"timerHapticStyle",t.at,"timerHapticStyle5",t.ax,"timerHapticStyle10",t.ay,"hudSpeedScaleMax",t.ch,"wallsKillPlayer",t.CW],u.N,u.z)}}
A.bw.prototype={}
A.d.prototype={
K(a,b){return new A.d(this.a+b.a,this.b+b.b)},
U(a,b){return new A.d(this.a-b.a,this.b-b.b)},
a1(a,b){return new A.d(this.a*b,this.b*b)},
gb2(){var t=this.a,s=this.b
return Math.sqrt(t*t+s*s)}}
A.cq.prototype={}
A.N.prototype={
gO(){var t=this
return new A.d((t.a+t.c)/2,(t.b+t.d)/2)},
X(a){var t=this
return t.a<a.c&&t.c>a.a&&t.b<a.d&&t.d>a.b}}
A.cM.prototype={
$1(a){var t,s,r
A.a6(a)
try{t=A.dx(u.N,u.z)
J.ex(t,"ok",!0)
J.ey(t,A.hj(u.a.a(B.n.b0(a,null))))
s=B.n.b3(t,null)
return s}catch(r){return'{"ok":false}'}},
$S:8}
A.bJ.prototype={
aR(){var t=this.a
t^=t<<13
t^=t>>>17
return this.a=(t^t<<5)>>>0},
C(){var t=this.a
t^=t<<13
t^=t>>>17
t=(t^t<<5)>>>0
this.a=t
return t/4294967296},
ba(a){if(a<=0)throw A.b(A.eC(a,null,null))
return B.b.ae(this.aR()/4294967296*a)},
$ieZ:1}
A.cP.prototype={
$0(){var t=this.a
return t.c>0||t.d>0},
$S:9}
A.cO.prototype={
$0(){var t,s,r,q=this
if(q.b.$0())return
t=q.c
s=!(t.a.d.CW&&t.ai())
if(s&&!t.bb())return
r=q.a
if(r.a){r.a=!1
r.d=Math.max(0,q.d.d.y)
if(s)t.bc()}else r.b=!0},
$S:10}
A.c_.prototype={}
A.a3.prototype={}
A.bm.prototype={
gO(){var t=this.a
return new A.d(t.a+this.y*0.5,t.b+this.z*0.5)},
aJ(a){this.a=new A.d(a.a-this.y*0.5,a.b-this.z*0.5)},
gM(){var t=this.CW*3.141592653589793/180
return new A.d(Math.cos(t),Math.sin(t))},
gN(){var t=this.CW*3.141592653589793/180
return new A.d(-Math.sin(t),Math.cos(t))},
gad(){var t=this,s=t.y*0.5,r=t.z*0.5,q=new A.c1(t.gO(),t.gM(),t.gN()),p=-s,o=-r
return A.w([q.$2(p,o),q.$2(s,o),q.$2(s,r),q.$2(p,r)],u.M)},
gG(){var t,s,r,q,p=this.gad(),o=B.a.gF(p).a,n=B.a.gF(p).a,m=B.a.gF(p).b,l=B.a.gF(p).b
for(t=0;t<4;++t){s=p[t]
r=s.a
if(r<o)o=r
if(r>n)n=r
q=s.b
if(q<m)m=q
if(q>l)l=q}return new A.N(o,m,n,l)},
Y(a){var t=this,s=t.gO(),r=t.gM(),q=t.gN(),p=a.a,o=a.b,n=s.a*p+s.b*o,m=t.y*0.5*Math.abs(p*r.a+o*r.b)+t.z*0.5*Math.abs(p*q.a+o*q.b)
return new A.b6(n-m,n+m)},
a2(a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0
for(t=[B.h,B.f,this.gM(),this.gN()],s=a1.a,r=a1.c,q=(s+r)/2,p=a1.b,o=a1.d,n=(p+o)/2,s=(r-s)/2,p=(o-p)/2,o=a2.a,r=a2.b,m=0,l=1,k=0;k<4;++k){j=t[k]
i=this.Y(j)
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
aE(a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[B.h,B.f,b.gM(),b.gN()],a0=a3.gO(),a1=(a3.c-a3.a)*0.5,a2=(a3.d-a3.b)*0.5
for(t=a0.a,s=a0.b,r=b.y*0.5,q=b.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.d(l,k)
g=b.Y(h)
f=t*l+s*k
e=a1*Math.abs(l)+a2*Math.abs(k)
d=Math.min(g.b,f+e)-Math.max(g.a,f-e)
if(d<=0)return null
if(d<p){c=b.a
o=(c.a+r-t)*l+(c.b+q-s)*k>=0?h:new A.d(-l,-k)
p=d}}if(o==null)return null
return o.a1(0,p+0.5)},
b9(a0){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=this,a=[b.gM(),b.gN(),a0.gM(),a0.gN()]
for(t=b.y*0.5,s=a0.y*0.5,r=b.z*0.5,q=a0.z*0.5,p=1/0,o=null,n=0;n<4;++n){m=a[n]
l=m.a
k=m.b
j=l*l+k*k
if(j<1e-12)continue
i=1/Math.sqrt(j)
l*=i
k*=i
h=new A.d(l,k)
g=b.Y(h)
f=a0.Y(h)
e=Math.min(g.b,f.b)-Math.max(g.a,f.a)
if(e<=0)return null
if(e<p){d=b.a
c=a0.a
o=(d.a+t-(c.a+s))*l+(d.b+r-(c.b+q))*k>=0?h:new A.d(-l,-k)
p=e}}if(o==null)return null
return o.a1(0,p+0.5)},
J(a){var t,s,r,q,p,o=a.a,n=a.b,m=o*o+n*n
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
A.c1.prototype={
$2(a,b){var t=this.a,s=this.b,r=this.c
return new A.d(t.a+s.a*a+r.a*b,t.b+s.b*a+r.b*b)},
$S:11}
A.c4.prototype={
bk(a){var t,s=this,r=!0
if(isFinite(a))if(s.a.d.e)if(!(s.r>0)){r=s.x
r=Math.max(0,r-a)>0}if(r)return!1
r=s.a.d
s.r=Math.max(0.12,r.f)
t=r.r
r=isFinite(t)?t:2
s.x=a+Math.max(0,r)*1000
s.at.D(0)
s.as.D(0)
s.a8()
return!0},
bf(a){var t=this,s=t.r
if(s<=0)return
s=Math.max(0,s-a)
t.r=s
if(s>0)t.a8()
else t.at.D(0)},
aY(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,b0=a9.a,b1=b0.a,b2=A.dz(b1.b,!0,u.i),b3=A.B(b2),b4=b3.i("b_<1>"),b5=A.dy(new A.b_(b2,b3.i("x(1)").a(new A.c9()),b4),b4.i("c.E"))
if(b5.length===0)B.a.I(b5,B.o)
t=b5.length
s=Math.max(t,4)
b2=u.S
b3=J.cV(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.a0(r,4)
b4=a9.c
B.a.ak(b3,b4)
q=A.dI(b3,0,A.e8(t,"count",b2),A.B(b3).c).aF(0)
b3=J.cV(s,b2)
for(r=0;r<s;++r)b3[r]=B.c.a0(r,4)
B.a.ak(b3,b4)
p=A.dI(b3,0,A.e8(t,"count",b2),A.B(b3).c).aF(0)
o=A.w([],u.u)
for(b2=b1.e,b3=b1.f,n=b1.r,m=b1.w,l=b1.y,b0=b0.b.a*1.2,b0*=b0,k=b1.a,j=b1.c,b1=b1.d,r=0;r<t;++r){if(!(r<b5.length))return A.i(b5,r)
i=b5[r]
if(!(r<q.length))return A.i(q,r)
h=q[r]
if(!(r<p.length))return A.i(p,r)
g=p[r]
f=Math.max(1,b0)*B.b.v(k,0.2,20)
e=B.b.v(i,0.05,50)
d=Math.sqrt(f/e)
c=Math.sqrt(f*e)
b=a9.aU(g,d,c)
a=Math.min(j,b1)
a0=Math.max(j,b1)
a1=a+b4.C()*(a0-a)+90*h
a2=(a1>=360?a1-360:a1)*3.141592653589793/180
a3=Math.min(b2,b3)
a4=Math.max(b2,b3)
a5=a3+b4.C()*(a4-a3)
a3=Math.min(n,m)
a4=Math.max(n,m)
i=b4.C()
h=Math.cos(a2)
g=Math.sin(a2)
a6=Math.abs(l)>0.01
a7=a6?b4.C()*360:0
a8=new A.bm(b,new A.d(h*a5,g*a5),c,d,a5,a3+i*(a4-a3),a7,l)
if(a6)a9.aS(a8)
b4.C()
b4.C()
b4.C()
b4.C()
B.a.l(o,a8)}return o},
bd(a){var t,s,r,q,p,o,n,m,l,k,j,i,h=u.j
if(!h.b(a)||J.a9(a)!==this.f.length)throw A.b(B.E)
for(t=this.f,s=J.Y(a),r=0;r<t.length;++r){q=s.h(a,r)
if(h.b(q)){p=J.Y(q)
p=p.gk(q)!==5||p.az(q,new A.ca())}else p=!0
if(p)throw A.b(B.C)
if(!(r<t.length))return A.i(t,r)
o=t[r]
p=J.Y(q)
n=A.W(p.h(q,0))
m=A.W(p.h(q,1))
l=A.W(p.h(q,2))
k=A.W(p.h(q,3))
j=A.W(p.h(q,4))
p=o.ay
if(Math.abs(Math.sqrt(l*l+k*k)-p)>Math.max(0.0001,p*0.000001)||Math.abs(j)>1e9)throw A.b(B.N)
o.a=new A.d(n,m)
o.b=new A.d(l,k)
o.CW=j
i=o.gG()
if(i.a<-0.0001||i.b<-0.0001||i.c>380.0001||i.d>380.0001)throw A.b(B.H)}},
aS(a){var t,s,r,q,p,o,n,m,l,k,j,i
for(t=this.d,s=380-t,r=0;r<3;++r){q=a.gad()
p=A.B(q)
o=p.i("e(1)")
p=p.i("J<1,e>")
n=new A.J(q,o.a(new A.c5()),p).Z(0,B.j)
m=new A.J(q,o.a(new A.c6()),p).Z(0,B.k)
l=new A.J(q,o.a(new A.c7()),p).Z(0,B.j)
k=new A.J(q,o.a(new A.c8()),p).Z(0,B.k)
if(n<t)j=t-n
else j=m>s?s-m:0
if(l<t)i=t-l
else i=k>s?s-k:0
if(j===0&&i===0)break
p=a.a
a.a=new A.d(p.a+j,p.b+i)}},
bh(a5,a6,a7){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this,a2=B.b.v(a5,0,0.05),a3=B.c.v(1,0,2),a4=B.b.v(a6,0,3600)
for(t=a1.f,s=t.length,r=a1.a,q=r.b.a*1.2,p=0,o=0;o<t.length;t.length===s||(0,A.bc)(t),++o){n=t[o]
m=B.b.v((n.ay+n.ch*a4)*a3,0,4000)
l=n.b
k=l.a
l=l.b
j=Math.sqrt(k*k+l*l)
if(j<0.000001)i=B.V
else{l=n.b
i=new A.d(l.a/j,l.b/j)}n.b=new A.d(i.a*m,i.b*m)
l=n.cx
k=Math.abs(l)
h=Math.max(1,B.b.b_(k*a2/5))
for(k=k>0.01,g=a2/h,l=l*a2/h,f=0;f<h;++f){e=n.b
d=e.a*g
e=e.b*g
if(k)n.CW+=l
if(a7&&!(a1.r>0)){c=a1.e
c===$&&A.a_()
b=c.a
c=c.b
a=n.a2(new A.N(b,c,b+q,c+q),new A.d(-d,-e))}else a=null
c=n.a
b=a==null
if(b)a0=1
else a0=a===0?0:Math.min(1,a+1e-7)
n.a=new A.d(c.a+d*a0,c.b+e*a0)
if(a1.a3(n))++p
if(!b)break}}if(r.a.x)a1.aW()
a1.bg(a2)
return new A.c_()},
b8(a,b){var t,s,r,q,p,o,n,m,l,k,j=this,i=a.a,h=!0
if(isFinite(i)){t=a.b
if(isFinite(t))i=i===0&&t===0
else i=h}else i=h
if(i)return
i=j.e
i===$&&A.a_()
s=i.K(0,a)
h=j.a
if(!h.d.CW){t=j.d
r=Math.max(t,380-t-h.b.a*1.2)
s=new A.d(B.b.v(s.a,t,r),B.b.v(s.b,t,r))}q=s.U(0,i)
t=j.e
r=t.a
t=t.b
h=h.b.a*1.2
p=new A.N(r,t,r+h,t+h)
o=1
if(b&&!(j.r>0))for(h=j.f,t=h.length,n=0;n<h.length;h.length===t||(0,A.bc)(h),++n){m=h[n].a2(p,q)
if(m!=null){r=m===0?0:m+1e-7
o=Math.min(o,r)}}h=i.K(0,q.a1(0,Math.min(1,o)))
j.e=h
l=h.U(0,i).gb2()
if(l===0)return
j.y+=l
if(j.r>0){for(i=j.f,k=0;k<i.length;++k)if(i[k].a2(p,q)!=null)j.an(k)}else j.ao()},
bg(a){var t=this,s=t.Q,r=A.B(s).i("x(1)").a(new A.cb(a))
s.$flags&1&&A.aA(s,16)
B.a.aV(s,r,!0)
if(t.r>0)t.a8()
else t.ao()},
a8(){var t,s,r,q,p,o=this
if(!(o.r>0))return
t=o.e
t===$&&A.a_()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.N(s,t,s+r,t+r)
for(t=o.f,s=o.at,p=0;p<t.length;++p){if(s.ac(0,p))continue
if(!(p<t.length))return A.i(t,p)
if(!q.X(t[p].gG()))continue
o.an(p)}},
an(a){var t,s,r,q=this
if(!q.at.l(0,a))return;++q.z
t=q.e
t===$&&A.a_()
s=q.a.b.a*1.2/2
r=t.K(0,new A.d(s,s))
s=q.f
if(!(a<s.length))return A.i(s,a)
r.K(0,s[a].gG().gO())
B.a.l(q.Q,new A.a3())},
ao(){var t,s,r,q,p,o,n,m=this
if(m.r>0)return
t=m.e
t===$&&A.a_()
s=t.a
t=t.b
r=m.a.b.a*1.2
q=new A.N(s,t,s+r,t+r)
p=A.cY(u.S)
for(t=m.f,s=m.as,r=m.Q,o=0;o<t.length;++o){n=A.eN(q,t[o].gG())
if(n<=0)continue
if(n<=14){s.l(0,o)
p.l(0,o)}else if(n>=22&&s.ac(0,o)){++m.z
if(!(o<t.length))return A.i(t,o)
t[o].gG()
if(!(o<t.length))return A.i(t,o)
t[o].gG()
B.a.l(r,new A.a3())}else if(s.ac(0,o))p.l(0,o)}s.D(0)
s.I(0,p)},
aA(){var t=this,s=t.d,r=Math.max(s,380-s-t.a.b.a*1.2),q=t.e
q===$&&A.a_()
t.e=new A.d(B.b.v(q.a,s,r),B.b.v(t.e.b,s,r))},
ai(){var t,s,r,q=this.e
q===$&&A.a_()
t=q.a
s=this.d
r=!0
if(!(t<=s)){q=q.b
if(!(q<=s)){r=this.a.b.a*1.2
s=380-s
q=t+r>=s||q+r>=s}else q=r}else q=r
return q},
bb(){var t,s,r,q,p,o=this
if(o.r>0)return!1
t=o.e
t===$&&A.a_()
s=t.a
t=t.b
r=o.a.b.a*1.2
q=new A.N(s,t,s+r,t+r)
for(t=o.f,s=t.length,p=0;p<t.length;t.length===s||(0,A.bc)(t),++p)if(t[p].aE(q)!=null)return!0
return!1},
bc(){var t,s,r,q,p,o,n,m=this.e
m===$&&A.a_()
t=m.a
m=m.b
s=this.a.b.a*1.2
r=new A.N(t,m,t+s,m+s)
for(m=this.f,t=m.length,q=0,p=0;p<m.length;m.length===t||(0,A.bc)(m),++p){o=m[p]
n=o.aE(r)
if(n==null)continue
s=o.a
o.a=new A.d(s.a+n.a,s.b+n.b)
o.J(n);++q}return q},
aU(a,b,c){var t,s,r,q,p,o,n,m,l,k,j=this,i=Math.max(8,j.d+2),h=A.cv(),g=A.cv(),f=A.cv(),e=A.cv()
switch(B.c.a0(a,4)){case 0:h.b=i
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
e.b=380-b-i}t=g.L()
s=h.L()
if(typeof t!=="number")return t.aj()
if(typeof s!=="number")return A.cH(s)
if(t<s){h.b=i
g.b=Math.max(i,380-c-i)}t=e.L()
s=f.L()
if(typeof t!=="number")return t.aj()
if(typeof s!=="number")return A.cH(s)
if(t<s){f.b=i
e.b=Math.max(i,380-b-i)}t=j.e
t===$&&A.a_()
s=t.a
t=t.b
r=j.a.b.a*1.2
q=r*0.6
p=new A.N(s-q,t-q,s+r+q,t+r+q)
for(t=j.c,o=0;o<12;++o){s=h.b
if(s===h)A.Q(A.aJ(""))
r=t.C()
q=g.b
if(q===g)A.Q(A.aJ(""))
n=h.b
if(n===h)A.Q(A.aJ(""))
if(typeof q!=="number")return q.U()
if(typeof n!=="number")return A.cH(n)
q=Math.max(1,q-n)
if(typeof s!=="number")return s.K()
m=s+r*q
s=f.b
if(s===f)A.Q(A.aJ(""))
r=t.C()
q=e.b
if(q===e)A.Q(A.aJ(""))
n=f.b
if(n===f)A.Q(A.aJ(""))
if(typeof q!=="number")return q.U()
if(typeof n!=="number")return A.cH(n)
q=Math.max(1,q-n)
if(typeof s!=="number")return s.K()
l=s+r*q
k=new A.d(m,l)
if(!new A.N(m,l,m+c,l+b).X(p))return k}return new A.d(J.dh(h.L(),i,380-c-i),J.dh(f.L(),i,380-b-i))},
a3(a1){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a1.gO()
for(t=this.d,s=380-t,r=a1.y*0.5,q=a1.z*0.5,p=!1,o=0;o<3;++o){n=a0.a
m=a0.b
a1.a=new A.d(n-r,m-q)
l=a1.gad()
k=B.a.gF(l).a
j=B.a.gF(l).a
i=B.a.gF(l).b
h=B.a.gF(l).b
for(g=0;g<4;++g){f=l[g]
e=f.a
if(e<k)k=e
if(e>j)j=e
d=f.b
if(d<i)i=d
if(d>h)h=d}c=!0
if(k<t){b=t-k
a1.J(B.h)
p=c}else if(j>s){b=s-j
a1.J(B.W)
p=c}else b=0
if(i<t){a=t-i
a1.J(B.f)
p=c}else if(h>s){a=s-h
a1.J(B.U)
p=c}else a=0
if(b===0&&a===0)break
a0=new A.d(n+b,m+a)}a1.aJ(a0)
return p},
aW(){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f
for(t=this.f,s=0,r=0;r<t.length;r=q)for(q=r+1,p=q;o=t.length,p<o;++p){if(!(r<o))return A.i(t,r)
n=t[r]
m=t[p]
if(!n.gG().X(m.gG()))continue
l=n.b9(m)
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
n.J(l)
m.J(new A.d(-o,-j))
this.a3(n)
this.a3(m)}return s}}
A.c9.prototype={
$1(a){A.dY(a)
return isFinite(a)&&a>0.05&&a<50},
$S:12}
A.ca.prototype={
$1(a){return typeof a!="number"||!isFinite(a)},
$S:13}
A.c5.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.c6.prototype={
$1(a){return u.n.a(a).a},
$S:0}
A.c7.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.c8.prototype={
$1(a){return u.n.a(a).b},
$S:0}
A.cb.prototype={
$1(a){return!((u.W.a(a).b+=this.a)<0.42)},
$S:14};(function aliases(){var t=J.a2.prototype
t.aK=t.j})();(function installTearOffs(){var t=hunkHelpers._static_0,s=hunkHelpers._static_1,r=hunkHelpers.installStaticTearOff
t(A,"fS","eX",1)
s(A,"h0","fy",2)
r(A,"hh",2,null,["$1$2","$2"],["ee",function(a,b){return A.ee(a,b,u.H)}],4,0)
r(A,"hg",2,null,["$1$2","$2"],["ed",function(a,b){return A.ed(a,b,u.H)}],4,0)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.k,null)
r(A.k,[A.cW,J.bq,A.aU,J.aa,A.l,A.f,A.cp,A.c,A.U,A.b0,A.z,A.aY,A.ag,A.y,A.cs,A.cl,A.D,A.ci,A.aK,A.cu,A.O,A.bR,A.cB,A.ar,A.bU,A.ae,A.bi,A.bk,A.cy,A.aV,A.t,A.aQ,A.cr,A.as,A.cc,A.bl,A.cm,A.c2,A.c3,A.bw,A.d,A.cq,A.N,A.bJ,A.c_,A.a3,A.bm,A.c4])
r(J.bq,[J.bs,J.aE,J.aG,J.aF,J.aH,J.an,J.ao])
r(J.aG,[J.a2,J.n,A.ap,A.aO])
r(J.a2,[J.bG,J.at,J.a1])
s(J.br,A.aU)
s(J.cd,J.n)
r(J.an,[J.aD,J.bt])
r(A.l,[A.ac,A.aX,A.bu,A.bP,A.bK,A.bQ,A.aI,A.be,A.R,A.aZ,A.bO,A.bL,A.bj])
s(A.au,A.f)
s(A.aB,A.au)
r(A.c,[A.aC,A.b_])
r(A.aC,[A.A,A.ad])
r(A.A,[A.aW,A.J,A.bT])
s(A.av,A.ag)
s(A.b6,A.av)
r(A.y,[A.bp,A.bg,A.bh,A.bN,A.cI,A.cK,A.c0,A.cM,A.c9,A.ca,A.c5,A.c6,A.c7,A.c8,A.cb])
s(A.ab,A.bp)
r(A.bg,[A.cn,A.cP,A.cO])
s(A.aR,A.aX)
r(A.bN,[A.bM,A.am])
r(A.D,[A.T,A.bS])
r(A.bh,[A.ce,A.cJ,A.ck,A.cz,A.c1])
r(A.aO,[A.bx,A.aq])
r(A.aq,[A.b2,A.b4])
s(A.b3,A.b2)
s(A.aM,A.b3)
s(A.b5,A.b4)
s(A.aN,A.b5)
r(A.aM,[A.by,A.bz])
r(A.aN,[A.bA,A.bB,A.bC,A.bD,A.bE,A.aP,A.bF])
s(A.aw,A.bQ)
s(A.b7,A.ar)
s(A.b1,A.b7)
s(A.bv,A.aI)
s(A.cf,A.bi)
r(A.bk,[A.ch,A.cg])
s(A.cx,A.cy)
r(A.R,[A.aS,A.bo])
t(A.au,A.aY)
t(A.b2,A.f)
t(A.b3,A.z)
t(A.b4,A.f)
t(A.b5,A.z)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",e:"double",Z:"num",q:"String",x:"bool",aQ:"Null",h:"List",k:"Object",aL:"Map",p:"JSObject"},mangledNames:{},types:["e(d)","a()","@(@)","~(k?,k?)","0^(0^,0^)<Z>","@(@,q)","@(q)","e(@)","q(q)","x()","~()","d(e,e)","x(e)","x(@)","x(a3)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;":(a,b)=>c=>c instanceof A.b6&&a.b(c.a)&&b.b(c.b)}}
A.fo(v.typeUniverse,JSON.parse('{"a1":"a2","bG":"a2","at":"a2","hq":"ap","bs":{"x":[],"j":[]},"aE":{"j":[]},"aG":{"p":[]},"a2":{"p":[]},"n":{"h":["1"],"p":[],"c":["1"]},"br":{"aU":[]},"cd":{"n":["1"],"h":["1"],"p":[],"c":["1"]},"aa":{"a0":["1"]},"an":{"e":[],"Z":[]},"aD":{"e":[],"a":[],"Z":[],"j":[]},"bt":{"e":[],"Z":[],"j":[]},"ao":{"q":[],"j":[]},"ac":{"l":[]},"aB":{"f":["a"],"aY":["a"],"h":["a"],"c":["a"],"f.E":"a"},"aC":{"c":["1"]},"A":{"c":["1"]},"aW":{"A":["1"],"c":["1"],"c.E":"1","A.E":"1"},"U":{"a0":["1"]},"J":{"A":["2"],"c":["2"],"c.E":"2","A.E":"2"},"b_":{"c":["1"],"c.E":"1"},"b0":{"a0":["1"]},"au":{"f":["1"],"aY":["1"],"h":["1"],"c":["1"]},"b6":{"av":[],"ag":[]},"bp":{"y":[],"S":[]},"ab":{"y":[],"S":[]},"aR":{"l":[]},"bu":{"l":[]},"bP":{"l":[]},"y":{"S":[]},"bg":{"y":[],"S":[]},"bh":{"y":[],"S":[]},"bN":{"y":[],"S":[]},"bM":{"y":[],"S":[]},"am":{"y":[],"S":[]},"bK":{"l":[]},"T":{"D":["1","2"],"dw":["1","2"],"aL":["1","2"],"D.K":"1","D.V":"2"},"ad":{"c":["1"],"c.E":"1"},"aK":{"a0":["1"]},"av":{"ag":[]},"ap":{"p":[],"j":[]},"aO":{"p":[]},"bx":{"p":[],"j":[]},"aq":{"G":["1"],"p":[]},"aM":{"f":["e"],"h":["e"],"G":["e"],"p":[],"c":["e"],"z":["e"]},"aN":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"]},"by":{"f":["e"],"h":["e"],"G":["e"],"p":[],"c":["e"],"z":["e"],"j":[],"f.E":"e"},"bz":{"f":["e"],"h":["e"],"G":["e"],"p":[],"c":["e"],"z":["e"],"j":[],"f.E":"e"},"bA":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"],"j":[],"f.E":"a"},"bB":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"],"j":[],"f.E":"a"},"bC":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"],"j":[],"f.E":"a"},"bD":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"],"j":[],"f.E":"a"},"bE":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"],"j":[],"f.E":"a"},"aP":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"],"j":[],"f.E":"a"},"bF":{"f":["a"],"h":["a"],"G":["a"],"p":[],"c":["a"],"z":["a"],"j":[],"f.E":"a"},"bQ":{"l":[]},"aw":{"l":[]},"b1":{"ar":["1"],"d1":["1"],"c":["1"]},"ae":{"a0":["1"]},"f":{"h":["1"],"c":["1"]},"D":{"aL":["1","2"]},"ar":{"d1":["1"],"c":["1"]},"b7":{"ar":["1"],"d1":["1"],"c":["1"]},"bS":{"D":["q","@"],"aL":["q","@"],"D.K":"q","D.V":"@"},"bT":{"A":["q"],"c":["q"],"c.E":"q","A.E":"q"},"aI":{"l":[]},"bv":{"l":[]},"e":{"Z":[]},"a":{"Z":[]},"h":{"c":["1"]},"be":{"l":[]},"aX":{"l":[]},"R":{"l":[]},"aS":{"l":[]},"bo":{"l":[]},"aZ":{"l":[]},"bO":{"l":[]},"bL":{"l":[]},"bj":{"l":[]},"aV":{"l":[]},"as":{"f3":[]},"bJ":{"eZ":[]},"eQ":{"h":["a"],"c":["a"]},"f7":{"h":["a"],"c":["a"]},"f6":{"h":["a"],"c":["a"]},"eO":{"h":["a"],"c":["a"]},"f4":{"h":["a"],"c":["a"]},"eP":{"h":["a"],"c":["a"]},"f5":{"h":["a"],"c":["a"]},"eL":{"h":["e"],"c":["e"]},"eM":{"h":["e"],"c":["e"]}}'))
A.fn(v.typeUniverse,JSON.parse('{"aC":1,"au":1,"aq":1,"b7":1,"bi":2,"bk":2}'))
var u=(function rtii(){var t=A.bX
return{V:t("aB"),C:t("l"),Z:t("S"),t:t("ab<e>"),U:t("c<@>"),u:t("n<bm>"),l:t("n<a3>"),M:t("n<d>"),s:t("n<q>"),b:t("n<@>"),T:t("aE"),m:t("p"),g:t("a1"),p:t("G<@>"),j:t("h<@>"),a:t("aL<q,@>"),W:t("a3"),P:t("aQ"),K:t("k"),n:t("d"),J:t("hr"),F:t("+()"),N:t("q"),R:t("j"),o:t("at"),y:t("x"),i:t("e"),z:t("@"),S:t("a"),O:t("dp<aQ>?"),A:t("p?"),Q:t("h<@>?"),X:t("k?"),v:t("q?"),L:t("bU?"),c:t("x?"),I:t("e?"),w:t("a?"),x:t("Z?"),H:t("Z"),B:t("~(q,@)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.P=J.bq.prototype
B.a=J.n.prototype
B.c=J.aD.prototype
B.b=J.an.prototype
B.d=J.ao.prototype
B.Q=J.a1.prototype
B.R=J.aG.prototype
B.q=J.bG.prototype
B.i=J.at.prototype
B.k=new A.ab(A.hg(),u.t)
B.j=new A.ab(A.hh(),u.t)
B.l=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.r=function() {
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
B.x=function(getTagFallback) {
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
B.t=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.w=function(hooks) {
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
B.v=function(hooks) {
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
B.u=function(hooks) {
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

B.n=new A.cf()
B.e=new A.cp()
B.y=new A.cq()
B.z=new A.t("Invalid mobile enemy variation")
B.A=new A.t("tick duration")
B.B=new A.t("jump cooldown")
B.C=new A.t("start pose values")
B.D=new A.t("unfinished run")
B.E=new A.t("start pose count")
B.F=new A.t("run duration")
B.G=new A.t("Invalid mobile enemy pace")
B.H=new A.t("start pose bounds")
B.I=new A.t("events after death")
B.J=new A.t("event")
B.K=new A.t("move")
B.L=new A.t("move bounds")
B.M=new A.t("proof format")
B.N=new A.t("start pose speed")
B.O=new A.t("tick")
B.S=new A.cg(null)
B.T=new A.ch(null)
B.o=t([1,0.25,0.5,3],A.bX("n<e>"))
B.p=new A.bw(34.72,4.63,0.05,0.08)
B.f=new A.d(0,1)
B.U=new A.d(0,-1)
B.h=new A.d(1,0)
B.V=new A.d(1,1)
B.W=new A.d(-1,0)
B.X=A.P("hm")
B.Y=A.P("hn")
B.Z=A.P("eL")
B.a_=A.P("eM")
B.a0=A.P("eO")
B.a1=A.P("eP")
B.a2=A.P("eQ")
B.a3=A.P("k")
B.a4=A.P("f4")
B.a5=A.P("f5")
B.a6=A.P("f6")
B.a7=A.P("f7")})();(function staticFields(){$.cw=null
$.H=A.w([],A.bX("n<k>"))
$.dD=null
$.co=0
$.dF=A.fS()
$.dl=null
$.dk=null
$.eb=null
$.e6=null
$.eh=null
$.cG=null
$.cL=null
$.dd=null
$.cA=A.w([],A.bX("n<h<k>?>"))})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hp","ek",()=>A.ea("_$dart_dartClosure"))
t($,"ho","dg",()=>A.ea("_$dart_dartClosure_dartJSInterop"))
t($,"hE","ew",()=>A.w([new J.br()],A.bX("n<aU>")))
t($,"ht","em",()=>A.V(A.ct({
toString:function(){return"$receiver$"}})))
t($,"hu","en",()=>A.V(A.ct({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hv","eo",()=>A.V(A.ct(null)))
t($,"hw","ep",()=>A.V(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hz","es",()=>A.V(A.ct(void 0)))
t($,"hA","et",()=>A.V(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hy","er",()=>A.V(A.dJ(null)))
t($,"hx","eq",()=>A.V(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"hC","ev",()=>A.V(A.dJ(void 0)))
t($,"hB","eu",()=>A.V(function(){try{(void 0).$method$}catch(s){return s.message}}()))
t($,"hD","cQ",()=>A.ef(B.a3))
t($,"hs","el",()=>{A.eY()
return $.co})})();(function nativeSupport(){!function(){var t=function(a){var n={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.ap,SharedArrayBuffer:A.ap,ArrayBufferView:A.aO,DataView:A.bx,Float32Array:A.by,Float64Array:A.bz,Int16Array:A.bA,Int32Array:A.bB,Int8Array:A.bC,Uint16Array:A.bD,Uint32Array:A.bE,Uint8ClampedArray:A.aP,CanvasPixelArray:A.aP,Uint8Array:A.bF})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.aq.$nativeSuperclassTag="ArrayBufferView"
A.b2.$nativeSuperclassTag="ArrayBufferView"
A.b3.$nativeSuperclassTag="ArrayBufferView"
A.aM.$nativeSuperclassTag="ArrayBufferView"
A.b4.$nativeSuperclassTag="ArrayBufferView"
A.b5.$nativeSuperclassTag="ArrayBufferView"
A.aN.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$0=function(){return this()}
Function.prototype.$1$1=function(a){return this(a)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.he
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
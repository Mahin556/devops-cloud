```bash
controlplane:~$ curl -v www.google.com

* Host www.google.com:80 was resolved.
* IPv6: 2404:6800:4009:80c::2004
* IPv4: 142.251.220.68
*   Trying 142.251.220.68:80...
* Connected to www.google.com (142.251.220.68) port 80
> GET / HTTP/1.1
> Host: www.google.com
> User-Agent: curl/8.5.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Sat, 22 Nov 2025 16:54:19 GMT
< Expires: -1
< Cache-Control: private, max-age=0
< Content-Type: text/html; charset=ISO-8859-1
< Content-Security-Policy-Report-Only: object-src 'none';base-uri 'self';script-src 'nonce-J27nUVrhXi4b2QvLBNdF5Q' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-inline' https: http:;report-uri https://csp.withgoogle.com/csp/gws/other-hp
< P3P: CP="This is not a P3P policy! See g.co/p3phelp for more info."
< Server: gws
< X-XSS-Protection: 0
< X-Frame-Options: SAMEORIGIN
< Set-Cookie: __Secure-STRP=ADq1D7rwIJMzpF43_5LdKRRU7qd-9UorfJMOtrn3A5cbsIBDlSLNopPhvgN8LcU71J4NJkm00HpXpooBtiKSHHyWmECTj5fFsEaB; expires=Sat, 22-Nov-2025 16:59:19 GMT; path=/; domain=.google.com; Secure; SameSite=strict
< Set-Cookie: AEC=AaJma5u-mOYaHcoJLRqTXkDCHqgSk4RJnAFRwQDlXpD0pBT4itrlgUoNcA; expires=Thu, 21-May-2026 16:54:19 GMT; path=/; domain=.google.com; Secure; HttpOnly; SameSite=lax
< Set-Cookie: NID=526=mD0m63vqFtWMLjeadAF9sCfxEWMGx2NF7UBOq8gb8na0EwZNWInsw6acgypkP7vMrOIA3diZvYj9cOfF7_yLiysY8J5A6KSazv-Xnt7BHm_K8dzQJBhaDMLGOR9tsrTiG-VQhkvNBoBNVaJ2qQrV7waBq9NpHgVp0oDWZDfV2j0Sv6QhRi0ZRuvXgXCQfbvQdX3C2R3S7L0hMysdlpPw2qNpXiMG8EC52g; expires=Sun, 24-May-2026 16:54:19 GMT; path=/; domain=.google.com; HttpOnly
< Accept-Ranges: none
< Vary: Accept-Encoding
< Transfer-Encoding: chunked
< 
<!doctype html><html itemscope="" itemtype="http://schema.org/WebPage" lang="en-IN"><head><meta content="text/html; charset=UTF-8" http-equiv="Content-Type"><meta content="/images/branding/googleg/1x/googleg_standard_color_128dp.png" itemprop="image"><title>Google</title><script nonce="J27nUVrhXi4b2QvLBNdF5Q">(function(){var _g={kEI:'u-ohadaLGLuz4-EP2o-I2Qk',kEXPI:'0,4240045,48791,30022,16105,344796,247320,53830,5231208,386,36811624,25381059,65169,30635,9139,4599,328,6225,50575,13590,23254,3292,34513,28334,48279,5932,353,10700,7770,410,5870,7714,33385,3050,2,13472,7439,3,5,4,2255,2864,10620,12107,5683,3604,594,490,6244,13175,16547,15873,4808,1218,1,1549,2825,2,4527,1760,6437,9742,2646,103,4,1,1164,4926,12498,519,5031,9592,4913,792,591,2,1,1380,135,581,2774,2,193,151,260,161,5243,2,4205,3,3212,1264,2364,4874,4384,2,874,1842,389,5089,19,3007,17,779,792,3289,4,5386,256,5318,6,8203,12119,219,1031,4595,742,311,534,846,1200,2,12,16,415,1,87,1054,1769,1064,9,27,8,3055,1010,593,1154,4,7330,7041,3606,5,1031,82,389,4,299,163,2185,5,2708,1131,371,609,15,164,570,298,2707,1105,497,1951,36,2841,116,662,195,418,7,1767,4,7,1056,2,296,1622,515,1375,2,179,293,634,2424,452,675,130,882,238,4,82,2,691,4,1875,2,4021,1347,4,963,96,1553,4,4,1629,88,1,1,2,1134,809,1,543,235,870,204,1323,346,251,483,456,41,1,248,5,438,4,1367,1,2,189,2,2,24,85,180,8,14,92,231,3,517,374,184,5,37,207,35,2,671,3,2,2,2,738,723,3,588,380,918,343,9,129,400,81,10,106,98,215,212,801,9,1009,223,1442,458,1638,413,124,38,3,196,156,246,211,843,919,307,506,443,9,134,187,325,1339,284,1,2,154,5,30,154,277,985,1381,19,295,306,93,752,147,465,8,126,741,36,939,165,203,1781,87,127,5,40,178,39,318,6,301,537,826,122,256,111,24,891,4,70,586,1,2,662,1484,4,94,299,3,2,2,2,176,4,69,3,2,2,2,296,26,140,59,3,2,2,2,42,298,146,9,204,156,116,912,343,1338,5,5,20,16,163,597,760,9,16,209,150,53,134,91,5,12,295,578,60,395,129,211,399,1,2,248,372,182,75,104,87,337,104,585,133,578,14,3,398,1704,4,15,21033195,18488,5,2253,739,4,2960,3,2022,1215,5254,2,1562,3,391,9253,2763,2,765,1671,25,51,1143,3,3214,2,4,2,53,492,3615,100,2,419,297,87,275,282,3,88,615,35,517,6491119,890,2170374,12519152,1,450961,4,475265,65503,65432,1,3424',kBL:'Q8J7',kOPI:89978449};(function(){var a;((a=window.google)==null?0:a.stvsc)?google.kEI=_g.kEI:window.google=_g;}).call(this);})();(function(){google.sn='webhp';google.kHL='en-IN';google.rdn=false;})();(function(){
var g=this||self;function k(){return window.google&&window.google.kOPI||null};var l,m=[];function n(a){for(var b;a&&(!a.getAttribute||!(b=a.getAttribute("eid")));)a=a.parentNode;return b||l}function p(a){for(var b=null;a&&(!a.getAttribute||!(b=a.getAttribute("leid")));)a=a.parentNode;return b}function q(a){/^http:/i.test(a)&&window.location.protocol==="https:"&&(google.ml&&google.ml(Error("a"),!1,{src:a,glmm:1}),a="");return a}
```
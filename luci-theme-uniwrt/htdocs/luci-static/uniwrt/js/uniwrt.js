/*
 * luci-theme-uniwrt — UniWRT Portal shell behaviour
 * SPDX-License-Identifier: MIT
 *
 * Functional rules:
 *  - Prefer LuCI's real menu DOM so every installed/custom app keeps working.
 *  - Build the controller-style rail only once, after the menu exists.
 *  - Use a small recovery menu only if LuCI exposes no menu after a short wait.
 *  - Never re-render page content, forms, modals, CBI buttons, or poll areas.
 */
(function () {
  "use strict";
  var UNIWRT_VERSION = "2.0.4";
  var KEY_THEME = "uniwrt:theme", KEY_RAIL = "uniwrt:rail";
  var SETUP_DONE = false, ATTEMPTS = 0, MAX_ATTEMPTS = 45;

  function bsvg(p){return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+p+'</svg>';}
  var ICON_MENU=bsvg('<path d="M4 6h16M4 12h16M4 18h16"/>');
  var ICON_SUN =bsvg('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>');
  var ICON_MOON=bsvg('<path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/>');
  var ICON_SEARCH=bsvg('<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>');

  var ICONS=[
    ["overview",'<path d="M3 13h8V3H3zM13 21h8v-6h-8zM13 3v8h8V3zM3 21h8v-4H3z"/>'],
    ["status",  '<path d="M3 12h4l3 8 4-16 3 8h4"/>'],
    ["route",   '<circle cx="6" cy="19" r="2"/><circle cx="18" cy="5" r="2"/><path d="M8 19h7a4 4 0 0 0 0-8H9a4 4 0 0 1 0-8h7"/>'],
    ["firewall",'<path d="M12 2l8 4v6c0 5-3.5 8-8 10-4.5-2-8-5-8-10V6z"/>'],
    ["log",     '<path d="M4 4h16v16H4z"/><path d="M8 8h8M8 12h8M8 16h5"/>'],
    ["process", '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M9 9h6v6H9z"/>'],
    ["realtime",'<path d="M3 3v18h18"/><path d="M7 14l3-4 3 3 4-6"/>'],
    ["system",  '<circle cx="12" cy="12" r="3"/><path d="M19.4 13a7.8 7.8 0 0 0 0-2l2-1.5-2-3.5-2.4 1a8 8 0 0 0-1.7-1L14.2 2h-4l-.4 2.5a8 8 0 0 0-1.7 1l-2.4-1-2 3.5L3.7 11a7.8 7.8 0 0 0 0 2l-2 1.5 2 3.5 2.4-1a8 8 0 0 0 1.7 1l.4 2.5h4l.4-2.5a8 8 0 0 0 1.7-1l2.4 1 2-3.5z"/>'],
    ["admin",   '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>'],
    ["software",'<path d="M21 16V8l-9-5-9 5v8l9 5z"/><path d="M3 8l9 5 9-5M12 13v8"/>'],
    ["package", '<path d="M21 16V8l-9-5-9 5v8l9 5z"/><path d="M3 8l9 5 9-5M12 13v8"/>'],
    ["startup", '<circle cx="12" cy="12" r="9"/><path d="M10 8l6 4-6 4z"/>'],
    ["schedul", '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>'],
    ["flash",   '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>'],
    ["reboot",  '<path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/>'],
    ["interface",'<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10v4M10 10v4M14 10v4M18 10v4"/>'],
    ["wireless",'<path d="M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0M12 19h.01"/>'],
    ["wifi",    '<path d="M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0M12 19h.01"/>'],
    ["dhcp",    '<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10v4M10 10v4M14 10v4M18 10v4"/>'],
    ["dns",     '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'],
    ["diagnost",'<path d="M3 12h4l2 6 4-12 2 6h6"/>'],
    ["network", '<circle cx="12" cy="5" r="2"/><circle cx="5" cy="19" r="2"/><circle cx="19" cy="19" r="2"/><path d="M12 7v4M12 11l-6 6M12 11l6 6"/>'],
    ["service", '<circle cx="6" cy="12" r="2"/><circle cx="18" cy="6" r="2"/><circle cx="18" cy="18" r="2"/><path d="M8 12h6M14 12l3-5M14 12l3 5"/>'],
    ["vpn",     '<path d="M12 2l8 4v6c0 5-3.5 8-8 10-4.5-2-8-5-8-10V6z"/><path d="M9 12l2 2 4-4"/>'],
    ["statistic",'<path d="M3 3v18h18"/><rect x="7" y="11" width="3" height="6"/><rect x="12" y="7" width="3" height="10"/><rect x="17" y="13" width="3" height="4"/>'],
    ["logout",  '<path d="M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>']
  ];
  function navIcon(label){var t=(label||"").toLowerCase(), p=null; for(var i=0;i<ICONS.length;i++){ if(t.indexOf(ICONS[i][0])!==-1){ p=ICONS[i][1]; break; } } return '<span class="nav-ico">'+bsvg(p||'<circle cx="12" cy="12" r="9"/>')+'</span>';}
  function ls(read,k,v){try{return read?localStorage.getItem(k):localStorage.setItem(k,v);}catch(e){return null;}}
  function esc(s){return String(s||"").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}
  function attr(s){return esc(s).replace(/"/g,"&quot;");}
  function pathOf(href){try{return new URL(href,location.href).pathname.replace(/\/+$/,"");}catch(e){return String(href||"").replace(/[#?].*$/,"").replace(/\/+$/,"");}}
  function scriptBase(){return (window.L&&L.env&&L.env.scriptname)||"/cgi-bin/luci";}

  function applyTheme(m){var h=document.documentElement;(m==="dark"||m==="light")?h.setAttribute("data-theme",m):h.removeAttribute("data-theme");}
  function curMode(){var s=ls(true,KEY_THEME);if(s==="dark"||s==="light")return s;return (window.matchMedia&&matchMedia("(prefers-color-scheme:dark)").matches)?"dark":"light";}
  function paintTheme(m){var b=document.getElementById("uniwrt-theme-btn");if(!b)return;b.innerHTML=(m==="dark")?ICON_SUN:ICON_MOON;b.title=(m==="dark")?"Switch to light mode":"Switch to dark mode";b.setAttribute("aria-label",b.title);}
  function toggleTheme(){var n=curMode()==="dark"?"light":"dark";ls(false,KEY_THEME,n);var b=document.getElementById("uniwrt-theme-btn"); if(b){b.classList.add("swap");setTimeout(function(){applyTheme(n);paintTheme(n);b.classList.remove("swap");},160);}else{applyTheme(n);paintTheme(n);}}

  function usableHref(h){return h && h !== "#" && h.indexOf("javascript:") !== 0;}
  function findMenu(){
    var candidates=[document.getElementById("topmenu"),document.getElementById("mainmenu"),document.querySelector("header ul.nav"),document.querySelector("nav ul")];
    for(var i=0;i<candidates.length;i++){var m=candidates[i];if(m&&m.querySelectorAll("a[href]").length>=2)return m;}
    return null;
  }
  function directLis(menu){
    var out=[];
    for(var i=0;i<menu.children.length;i++){if(String(menu.children[i].tagName).toLowerCase()==="li")out.push(menu.children[i]);}
    return out.length?out:Array.prototype.slice.call(menu.querySelectorAll("li"));
  }
  function parseGroups(menu){
    var groups=[], cur=location.pathname.replace(/\/+$/,"");
    directLis(menu).forEach(function(li){
      if(li.closest("li") && li.parentElement !== menu)return;
      var head=li.querySelector(":scope > a")||li.querySelector("a");
      if(!head)return;
      var label=(head.textContent||"").trim();
      var links=li.querySelectorAll(":scope > ul a[href], :scope > div a[href], :scope > .dropdown-menu a[href]");
      var items=[];
      if(links.length){
        links.forEach(function(a){var h=a.getAttribute("href")||"", t=(a.textContent||"").trim(); if(t&&usableHref(h))items.push({href:h,label:t,active:pathOf(h)===cur});});
      } else {
        var h=head.getAttribute("href")||""; if(label&&usableHref(h))items.push({href:h,label:label,active:pathOf(h)===cur});
      }
      if(label&&items.length)groups.push({label:label,items:dedupe(items)});
    });
    if(!groups.length){
      var flat=[]; menu.querySelectorAll("a[href]").forEach(function(a){var h=a.getAttribute("href")||"", t=(a.textContent||"").trim(); if(t&&usableHref(h))flat.push({href:h,label:t,active:pathOf(h)===cur});});
      if(flat.length)groups.push({label:"Menu",items:dedupe(flat)});
    }
    return markActive(groups);
  }
  function dedupe(items){var seen={}, out=[]; items.forEach(function(it){var k=pathOf(it.href)+"|"+it.label; if(!seen[k]){seen[k]=1; out.push(it);}}); return out;}
  function fallbackNav(){
    var b=scriptBase();
    return markActive([{label:"Recovery",items:[
      {href:b+"/admin/status/overview",label:"Overview"},
      {href:b+"/admin/network/network",label:"Interfaces"},
      {href:b+"/admin/network/wireless",label:"Wireless"},
      {href:b+"/admin/network/firewall",label:"Firewall"},
      {href:b+"/admin/system/system",label:"System"},
      {href:b+"/admin/system/reboot",label:"Reboot"},
      {href:b+"/admin/logout",label:"Logout"}
    ]}]);
  }
  function markActive(groups){
    var cur=location.pathname.replace(/\/+$/,""); var best=null,bestLen=-1;
    groups.forEach(function(g){g.items.forEach(function(it){var p=pathOf(it.href); it.active=false; if(p&&cur.indexOf(p)===0&&p.length>bestLen){best=it;bestLen=p.length;}});});
    if(best)best.active=true; return groups;
  }

  function buildRail(menu, recovery){
    if(document.querySelector(".uniwrt-sidebar"))return true;
    var groups=recovery?fallbackNav():parseGroups(menu);
    var total=groups.reduce(function(n,g){return n+g.items.length;},0);
    if(total<2 && !recovery)return false;
    var navHtml=groups.map(function(g){
      var lis=g.items.map(function(it){return '<li><a href="'+attr(it.href)+'"'+(it.active?' class="active"':'')+'>'+navIcon(it.label)+'<span class="nav-label">'+esc(it.label)+'</span></a></li>';}).join("");
      return '<div class="nav-group"><div class="nav-group-label">'+esc(g.label)+'</div><ul>'+lis+'</ul></div>';
    }).join("");
    var aside=document.createElement("aside"); aside.className="uniwrt-sidebar";
    aside.innerHTML='<div class="uniwrt-brand"><img src="/luci-static/uniwrt/logo.svg" alt="" onerror="this.style.display=\'none\'"><span class="brand-text">UniWRT</span></div>'+ '<div class="uniwrt-menu-search"><input type="search" id="uniwrt-menu-filter" placeholder="Search menu" autocomplete="off" aria-label="Search menu"></div>' + '<nav class="uniwrt-nav">'+navHtml+'</nav>'+ '<div class="uniwrt-rail-foot">Portal for OpenWrt'+(recovery?' · Recovery menu':'')+'</div>';
    var title=(document.title.split(" - ")[0]||document.title||"Dashboard").trim();
    var bar=document.createElement("div"); bar.className="uniwrt-topbar";
    bar.innerHTML='<button type="button" class="uniwrt-iconbtn" id="uniwrt-collapse" title="Toggle menu" aria-label="Toggle menu" aria-expanded="false">'+ICON_MENU+'</button>'+ '<span class="crumb">'+esc(title)+'</span><span class="uniwrt-context">LuCI</span><span class="spacer"></span>'+ '<button type="button" class="uniwrt-iconbtn" id="uniwrt-theme-btn" title="Theme" aria-label="Theme"></button>';
    var scrim=document.createElement("div"); scrim.className="uniwrt-scrim";
    document.body.appendChild(aside); document.body.appendChild(bar); document.body.appendChild(scrim); document.body.classList.add("uniwrt-shell");
    if(ls(true,KEY_RAIL)==="collapsed")document.body.classList.add("rail-collapsed");
    var act=aside.querySelector("a.active"); if(act)setTimeout(function(){try{act.scrollIntoView({block:"center"});}catch(e){}},0);
    var c=document.getElementById("uniwrt-collapse"); if(c)c.addEventListener("click",function(){ if(window.innerWidth<=900){document.body.classList.toggle("rail-open"); c.setAttribute("aria-expanded",document.body.classList.contains("rail-open")?"true":"false");} else {document.body.classList.toggle("rail-collapsed"); ls(false,KEY_RAIL,document.body.classList.contains("rail-collapsed")?"collapsed":"");} });
    scrim.addEventListener("click",function(){document.body.classList.remove("rail-open"); if(c)c.setAttribute("aria-expanded","false");});
    window.addEventListener("resize",function(){if(window.innerWidth>900){document.body.classList.remove("rail-open"); if(c)c.setAttribute("aria-expanded","false");}}, {passive:true});
    document.addEventListener("keydown",function(e){if(e.key==="Escape"){document.body.classList.remove("rail-open"); if(c)c.setAttribute("aria-expanded","false");}});
    var tb=document.getElementById("uniwrt-theme-btn"); if(tb)tb.addEventListener("click",toggleTheme); paintTheme(curMode());
    var filter=document.getElementById("uniwrt-menu-filter");
    if(filter)filter.addEventListener("input",function(){var q=this.value.trim().toLowerCase(); aside.querySelectorAll(".nav-group").forEach(function(g){var visible=0; g.querySelectorAll("li").forEach(function(li){var ok=!q || li.textContent.toLowerCase().indexOf(q)!==-1; li.classList.toggle("is-hidden",!ok); if(ok)visible++;}); g.classList.toggle("is-empty",visible===0);});});
    aside.querySelectorAll("a[href]").forEach(function(a){a.addEventListener("click",function(){document.body.classList.remove("rail-open"); if(c)c.setAttribute("aria-expanded","false");});});
    return true;
  }

  function decorateLogin(){
    var pw=document.querySelector('input[type="password"]');
    if(!pw||findMenu())return false;
    document.body.classList.add("uniwrt-login");

    /* Some LuCI builds show login through #modal_overlay but only mark the
     * body with modal-overlay-active. Make the overlay state explicit so the
     * login dialog cannot be hidden by theme modal styling. */
    var overlay=document.getElementById("modal_overlay");
    if(overlay&&overlay.querySelector('input[type="password"]')){
      overlay.classList.add("active");
      document.body.classList.add("modal-overlay-active");
    }

    var form=pw.closest("form, .cbi-map");
    if(form&&!form.querySelector(".uniwrt-login-brand")){
      var b=document.createElement("div"); b.className="uniwrt-login-brand";
      b.innerHTML='<img src="/luci-static/uniwrt/logo.svg" alt="" onerror="this.style.display=\'none\'"><strong>UniWRT</strong>';
      form.insertBefore(b,form.firstChild);
    }
    return true;
  }
  function rebrandFooter(){
    var f=document.querySelector("footer")||document.getElementById("footer");
    if(!f||f.getAttribute("data-uniwrt")==="1")return;
    f.setAttribute("data-uniwrt","1");
    var s=document.createElement("span"); s.className="uniwrt-ver"; s.textContent="UniWRT v"+UNIWRT_VERSION;
    f.appendChild(document.createTextNode(" ")); f.appendChild(s);
  }
  function tryInit(){
    if(SETUP_DONE)return;
    applyTheme(curMode()); rebrandFooter();
    if(decorateLogin()){SETUP_DONE=true;return;}
    var menu=findMenu();
    if(menu && buildRail(menu,false)){SETUP_DONE=true;return;}
    if(ATTEMPTS++ < MAX_ATTEMPTS){setTimeout(tryInit,90);return;}
    if(buildRail(null,true)){SETUP_DONE=true;}
  }
  function start(){try{tryInit();}catch(e){try{console.warn("UniWRT theme init failed",e);}catch(_){}}}
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",start,{once:true}); else start();
  if(window.matchMedia)matchMedia("(prefers-color-scheme:dark)").addEventListener("change",function(){if(!ls(true,KEY_THEME)){applyTheme(curMode());paintTheme(curMode());}});
})();

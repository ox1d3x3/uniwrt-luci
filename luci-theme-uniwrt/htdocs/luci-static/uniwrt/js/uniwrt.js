/*
 * luci-theme-uniwrt — shell behaviour
 * SPDX-License-Identifier: MIT
 *
 * Reads LuCI's real two-level menu:
 *   <ul id="topmenu"> <li.dropdown> <a.menu>CATEGORY</a>
 *       <ul.dropdown-menu> <li><a>PAGE</a> ... </ul>
 * and rebuilds it as a grouped UniFi-style left rail (category label +
 * its pages), with the current page highlighted. Adds a top bar with a
 * collapse toggle and a light/dark switch.
 *
 * Fail-safe: the native <header> is only hidden (via the `uniwrt-shell`
 * body class) AFTER a populated rail has been built. If the menu can't be
 * read, nothing is hidden and the stock navigation stays intact.
 */
(function () {
  "use strict";
  var UNIWRT_VERSION = "1.6.2";
  var KEY_THEME = "uniwrt:theme", KEY_RAIL = "uniwrt:rail";

  function bsvg(p){return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '+
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'+p+'</svg>';}
  var ICON_MENU=bsvg('<path d="M4 6h16M4 12h16M4 18h16"/>');
  var ICON_SUN =bsvg('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>');
  var ICON_MOON=bsvg('<path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/>');

  /* label -> icon path (matched on substring, first hit wins) */
  var ICONS=[
    ["overview",'<path d="M3 13h8V3H3zM13 21h8v-6h-8zM13 3v8h8V3zM3 21h8v-4H3z"/>'],
    ["status",  '<path d="M3 12h4l3 8 4-16 3 8h4"/>'],
    ["route",   '<circle cx="6" cy="19" r="2"/><circle cx="18" cy="5" r="2"/><path d="M8 19h7a4 4 0 0 0 0-8H9a4 4 0 0 1 0-8h7"/>'],
    ["firewall",'<path d="M12 2l8 4v6c0 5-3.5 8-8 10-4.5-2-8-5-8-10V6z"/>'],
    ["log",     '<path d="M4 4h16v16H4z"/><path d="M8 8h8M8 12h8M8 16h5"/>'],
    ["process", '<rect x="4" y="4" width="16" height="16" rx="2"/><path d="M9 9h6v6H9z"/>'],
    ["channel", '<path d="M3 12h4l3 8 4-16 3 8h4"/>'],
    ["realtime",'<path d="M3 3v18h18"/><path d="M7 14l3-4 3 3 4-6"/>'],
    ["graph",   '<path d="M3 3v18h18"/><path d="M7 14l3-4 3 3 4-6"/>'],
    ["system",  '<circle cx="12" cy="12" r="3"/><path d="M19.4 13a7.8 7.8 0 0 0 0-2l2-1.5-2-3.5-2.4 1a8 8 0 0 0-1.7-1L14.2 2h-4l-.4 2.5a8 8 0 0 0-1.7 1l-2.4-1-2 3.5L3.7 11a7.8 7.8 0 0 0 0 2l-2 1.5 2 3.5 2.4-1a8 8 0 0 0 1.7 1l.4 2.5h4l.4-2.5a8 8 0 0 0 1.7-1l2.4 1 2-3.5z"/>'],
    ["admin",   '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>'],
    ["software",'<path d="M21 16V8l-9-5-9 5v8l9 5z"/><path d="M3 8l9 5 9-5M12 13v8"/>'],
    ["package", '<path d="M21 16V8l-9-5-9 5v8l9 5z"/><path d="M3 8l9 5 9-5M12 13v8"/>'],
    ["startup", '<circle cx="12" cy="12" r="9"/><path d="M10 8l6 4-6 4z"/>'],
    ["schedul", '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>'],
    ["sysupgrade",'<path d="M12 16V4M6 10l6-6 6 6"/><path d="M4 20h16"/>'],
    ["led",     '<path d="M9 18h6M10 21h4M12 2a6 6 0 0 1 4 10c-1 1-1 2-1 3H9c0-1 0-2-1-3a6 6 0 0 1 4-10z"/>'],
    ["backup",  '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5"/>'],
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
  function navIcon(label){
    var t=(label||"").toLowerCase(), p=null;
    for(var i=0;i<ICONS.length;i++){ if(t.indexOf(ICONS[i][0])!==-1){ p=ICONS[i][1]; break; } }
    if(!p) p='<circle cx="12" cy="12" r="9"/>';
    return '<span class="nav-ico">'+bsvg(p)+'</span>';
  }

  function ls(read,k,v){try{return read?localStorage.getItem(k):localStorage.setItem(k,v);}catch(e){return null;}}
  function esc(s){return (s||"").replace(/&/g,"&amp;").replace(/</g,"&lt;");}
  function pathOf(href){try{return new URL(href,location.href).pathname.replace(/\/+$/,"");}catch(e){return (href||"").replace(/[#?].*$/,"").replace(/\/+$/,"");}}

  function applyTheme(m){var h=document.documentElement;(m==="dark"||m==="light")?h.setAttribute("data-theme",m):h.removeAttribute("data-theme");}
  function curMode(){var s=ls(true,KEY_THEME);if(s==="dark"||s==="light")return s;
    return (window.matchMedia&&matchMedia("(prefers-color-scheme:dark)").matches)?"dark":"light";}
  function paintTheme(m){var b=document.getElementById("uniwrt-theme-btn");if(!b)return;
    b.innerHTML=(m==="dark")?ICON_SUN:ICON_MOON;b.title=(m==="dark")?"Switch to light mode":"Switch to dark mode";}
  function toggleTheme(){var n=curMode()==="dark"?"light":"dark";ls(false,KEY_THEME,n);
    var b=document.getElementById("uniwrt-theme-btn");
    if(b){b.classList.add("swap");setTimeout(function(){applyTheme(n);paintTheme(n);b.classList.remove("swap");},180);}
    else{applyTheme(n);paintTheme(n);}}

  function findMenu(){
    var m=document.getElementById("topmenu")||document.getElementById("mainmenu");
    if(m&&m.querySelectorAll("a").length>=2)return m;
    var alt=document.querySelector("header .nav, .main-left .nav, nav.nav");
    return (alt&&alt.querySelectorAll("a").length>=2)?alt:null;
  }

  /* parse two-level menu into [{label, items:[{href,label}]}] */
  function parseGroups(menu){
    var groups=[], cur=location.pathname.replace(/\/+$/,"");
    var tops=menu.querySelectorAll(":scope > li");
    tops.forEach(function(li){
      var head=li.querySelector(":scope > a");
      var sub=li.querySelectorAll(":scope > ul a");
      var label=head?head.textContent.trim():"";
      var items=[];
      if(sub.length){
        sub.forEach(function(a){var h=a.getAttribute("href")||"";var t=(a.textContent||"").trim();
          if(t)items.push({href:h,label:t,active:pathOf(h)===cur});});
      }else if(head){
        var h=head.getAttribute("href")||"";items.push({href:h,label:label,active:pathOf(h)===cur});
      }
      if(label&&items.length)groups.push({label:label,items:items});
    });
    // Fallback: if the two-level structure wasn't found but the menu has links,
    // build a single flat group so the rail ALWAYS appears when a menu exists.
    if(!groups.length){
      var flat=[];
      menu.querySelectorAll("a").forEach(function(a){
        var h=a.getAttribute("href")||"",t=(a.textContent||"").trim();
        if(t&&h&&h!=="#")flat.push({href:h,label:t,active:pathOf(h)===cur});
      });
      if(flat.length)groups.push({label:"Menu",items:flat});
    }
    return groups;
  }

  // Fixed UniFi-style navigation. Built into the theme so the rail ALWAYS
  // appears, independent of whether LuCI has finished rendering its own menu
  // (on 25.12 the menu is built late via ubus and is often empty at load).
  // Paths are LuCI's stable admin routes; LuCI resolves the script prefix.
  function defaultNav(base){
    var b=base||"/cgi-bin/luci";
    return [
      {label:"Status",items:[
        {href:b+"/admin/status/overview",label:"Overview"},
        {href:b+"/admin/status/routes",label:"Routing"},
        {href:b+"/admin/status/nftables",label:"Firewall"},
        {href:b+"/admin/status/logs/syslog",label:"System Log"},
        {href:b+"/admin/status/processes",label:"Processes"},
        {href:b+"/admin/status/channel_analysis",label:"Channel Analysis"},
        {href:b+"/admin/status/realtime/load",label:"Realtime Graphs"}
      ]},
      {label:"System",items:[
        {href:b+"/admin/system/system",label:"System"},
        {href:b+"/admin/system/admin",label:"Administration"},
        {href:b+"/admin/system/package-manager",label:"Software"},
        {href:b+"/admin/system/startup",label:"Startup"},
        {href:b+"/admin/system/crontab",label:"Scheduled Tasks"},
        {href:b+"/admin/system/leds",label:"LED Configuration"},
        {href:b+"/admin/system/attendedsysupgrade",label:"Attended Sysupgrade"},
        {href:b+"/admin/system/flash",label:"Backup / Flash Firmware"},
        {href:b+"/admin/system/reboot",label:"Reboot"}
      ]},
      {label:"Network",items:[
        {href:b+"/admin/network/network",label:"Interfaces"},
        {href:b+"/admin/network/wireless",label:"Wireless"},
        {href:b+"/admin/network/dhcp",label:"DHCP"},
        {href:b+"/admin/network/dns",label:"DNS"},
        {href:b+"/admin/network/routes",label:"Static Routes"},
        {href:b+"/admin/network/diagnostics",label:"Diagnostics"},
        {href:b+"/admin/network/firewall",label:"Firewall"}
      ]}
    ];
  }

  // Mark the entry matching the current path active (longest-prefix wins).
  function markActive(groups){
    var cur=location.pathname.replace(/\/+$/,""),best=null,bestLen=-1;
    groups.forEach(function(g){g.items.forEach(function(it){
      var p=pathOf(it.href);
      if(p&&cur.indexOf(p)===0&&p.length>bestLen){best=it;bestLen=p.length;}
      it.active=false;
    });});
    if(best)best.active=true;
    return groups;
  }

  function buildRail(menu){
    if(document.querySelector(".uniwrt-sidebar"))return true;

    // Prefer LuCI's own menu when it actually has links (keeps any custom
    // pages a build adds); otherwise fall back to our fixed nav so the rail
    // is guaranteed to render.
    var groups=menu?parseGroups(menu):[];
    var total=groups.reduce(function(n,g){return n+g.items.length;},0);
    if(total<3){
      var base=(window.L&&L.env&&L.env.scriptname)?L.env.scriptname:"/cgi-bin/luci";
      groups=markActive(defaultNav(base));
    }
    if(!groups.length)return false;

    var navHtml=groups.map(function(g){
      var lis=g.items.map(function(it){
        return '<li><a href="'+it.href+'"'+(it.active?' class="active"':'')+'>'+
          navIcon(it.label)+'<span class="nav-label">'+esc(it.label)+'</span></a></li>';
      }).join("");
      return '<div class="nav-group"><div class="nav-group-label">'+esc(g.label)+
        '</div><ul>'+lis+'</ul></div>';
    }).join("");

    var aside=document.createElement("aside");
    aside.className="uniwrt-sidebar";
    aside.innerHTML='<div class="uniwrt-brand"><img src="/luci-static/uniwrt/logo.svg" alt="" '+
      'onerror="this.style.display=\'none\'"><span class="brand-text">UniWRT</span></div>'+
      '<nav class="uniwrt-nav">'+navHtml+'</nav>'+
      '<div class="uniwrt-rail-foot">OpenWrt &middot; LuCI</div>';

    var title=(document.title.split(" - ")[0]||document.title||"Dashboard").trim();
    var bar=document.createElement("div");
    bar.className="uniwrt-topbar";
    bar.innerHTML='<button class="uniwrt-iconbtn" id="uniwrt-collapse" title="Toggle menu">'+ICON_MENU+'</button>'+
      '<span class="crumb">'+esc(title)+'</span><span class="spacer"></span>'+
      '<button class="uniwrt-iconbtn" id="uniwrt-theme-btn" title="Theme"></button>';

    var scrim=document.createElement("div");scrim.className="uniwrt-scrim";

    document.body.appendChild(aside);
    document.body.appendChild(bar);
    document.body.appendChild(scrim);
    document.body.classList.add("uniwrt-shell");
    if(ls(true,KEY_RAIL)==="collapsed")document.body.classList.add("rail-collapsed");

    var act=aside.querySelector("a.active");if(act)setTimeout(function(){try{act.scrollIntoView({block:"center"});}catch(e){}},0);

    document.getElementById("uniwrt-collapse").addEventListener("click",function(){
      if(window.innerWidth<=900){document.body.classList.toggle("rail-open");}
      else{document.body.classList.toggle("rail-collapsed");
        ls(false,KEY_RAIL,document.body.classList.contains("rail-collapsed")?"collapsed":"");}
    });
    scrim.addEventListener("click",function(){document.body.classList.remove("rail-open");});
    document.getElementById("uniwrt-theme-btn").addEventListener("click",toggleTheme);
    paintTheme(curMode());
    return true;
  }

  function decorateLogin(){
    var pw=document.querySelector('input[type="password"]');
    if(!pw||findMenu())return false;
    document.body.classList.add("uniwrt-login");
    var form=pw.closest("form, .cbi-map");
    if(form&&!form.querySelector(".uniwrt-login-brand")){
      var b=document.createElement("div");b.className="uniwrt-login-brand";
      b.innerHTML='<img src="/luci-static/uniwrt/logo.svg" alt="" onerror="this.style.display=\'none\'">'+
        '<strong>UniWRT</strong>';
      form.insertBefore(b,form.firstChild);
    }
    return true;
  }

  function rebrandFooter(){
    var f=document.querySelector("footer")||document.getElementById("footer");
    if(!f||f.getAttribute("data-uniwrt")==="1")return;
    f.setAttribute("data-uniwrt","1");
    f.innerHTML='<span>Author: <a href="https://github.com/ox1d3x3/uniwrt-luci" '+
      'target="_blank" rel="noreferrer">Ox1d3x3 &times; UniWRT</a>'+
      '<span class="uniwrt-ver">v'+UNIWRT_VERSION+'</span></span>';
  }

  // One-time setup guard: the rail/chrome must be built exactly once. After
  // that we MUST stop touching the DOM, because LuCI's own JS (L.poll) keeps
  // mutating the page to fill Memory/Storage, build tables and open modals —
  // re-running on every mutation creates a feedback loop and can interrupt
  // LuCI's updates (blank Memory/Storage, dead buttons). So: build once, then
  // disconnect and never re-run.
  var SETUP_DONE=false;

  function init(){
    if(SETUP_DONE)return true;
    applyTheme(curMode());
    rebrandFooter();
    if(decorateLogin()){SETUP_DONE=true;return true;}
    if(buildRail(findMenu())){SETUP_DONE=true;return true;}
    return false;
  }
  // Run setup exactly once when the DOM is ready, then never touch the DOM
  // again — LuCI's own JS (L.poll, tab/modal handlers) must run uninterrupted.
  // Our rail uses a built-in nav, so we don't need to wait for LuCI's menu.
  function start(){ try{ init(); }catch(e){} }
  if(document.readyState==="loading")
    document.addEventListener("DOMContentLoaded",start,{once:true});
  else start();
  if(window.matchMedia)matchMedia("(prefers-color-scheme:dark)").addEventListener("change",function(){
    if(!ls(true,KEY_THEME)){applyTheme(curMode());paintTheme(curMode());}});
})();

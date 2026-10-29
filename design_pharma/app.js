(function(){
'use strict';
/* ================= helpers ================= */
const $=(s,r=document)=>r.querySelector(s),$$=(s,r=document)=>[...r.querySelectorAll(s)];
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const I=(n,c='')=>`<svg class="i ${c}" aria-hidden="true"><use href="#i-${n}"/></svg>`;
const nfi=new Intl.NumberFormat('fr-FR',{maximumFractionDigits:0}),nf1=new Intl.NumberFormat('fr-FR',{maximumFractionDigits:1}),nf2=new Intl.NumberFormat('fr-FR',{minimumFractionDigits:2,maximumFractionDigits:2});
const eg=(n,d)=>(d?nf2:nfi).format(Math.round(n*100)/100)+' EGP';
const norm=s=>String(s).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'');
const sum=(a,f)=>a.reduce((s,x)=>s+f(x),0);
const DAY=864e5,TODAY=new Date(2026,9,28);
const addDays=n=>new Date(2026,9,28+n);
const daysTo=d=>Math.round((d-TODAY)/DAY);
const fd=d=>new Intl.DateTimeFormat('fr-FR',{day:'numeric',month:'short',year:'numeric'}).format(d);
const isoD=d=>d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
const parseD=s=>{const [y,m,d]=s.split('-').map(Number);return new Date(y,m-1,d)};
const ftime=d=>new Intl.DateTimeFormat('fr-FR',{hour:'2-digit',minute:'2-digit'}).format(d);
const ago=ts=>{const m=Math.round((Date.now()-ts)/6e4);if(m<1)return "à l'instant";if(m<60)return `il y a ${m} min`;const h=Math.round(m/60);return h<24?`il y a ${h} h`:`il y a ${Math.round(h/24)} j`};
const initials=n=>n.split(' ').map(w=>w[0]).slice(0,2).join('').toUpperCase();
const AVC=['#C2321F','#0B7F78','#2150C8','#8B5CF6','#B45309','#15803D'];
const pill=(t,c,nodot)=>`<span class="pill ${c||''} ${nodot?'nodot':''}">${esc(t)}</span>`;
const pad=(l,r,w=36)=>l+' '.repeat(Math.max(1,w-l.length-r.length))+r;

/* ================= données ================= */
let SEQ=0;
const L=(lot,d,q)=>({lot,exp:addDays(d),q});
const M=(n,cat,price,cost,min,sup,rx,lots)=>({id:++SEQ,n,cat,price,cost,min,sup,rx,bc:'6221'+String(100000000+SEQ*7919311).slice(0,9),lots});
const MEDS=[
 M('Paracétamol 500 mg','Douleur',15,9.5,100,1,false,[L('PAR26-11',420,450)]),
 M('Amoxicilline 250 mg','Antibiotiques',45,31,40,2,true,[L('AMX26-04',55,12)]),
 M('Oméprazole 20 mg','Digestif',28,18,80,3,false,[L('OME26-02',135,320)]),
 M('Metformine 500 mg','Diabète',22,14,50,1,true,[L('MET26-09',8,5)]),
 M('Amlodipine 5 mg','Cardiovasculaire',35,22,60,4,true,[L('AML26-05',90,180)]),
 M('Vitamine C 1000 mg','Vitamines',35,21,80,5,false,[L('VTC26-07',300,260)]),
 M('Aspirine 100 mg','Douleur',18,11,80,1,false,[L('BTC2024-03',15,180)]),
 M('Ciprofloxacine 500 mg','Antibiotiques',52,36,40,2,true,[L('BTC2024-07',-20,30),L('CIP26-01',240,90)]),
 M('Losartan 50 mg','Cardiovasculaire',41,27,50,4,true,[L('BTC2024-12',25,60),L('LOS26-03',200,110)]),
 M('Ibuprofène 400 mg','Douleur',24,14,100,3,false,[L('IBU26-06',380,300)]),
 M('Cétirizine 10 mg','Allergie',19,11,40,6,false,[L('CET26-08',260,120)]),
 M('Vitamine D3 1000 UI','Vitamines',48,30,50,5,false,[]),
 M('Zinc 50 mg','Vitamines',32,19,60,5,false,[L('ZIN26-10',95,75)]),
 M('Dompéridone 10 mg','Digestif',26,16,40,3,false,[L('DOM26-01',30,38)]),
 M('Sérum physiologique 0,9 %','Hygiène',12,6,120,6,false,[L('SER26-12',500,410)]),
 M('Pansements assortis','Hygiène',22,12,30,6,false,[L('PAN26-03',700,95)]),
 M('Atorvastatine 20 mg','Cardiovasculaire',60,40,40,4,true,[L('ATO26-02',150,90)]),
 M('Salbutamol spray 100 µg','Respiratoire',38,25,30,2,true,[L('SAL26-04',210,48)])];
const SUP=[
 {id:1,n:'PharmaCorp Égypte',c:'Mohamed Ali',ph:'+20 122 456 7890',lead:3},{id:2,n:'MediSupply International',c:'Sarah Hassan',ph:'+20 101 234 5678',lead:5},
 {id:3,n:'Distributeurs de produits de santé',c:'Ahmed Mahmoud',ph:'+20 100 987 6543',lead:2},{id:4,n:'Solutions pharmaceutiques mondiales',c:'Fatima Khalil',ph:'+20 112 345 6789',lead:7},
 {id:5,n:'Fournitures médicales égyptiennes',c:'Omar Youssef',ph:'+20 120 876 5432',lead:4},{id:6,n:'Delta Pharmaceuticals',c:'Layla Ibrahim',ph:'+20 115 432 1098',lead:3}];
const ROLES=['Administrateur','Pharmacien',"Gestionnaire d'inventaire",'Caissier'];
const MODS=[['db','Tableau de bord'],['pos','Point de vente'],['inv','Inventaire'],['cl','Clients'],['ex',"Suivi d'expiration"],['an','Analytique'],['sa','Rapports de vente'],['su','Fournisseurs'],['st','Accès du personnel'],['se','Paramètres']];
const PERM={'Administrateur':new Set(MODS.map(m=>m[0])),'Pharmacien':new Set(['db','pos','inv','cl','ex','sa']),"Gestionnaire d'inventaire":new Set(['db','inv','ex','su']),'Caissier':new Set(['pos','cl'])};
const ROLECLS={'Administrateur':['admin','shield'],'Pharmacien':['pharma','user'],"Gestionnaire d'inventaire":['inv','box'],'Caissier':['cash','cart']};
const STAFF=[{id:1,n:'Ahmed Khaled',e:'ahmed@pharma.com',role:'Administrateur',on:true},{id:2,n:'Sara Mohamed',e:'sara@pharma.com',role:'Pharmacien',on:true},{id:3,n:'Omar Hassan',e:'omar@pharma.com',role:"Gestionnaire d'inventaire",on:true},{id:4,n:'Layla Ahmed',e:'layla@pharma.com',role:'Pharmacien',on:true},{id:5,n:'Youssef Nabil',e:'youssef@pharma.com',role:'Caissier',on:true}];
const CLI=[
 {id:1,n:'Mohamed Ali',ph:'+20 122 456 7890',e:'mohamed@email.com',tot:24500,cnt:38,last:'28 oct. 2026'},{id:2,n:'Fatima Hassan',ph:'+20 101 234 5678',e:'fatima@email.com',tot:18200,cnt:29,last:'27 oct. 2026'},
 {id:3,n:'Nour Ibrahim',ph:'+20 100 987 6543',e:'nour@email.com',tot:9640,cnt:17,last:'25 oct. 2026'},{id:4,n:'Youssef Khalil',ph:'+20 112 345 6789',e:'youssef.k@email.com',tot:4120,cnt:8,last:'2 juil. 2026'},
 {id:5,n:'Mariam Saad',ph:'+20 120 876 5432',e:'mariam@email.com',tot:7380,cnt:14,last:'24 oct. 2026'},{id:6,n:'Karim Farouk',ph:'+20 115 432 1098',e:'karim@email.com',tot:3290,cnt:6,last:'19 oct. 2026'}];
const SET={tax:14,expDays:30,low:true,exp:true,report:false};
const TODAY_BASE=3225,WEEK_BASE=21340-3225;
const SALES=[];let INV=10482;
function mkSale(h,mi,cust,pay,items){const it=items.map(([id,q])=>{const m=MEDS.find(x=>x.id===id);return{id,n:m.n,q,p:m.price,c:m.cost}});
  const net=sum(it,i=>i.p*i.q),tax=net*.14;const d=new Date(2026,9,28,h,mi);return{id:'INV-'+(INV--),ts:d,cust,pay,items:it,net,cost:sum(it,i=>i.c*i.q),tax,total:net+tax,paid:net+tax,seed:true}}
[[15,30,'Mohamed Ali','Espèces',[[1,2],[3,1],[10,1]]],[14,45,'Passage','Carte',[[6,2]]],[13,10,'Fatima Hassan','Espèces',[[2,1],[1,3],[14,1],[5,1]]],[11,58,'Nour Ibrahim','Carte',[[11,1],[13,2]]],[10,20,'Passage','Espèces',[[10,2]]],[9,12,'Mariam Saad','Espèces',[[1,1],[7,1],[15,2]]]].forEach(a=>SALES.push(mkSale(...a)));
INV=10483;
const ORDERS=[],ACT=[
 {ts:Date.now()-2*6e4,icon:'cart',title:'Vente conclue',text:'Facture INV-10482 · '+eg(SALES[0].total,1)},
 {ts:Date.now()-60*6e4,icon:'users',title:'Nouveau client enregistré',text:'Karim Farouk a été ajouté'},
 {ts:Date.now()-180*6e4,icon:'file',title:'Rapport quotidien généré',text:'Ventes du 27 octobre 2026'}];
const logAct=(icon,title,text)=>ACT.unshift({ts:Date.now(),icon,title,text});
const AN={
 week:{labels:['lun.','mar.','mer.','jeu.','ven.','sam.','dim.'],long:['lundi','mardi','mercredi','jeudi','vendredi','samedi','dimanche'],rev:[2800,3200,2400,3800,4200,3600,4500],d:[8.2,6.4,5.1,1.2],f:.075,name:'7 derniers jours'},
 month:{labels:['S1','S2','S3','S4'],long:['Semaine 1','Semaine 2','Semaine 3','Semaine 4'],rev:[72000,81000,76000,99000],d:[23.5,18.2,12.3,-2.1],f:1,name:'30 derniers jours'},
 year:{labels:['nov.','déc.','janv.','févr.','mars','avr.','mai','juin','juil.','août','sept.','oct.'],long:['novembre 2025','décembre 2025','janvier 2026','février 2026','mars 2026','avril 2026','mai 2026','juin 2026','juillet 2026','août 2026','septembre 2026','octobre 2026'],rev:[265000,270000,280000,255000,290000,300000,310000,295000,320000,305000,330000,328000],d:[31,27.4,19.8,9.6],f:11.4,name:'12 derniers mois'}};
const TOP=[['Paracétamol 500 mg',1250,15,12,1],['Amoxicilline 250 mg',980,45,8,1],['Vitamine C 1000 mg',850,35,3,0],['Oméprazole 20 mg',720,28,15,1],['Metformine 500 mg',650,22,5,1]];
const CATSHARE=[['Douleur',35],['Antibiotiques',25],['Vitamines',20],['Digestif',12],['Autres',8]];
const LINE=[28,35,31,42,48,38,45],LINEL=['lun.','mar.','mer.','jeu.','ven.','sam.','dim.'];

/* ================= logique ================= */
const medById=id=>MEDS.find(m=>m.id===id),supById=id=>SUP.find(s=>s.id===id);
const stock=m=>sum(m.lots.filter(l=>daysTo(l.exp)>=0),l=>l.q);
const status=m=>{const s=stock(m);return s===0?'rupture':s<=m.min*.25?'critique':s<m.min?'faible':'ok'};
const ST={ok:['En stock','good'],faible:['Stock faible','warn'],critique:['Critique','crit'],rupture:['Rupture','crit']};
const RANK={rupture:0,critique:1,faible:2,ok:3};
const byUrg=(a,b)=>RANK[status(a)]-RANK[status(b)]||a.n.localeCompare(b.n);
const stPill=m=>pill(ST[status(m)][0],ST[status(m)][1]);
function lotSt(l){const d=daysTo(l.exp);
  if(d<0)return{k:'expired',t:`Expiré depuis ${-d} j`,c:'crit',d};
  if(d<=15)return{k:'soon',t:`Dans ${d} j`,c:'crit',d};
  if(d<=SET.expDays)return{k:'soon',t:`Dans ${d} j`,c:'warn',d};
  if(d<=90)return{k:'watch',t:`Dans ${d} j`,c:'info',d};
  return{k:'ok',t:`Dans ${d} j`,c:'good',d}}
const allLots=()=>MEDS.flatMap(m=>m.lots.filter(l=>l.q>0).map(l=>({m,l,st:lotSt(l)}))).sort((a,b)=>a.st.d-b.st.d);
function velocity(m){return({1:41,2:32,3:24,4:21,5:12,6:28,7:17,8:6,9:7,10:23,11:9,12:10,13:8,14:6,15:11,16:4,17:5,18:5})[m.id]/1||5}
const ceil10=n=>Math.max(10,Math.ceil(n/10)*10);
const suggest=m=>ceil10(Math.max(m.min*2-stock(m),0)||m.min);
const DISM=new Set();
function alerts(){const out=[];
  MEDS.forEach(m=>{const st=status(m),s=stock(m);
    if(st==='rupture')out.push({id:'s'+m.id,sev:'crit',kind:'stock',m,t:`${m.n} · Rupture de stock`,x:'Aucune unité vendable. Réapprovisionnement immédiat requis.',r:0});
    else if(st==='critique')out.push({id:'s'+m.id,sev:'crit',kind:'stock',m,t:`${m.n} · Niveau de stock critique`,x:`${s} unité${s>1?'s':''} restante${s>1?'s':''} (seuil ${m.min}).`,r:1});
    else if(st==='faible'&&SET.low)out.push({id:'s'+m.id,sev:'warn',kind:'stock',m,t:`${m.n} · Stock faible`,x:`${s} unités en stock, seuil ${m.min}.`,r:3});
    m.lots.filter(l=>l.q>0).forEach(l=>{const ls=lotSt(l);if(!SET.exp)return;
      if(ls.k==='expired')out.push({id:'e'+m.id+l.lot,sev:'crit',kind:'exp',m,l,t:`${m.n} · Lot expiré`,x:`Lot ${l.lot} expiré depuis ${-ls.d} j · ${l.q} unités à retirer.`,r:2});
      else if(ls.k==='soon')out.push({id:'e'+m.id+l.lot,sev:ls.d<=15?'crit':'warn',kind:'exp',m,l,t:`${m.n} · Péremption proche`,x:`Le lot ${l.lot} expire dans ${ls.d} jours (${l.q} unités).`,r:ls.d<=15?2:4})})});
  return out.filter(a=>!DISM.has(a.id)).sort((a,b)=>a.r-b.r)}
const navBadge=()=>({inv:MEDS.filter(m=>status(m)!=='ok').length,ex:allLots().filter(x=>x.st.k==='expired'||x.st.k==='soon').length});
let NEWNET=0,NEWCOUNT=0,WRITEOFF=0;
const todayNet=()=>TODAY_BASE+NEWNET,todayCount=()=>28+NEWCOUNT;
function csvOf(rows){return rows.map(r=>r.map(v=>{v=String(v);return /[;"\n]/.test(v)?'"'+v.replace(/"/g,'""')+'"':v}).join(';')).join('\n')}

/* ================= état UI ================= */
const U={view:'db',sf:'all',sq:'',af:'all',alAll:false,actAll:false,pq:'',pcat:'Tous',pay:'Espèces',paid:'',rxok:false,cn:'',cp:'',iq:'',icat:'all',ist:'all',cq:'',csel:1,xf:'all',salq:'',salpay:'Toutes',salmore:25,per:'week',aper:'month',menu:null,gq:'',user:1,ordTab:'open'};
const CART=new Map();
const NAV=[['db','Tableau de bord','home',0],['pos','Point de vente','cart',0],['inv','Inventaire','box',0],['cl','Clients','user',0],['ex',"Suivi d'expiration",'alert',0],['an','Analytique','chart',1],['sa','Rapports de vente','trend',1],['su','Fournisseurs','truck',1],['st','Accès du personnel','shield',1],['se','Paramètres','gear',1]];
const curUser=()=>STAFF.find(s=>s.id===U.user);
const can=k=>PERM[curUser().role].has(k);

/* ================= coque ================= */
function renderSide(){
  const b=navBadge(),u=curUser(),g=['MENU PRINCIPAL','GESTION'];let h=`<div class="brand"><div class="logo">${I('pill','lg')}</div><div><b>PharmaERP</b><span>Plateforme d'entreprise</span></div></div>`;
  [0,1].forEach(gi=>{const its=NAV.filter(n=>n[3]===gi&&can(n[0]));if(its.length)h+=`<div class="navgroup">${g[gi]}</div><nav class="nav" aria-label="${g[gi]}">${its.map(n=>`<button data-a="go" data-v="${n[0]}" ${U.view===n[0]?'aria-current="page"':''}>${I(n[2])}<span>${n[1]}</span>${b[n[0]]?`<span class="badge" aria-label="${b[n[0]]} à traiter">${b[n[0]]}</span>`:''}</button>`).join('')}</nav>`});
  h+=`<div class="sidefoot"><button class="me" data-a="menu" data-v="user" aria-label="Changer d'utilisateur"><span class="av on" style="background:${AVC[u.id%6]}">${initials(u.n)}</span><span class="grow"><b>${esc(u.n)}</b><small>${esc(u.role)}</small></span>${I('chevron','sm')}</button></div>`;
  $('#side').innerHTML=h}
function searchMenu(){const q=norm(U.gq.trim());if(q.length<2)return'';
  const ms=MEDS.filter(m=>norm(m.n).includes(q)||m.bc.includes(q)||norm(m.cat).includes(q)).slice(0,5),cs=CLI.filter(c=>norm(c.n).includes(q)||c.ph.replace(/\s/g,'').includes(q.replace(/\s/g,''))).slice(0,4),ss=SALES.filter(s=>norm(s.id).includes(q)).slice(0,4);
  if(!ms.length&&!cs.length&&!ss.length)return`<div class="menu"><div class="empty">Aucun résultat pour « ${esc(U.gq)} ».<br>Vérifiez l'orthographe ou cherchez par code-barres.</div></div>`;
  return`<div class="menu">${ms.length?'<h4>Médicaments</h4>':''}${ms.map(m=>`<button class="mi" data-a="gs-med" data-id="${m.id}">${I('pill')}<span><b>${esc(m.n)}</b><small>${esc(m.cat)} · stock ${stock(m)} · ${eg(m.price,1)}</small></span></button>`).join('')}${cs.length?'<h4>Clients</h4>':''}${cs.map(c=>`<button class="mi" data-a="gs-cli" data-id="${c.id}">${I('user')}<span><b>${esc(c.n)}</b><small>${esc(c.ph)}</small></span></button>`).join('')}${ss.length?'<h4>Factures</h4>':''}${ss.map(s=>`<button class="mi" data-a="receipt" data-id="${s.id}">${I('file')}<span><b>${s.id}</b><small>${fd(s.ts)} · ${eg(s.total,1)}</small></span></button>`).join('')}</div>`}
function renderTop(){
  const al=alerts(),crit=al.filter(a=>a.sev==='crit'),u=curUser(),m=U.menu,dark=document.documentElement.dataset.theme==='dark'||(!document.documentElement.dataset.theme&&matchMedia('(prefers-color-scheme:dark)').matches);
  $('#top').innerHTML=`<button class="iconbtn" id="menubtn" data-a="navtoggle" aria-label="Ouvrir le menu">${I('menu')}</button>
  <div class="ttl"><h1>${NAV.find(n=>n[0]===U.view)[1]}</h1><div class="sub">Mercredi 28 octobre 2026 · <span id="clock">${ftime(new Date())}</span></div></div>
  <div class="gsearch"><label class="field">${I('search')}<span class="sr">Recherche globale</span><input id="gq" data-in="gq" value="${esc(U.gq)}" placeholder="Rechercher un médicament, un client, une facture…" autocomplete="off"></label>${m==='search'?searchMenu():''}</div>
  <button class="iconbtn" data-a="theme" aria-label="Changer de thème">${I(dark?'sun':'moon')}</button>
  <div class="menuwrap"><button class="iconbtn" data-a="menu" data-v="bell" aria-label="Notifications, ${crit.length} critiques">${I('bell')}${crit.length?`<span class="dot">${crit.length}</span>`:''}</button>${m==='bell'?`<div class="menu"><h4>Alertes critiques (${crit.length})</h4>${crit.slice(0,6).map(a=>`<button class="mi" data-a="bell-go" data-id="${a.id}">${I(a.kind==='stock'?'box':'clock')}<span><b>${esc(a.t)}</b><small>${esc(a.x)}</small></span></button>`).join('')||'<div class="empty">Aucune alerte critique.</div>'}<button class="btn ghost" style="width:100%" data-a="go" data-v="db" data-scroll="alerts">Voir toutes les alertes</button></div>`:''}</div>
  <div class="menuwrap"><button class="userbtn" data-a="menu" data-v="user" aria-label="Compte"><span class="av sm" style="background:${AVC[u.id%6]}">${initials(u.n)}</span><span class="nm">${esc(u.role)}</span>${I('chevron','sm')}</button>${m==='user'?`<div class="menu" style="min-width:280px"><h4>Se connecter en tant que</h4>${STAFF.filter(s=>s.on).map(s=>`<button class="mi" data-a="switch-user" data-id="${s.id}" aria-selected="${s.id===u.id}"><span class="av sm" style="background:${AVC[s.id%6]}">${initials(s.n)}</span><span><b>${esc(s.n)}</b><small>${esc(s.role)}</small></span>${s.id===u.id?`<span style="margin-left:auto;color:var(--brand)">${I('check','sm')}</span>`:''}</button>`).join('')}</div>`:''}</div>`}
const V={};
function render(){
  const a=document.activeElement,id=a&&a.id,pos=a&&a.selectionStart;
  renderSide();renderTop();
  NAV.forEach(n=>{const s=$('#'+n[0]);s.hidden=n[0]!==U.view;if(n[0]!==U.view)s.innerHTML=''});
  const v=$('#view'),st=v.scrollTop;$('#'+U.view).innerHTML=V[U.view]();v.scrollTop=st;
  if(id){const el=document.getElementById(id);if(el){el.focus();try{if(pos!=null)el.setSelectionRange(pos,pos)}catch(e){}}}}
function go(k,o){if(!can(k))k=NAV.find(n=>can(n[0]))[0];U.view=k;U.menu=null;$('#app').classList.remove('nav-open');if(o&&o.ui)Object.assign(U,o.ui);render();$('#view').scrollTop=0;
  if(o&&o.scroll)setTimeout(()=>{const el=document.getElementById(o.scroll);if(el)el.scrollIntoView({behavior:'smooth',block:'start'})},30)}
function toast(msg){const t=document.createElement('div');t.className='toast';t.innerHTML=I('check')+esc(msg);$('#toasts').appendChild(t);setTimeout(()=>t.remove(),3400)}
function openDlg(html){const m=$('#modal');m.innerHTML=html;m.classList.add('open');const f=m.querySelector('input:not([type=checkbox]):not([disabled]),select,textarea');if(f&&!f.dataset.nofocus)f.focus()}
function closeDlg(){const m=$('#modal');m.classList.remove('open');m.innerHTML=''}
const dlg=(t,sub,body,foot,wide)=>`<div class="dlg ${wide?'wide':''}" role="dialog" aria-modal="true" aria-label="${esc(t)}"><div class="dh"><div><h3>${t}</h3>${sub?`<p>${sub}</p>`:''}</div><button class="xbtn" style="position:static" data-a="close" aria-label="Fermer">${I('x')}</button></div><div class="db">${body}</div>${foot?`<div class="df">${foot}</div>`:''}</div>`;
const err=(id)=>`<div id="${id}" role="alert" style="color:var(--crit);font-size:13px;font-weight:600;min-height:0"></div>`;
const kpi=(lab,val,icon,col,bg,foot)=>`<div class="card kpi" style="--k:${col};--kb:${bg}"><div class="ico">${I(icon)}</div><div class="lab">${lab}</div><div class="val">${val}</div><div class="foot">${foot}</div></div>`;
const dl=(d)=>d==null?'':`<span class="delta ${d>=0?'up':'down'}">${I(d>=0?'up':'down','sm')}${d>=0?'+':''}${nf1.format(d)} %</span>`;
const segH=(act,opts,cur,counts)=>`<div class="seg" role="group">${opts.map(([k,l])=>`<button data-a="${act}" data-v="${k}" aria-pressed="${cur===k}">${l}${counts&&counts[k]!=null?`<span class="n">${counts[k]}</span>`:''}</button>`).join('')}</div>`;

/* ================= vues : menu principal ================= */
function stockTableDash(rows){return`<div class="tw"><table><thead><tr><th>Médicament</th><th>Catégorie</th><th>Niveau de stock</th><th>Prix</th><th>Statut</th></tr></thead><tbody>${rows.map(m=>{const s=stock(m),st=status(m),col=st==='ok'?'var(--good)':st==='faible'?'var(--warn)':'var(--crit)';
  return`<tr class="${st==='critique'||st==='rupture'?'hl':''}"><td class="med"><b>${esc(m.n)} ${m.rx?'<span class="rx">Rx</span>':''}</b><small>Réf. ${String(m.id).padStart(3,'0')}</small></td><td><span class="tag">${esc(m.cat)}</span></td><td style="min-width:140px"><b class="num">${nfi.format(s)}</b> <span class="mute">unités</span><div class="meter"><i style="width:${Math.min(100,s/(m.min*3)*100)}%;background:${col}"></i></div></td><td class="num">${eg(m.price,1)}</td><td>${stPill(m)}</td></tr>`}).join('')}</tbody></table></div>`}
const alertH=a=>`<div class="alert ${a.sev}"><div class="ai">${I(a.kind==='stock'?'box':'clock')}</div><div><b>${esc(a.t)}</b><p>${esc(a.x)}</p><div class="ft">${a.kind==='stock'?`<button class="btn sm primary" data-a="order" data-id="${a.m.id}">Commander</button>`:`<button class="btn sm primary" data-a="go" data-v="ex" data-xf="${lotSt(a.l).k==='expired'?'expired':'soon'}">Revoir le lot</button>`}</div></div><button class="xbtn" data-a="dismiss" data-id="${esc(a.id)}" aria-label="Ignorer cette alerte">${I('x','sm')}</button></div>`;
V.db=()=>{
  const al=alerts(),crit=al.filter(a=>a.sev==='crit').length,soon=allLots().filter(x=>x.st.k==='soon'),f=U.sf,q=norm(U.sq);
  const cnt={all:MEDS.length,crit:MEDS.filter(m=>['critique','rupture'].includes(status(m))).length,low:MEDS.filter(m=>status(m)==='faible').length,ok:MEDS.filter(m=>status(m)==='ok').length};
  const rows=MEDS.filter(m=>{const s=status(m);return(f==='all'||(f==='crit'?s==='critique'||s==='rupture':f==='low'?s==='faible':s==='ok'))&&(!q||norm(m.n).includes(q)||norm(m.cat).includes(q))}).sort(byUrg);
  const flt=al.filter(a=>U.af==='all'||(U.af==='crit'?a.sev==='crit':a.sev==='warn')),shown=U.alAll?flt:flt.slice(0,4);
  const acts=U.actAll?ACT.slice(0,12):ACT.slice(0,4);
  const reco=MEDS.map(m=>({m,s:stock(m),v:velocity(m)})).filter(x=>x.s/x.v<14).sort((a,b)=>a.s/a.v-b.s/b.v).slice(0,3);
  return`<div class="page"><div class="grid4">
  ${kpi('Références actives',MEDS.length,'box','var(--c1)','var(--brand-50)',`<span>${nfi.format(sum(MEDS,stock))} unités vendables</span>`)}
  ${kpi('Alertes critiques',crit,'alert','var(--crit)','var(--crit-50)','<button class="btn sm" data-a="scroll" data-v="alerts">Traiter</button>')}
  ${kpi('Expirations sous '+SET.expDays+' j',soon.length,'clock','var(--warn)','var(--warn-50)',`<span>${nfi.format(sum(soon,x=>x.l.q))} unités concernées</span>`)}
  ${kpi('Ventes du jour (HT)',eg(todayNet()),'trend','var(--info)','var(--info-50)',`<span>${todayCount()} transactions</span>${dl(12.5)}`)}</div>
  <div class="qa">
   <button data-a="med-new"><span class="ic" style="background:var(--c2)">${I('plus')}</span><span><b>Ajouter un médicament</b><small>Ajout rapide à l'inventaire</small></span></button>
   <button data-a="go" data-v="pos"><span class="ic" style="background:var(--c1)">${I('cart')}</span><span><b>Nouvelle vente</b><small>Ouvrir la caisse</small></span></button>
   <button data-a="cli-new"><span class="ic" style="background:var(--c4)">${I('user')}</span><span><b>Ajouter un client</b><small>Inscription d'un nouveau client</small></span></button>
   <button data-a="report"><span class="ic" style="background:var(--c3)">${I('file')}</span><span><b>Générer un rapport</b><small>Résumé de période à copier</small></span></button></div>
  <div class="cols"><div class="stack" style="gap:20px">
   <section class="card"><div class="hd"><div><h3>État des stocks</h3><p>Suivi en temps réel, classé par urgence</p></div><button class="btn sm" data-a="export-stock">${I('download','sm')}Exporter</button></div><div class="bd stack">
    <div class="row wrap"><label class="field" style="max-width:240px;height:38px">${I('search','sm')}<span class="sr">Filtrer</span><input id="sq" data-in="sq" value="${esc(U.sq)}" placeholder="Rechercher…"></label>${segH('sf',[['all','Tous'],['crit','Critique'],['low','Stock faible'],['ok','En stock']],f,cnt)}</div>
    ${rows.length?stockTableDash(rows.slice(0,8)):`<div class="empty">Aucun médicament ne correspond à ce filtre.</div>`}
    <div class="row between wrap"><span class="mute">Affichage de ${Math.min(8,rows.length)} sur ${rows.length} articles</span><button class="btn sm" data-a="go" data-v="inv">Ouvrir l'inventaire</button></div></div></section></div>
   <div class="stack" style="gap:20px">
   <section class="card" id="alerts"><div class="hd"><div><h3>Centre d'alertes</h3><p>Stocks et péremptions à traiter</p></div>${pill(crit+' critiques','crit')}</div><div class="bd stack">
    ${segH('af',[['all','Toutes'],['crit','Critique'],['warn','À surveiller']],U.af,{all:al.length,crit:al.filter(a=>a.sev==='crit').length,warn:al.filter(a=>a.sev==='warn').length})}
    <div class="alerts">${shown.map(alertH).join('')||`<div class="empty">${I('check','lg')}Rien à traiter pour le moment.</div>`}</div>
    <div class="row between wrap"><span class="mute">Affichage de ${shown.length} alertes sur ${flt.length}</span>${flt.length>4?`<button class="btn ghost sm" data-a="alall">${U.alAll?'Réduire':'Afficher toutes les alertes'}</button>`:''}</div></div></section>
   <section class="card"><div class="hd"><div><h3>À réapprovisionner</h3><p>Calculé sur les ventes des 30 derniers jours</p></div></div><div class="bd stack">${reco.map(({m,s,v})=>`<div class="reco"><div class="row between"><b>${esc(m.n)}</b>${pill(s===0?'Rupture':nf1.format(s/v)+' j de couverture',s/v<5?'crit':'warn')}</div><span class="mute">Ventes moyennes : ${nf1.format(v)} unités par jour · stock ${s}</span><div><button class="btn sm primary" data-a="order" data-id="${m.id}">${I('plus','sm')}Commander +${suggest(m)} unités</button></div></div>`).join('')||'<div class="empty">Couverture suffisante sur toutes les références.</div>'}</div></section>
   <section class="card"><div class="hd"><div><h3>Activité récente</h3><p>Dernières mises à jour du système</p></div></div><div class="bd"><div class="feed">${acts.map(a=>`<div class="it"><div class="ic">${I(a.icon)}</div><div><b>${esc(a.title)}</b><span class="mute">${esc(a.text)}</span><small>${ago(a.ts)}</small></div></div>`).join('')}</div>${ACT.length>4?`<button class="btn" style="width:100%;margin-top:10px" data-a="actall">${U.actAll?'Réduire':'Afficher toutes les activités'}</button>`:''}</div></section></div></div></div>`};

V.pos=()=>{
  const cats=['Tous',...new Set(MEDS.map(m=>m.cat))],q=norm(U.pq);
  const list=MEDS.filter(m=>(U.pcat==='Tous'||m.cat===U.pcat)&&(!q||norm(m.n).includes(q)||m.bc.includes(q)));
  const lines=[...CART].map(([id,n])=>({m:medById(id),n})),sub=sum(lines,l=>l.m.price*l.n),tax=sub*SET.tax/100,tot=sub+tax,hasRx=lines.some(l=>l.m.rx);
  const paid=parseFloat(String(U.paid).replace(',','.'))||0,canPay=lines.length&&(!hasRx||U.rxok)&&(U.pay==='Carte'||paid>=tot-.001),chg=Math.max(0,paid-tot);
  return`<div class="page"><div class="pagehead"><div><h2>Point de vente</h2><p>Sélectionnez les médicaments à ajouter au panier, puis encaissez.</p></div></div>
  <div class="pos"><div class="stack"><label class="field">${I('search')}<span class="sr">Rechercher</span><input id="pq" data-in="pq" value="${esc(U.pq)}" placeholder="Scannez un code-barres ou tapez un nom, une catégorie…" autocomplete="off"></label>
   <div class="seg" role="group">${cats.map(c=>`<button data-a="pcat" data-v="${esc(c)}" aria-pressed="${U.pcat===c}">${esc(c)}</button>`).join('')}</div>
   <div class="pgrid">${list.map(m=>{const s=stock(m),st=status(m),exp=m.lots.some(l=>{const k=lotSt(l);return l.q>0&&k.k==='soon'});
    return`<button class="prod" data-a="padd" data-id="${m.id}" ${s===0?'disabled':''}><span class="tagrow"><span class="tag">${esc(m.cat)}</span>${m.rx?'<span class="rx">Rx</span>':''}</span><span class="add">${I('plus','sm')}</span><b>${esc(m.n)}</b><span class="pr num">${nf2.format(m.price)} EGP</span>${s===0?pill('Rupture','crit'):pill('Stock : '+s,st==='ok'?'good':st==='faible'?'warn':'crit')}${exp&&s>0?`<small class="mute">Lot proche de la péremption</small>`:''}</button>`}).join('')||'<div class="empty">Aucun produit trouvé. Essayez un autre nom ou un code-barres.</div>'}</div></div>
  <aside class="card cart"><div class="row between"><h3>Commande actuelle</h3>${lines.length?`<button class="btn ghost sm" data-a="cart-clear">${I('trash','sm')}Vider</button>`:''}</div>
   <input id="cn" data-in="cn" class="input" value="${esc(U.cn)}" placeholder="Nom du client" aria-label="Nom du client" list="clist"><datalist id="clist">${CLI.map(c=>`<option value="${esc(c.n)}">`).join('')}</datalist>
   <input id="cp" data-in="cp" class="input" value="${esc(U.cp)}" placeholder="Numéro de téléphone" aria-label="Téléphone">
   <div>${lines.length?lines.map(({m,n})=>`<div class="line"><div><b>${esc(m.n)}</b> ${m.rx?'<span class="rx">Rx</span>':''}<small class="mute" style="display:block">${nf2.format(m.price)} EGP l'unité</small></div><b class="num">${eg(m.price*n,1)}</b><div class="qty"><button data-a="qminus" data-id="${m.id}" aria-label="Retirer une unité">${I('minus','sm')}</button><span>${n}</span><button data-a="qplus" data-id="${m.id}" aria-label="Ajouter une unité">${I('plus','sm')}</button></div><button class="btn ghost sm" style="justify-self:end" data-a="qdel" data-id="${m.id}">${I('trash','sm')}Retirer</button></div>`).join(''):`<div class="empty">${I('cart','lg')}Aucun article dans le panier.<br>Touchez un produit pour l'ajouter.</div>`}</div>
   ${hasRx?`<label class="banner" style="background:var(--info-50);color:var(--info);gap:10px;cursor:pointer"><input type="checkbox" class="chk" data-chk="rxok" id="rxok" ${U.rxok?'checked':''}> Ordonnance vérifiée (obligatoire pour ${lines.filter(l=>l.m.rx).length} article${lines.filter(l=>l.m.rx).length>1?'s':''})</label>`:''}
   <div class="seg" style="display:flex"><button style="flex:1;justify-content:center" data-a="pay" data-v="Espèces" aria-pressed="${U.pay==='Espèces'}">${I('cash','sm')}Espèces</button><button style="flex:1;justify-content:center" data-a="pay" data-v="Carte" aria-pressed="${U.pay==='Carte'}">${I('card','sm')}Carte</button></div>
   <div class="stack" style="gap:6px"><div class="tot"><span>Sous-total HT</span><b class="num">${eg(sub,1)}</b></div><div class="tot"><span>TVA (${SET.tax} %)</span><b class="num">${eg(tax,1)}</b></div><div class="tot big"><span>Total TTC</span><span class="num" style="color:var(--good)">${eg(tot,1)}</span></div></div>
   ${U.pay==='Espèces'?`<div><label class="lb" for="paid">Montant payé</label><div class="row"><input id="paid" data-in="paid" class="input" inputmode="decimal" value="${esc(U.paid)}" placeholder="0,00"><button class="btn" data-a="exact" ${lines.length?'':'disabled'}>Exact</button></div></div><div class="tot"><span>Monnaie à rendre</span><b class="num" style="color:var(--good)">${eg(chg,1)}</b></div>`:''}
   <button class="btn primary" style="height:46px" data-a="checkout" ${canPay?'':'disabled'}>${I('check')}Encaisser ${eg(tot,1)}</button>
   ${lines.length&&!canPay?`<small class="mute">${hasRx&&!U.rxok?'Confirmez la vérification de l\'ordonnance.':U.pay==='Espèces'&&paid<tot?'Saisissez un montant payé suffisant.':''}</small>`:''}</aside></div></div>`};

V.inv=()=>{
  const q=norm(U.iq),cats=[...new Set(MEDS.map(m=>m.cat))].sort();
  const cnt={all:MEDS.length,ok:0,low:0,crit:0};MEDS.forEach(m=>{const s=status(m);if(s==='ok')cnt.ok++;else if(s==='faible')cnt.low++;else cnt.crit++});
  const rows=MEDS.filter(m=>{const s=status(m);return(U.icat==='all'||m.cat===U.icat)&&(U.ist==='all'||(U.ist==='ok'?s==='ok':U.ist==='low'?s==='faible':s==='critique'||s==='rupture'))&&(!q||norm(m.n).includes(q)||norm(m.cat).includes(q)||m.bc.includes(q))}).sort(byUrg);
  const al=alerts(),open=ORDERS.filter(o=>o.st==='open'),done=ORDERS.filter(o=>o.st==='done'),ol=U.ordTab==='open'?open:done;
  return`<div class="page"><div class="pagehead"><div><h2>Gestion des stocks</h2><p>Gérez tous les médicaments et produits de votre pharmacie.</p></div><div class="actions"><button class="btn" data-a="review">${I('clipboard','sm')}Revue des actions<span class="pill crit nodot" style="margin-left:4px">${al.length}</span></button><button class="btn" style="border-color:var(--good);color:var(--good)" data-a="order-crit">${I('cart','sm')}Commander les critiques</button><button class="btn primary" data-a="med-new">${I('plus','sm')}Ajouter un médicament</button></div></div>
  <section class="card"><div class="bd stack"><div class="row wrap"><label class="field grow">${I('search')}<span class="sr">Rechercher</span><input id="iq" data-in="iq" value="${esc(U.iq)}" placeholder="Rechercher par nom, catégorie ou code-barres…"></label><select class="select" style="width:200px" data-sel="icat" aria-label="Catégorie"><option value="all">Toutes les catégories</option>${cats.map(c=>`<option ${U.icat===c?'selected':''}>${esc(c)}</option>`).join('')}</select></div>
   ${segH('ist',[['all','Tous'],['ok','En stock'],['low','Stock faible'],['crit','Critique / rupture']],U.ist,cnt)}
   ${rows.length?`<div class="tw"><table><thead><tr><th>Médicament</th><th>Catégorie</th><th>Stock</th><th>Statut</th><th>Prochaine expiration</th><th>Actions</th></tr></thead><tbody>${rows.map(m=>{const s=stock(m),st=status(m),col=st==='ok'?'var(--good)':st==='faible'?'var(--warn)':'var(--crit)',nx=m.lots.filter(l=>l.q>0&&daysTo(l.exp)>=0).sort((a,b)=>a.exp-b.exp)[0],ls=nx&&lotSt(nx),exq=expQty(m);
    return`<tr class="${st==='critique'||st==='rupture'?'hl':''}"><td class="med"><b>${esc(m.n)} ${m.rx?'<span class="rx">Rx</span>':''}</b><small>Code ${m.bc}</small></td><td><span class="tag">${esc(m.cat)}</span></td><td style="min-width:140px"><b class="num">${nfi.format(s)}</b> <span class="mute">unités</span><div class="meter"><i style="width:${Math.min(100,s/(m.min*3)*100)}%;background:${col}"></i></div>${exq?`<small style="color:var(--crit)">+ ${exq} expirées</small>`:''}</td><td>${stPill(m)}</td><td>${nx?`${fd(nx.exp)}<br>${pill(ls.t,ls.c)}`:'<span class="mute">—</span>'}</td><td><div class="row"><button class="btn ghost sm" data-a="med-edit" data-id="${m.id}">${I('clipboard','sm')}Modifier</button><button class="btn sm" data-a="order" data-id="${m.id}">${I('cart','sm')}Commander</button></div></td></tr>`}).join('')}</tbody></table></div>`:`<div class="empty">Aucun médicament ne correspond à ces filtres.<br><button class="btn sm" data-a="inv-reset">Réinitialiser les filtres</button></div>`}
   <span class="mute">Affichage de ${rows.length} médicaments sur ${MEDS.length}</span></div></section>
  <section class="card"><div class="hd"><div><h3>Commandes fournisseurs</h3><p>Réceptionnez une commande pour ajouter un lot au stock</p></div>${segH('ordtab',[['open','En cours'],['done','Reçues']],U.ordTab,{open:open.length,done:done.length})}</div><div class="bd">
   ${ol.length?`<div class="tw"><table><thead><tr><th>Commande</th><th>Médicament</th><th>Fournisseur</th><th>Quantité</th><th>Livraison</th><th>Coût estimé</th><th></th></tr></thead><tbody>${ol.map(o=>`<tr><td><b>${o.id}</b><br>${o.prio==='Urgent'?pill('Urgent','crit'):pill('Normale','')}</td><td>${esc(medById(o.mid).n)}</td><td>${esc(supById(o.sup).n)}</td><td class="num">${o.qty}</td><td>${fd(o.eta)}</td><td class="num">${eg(o.cost)}</td><td>${o.st==='open'?`<div class="row"><button class="btn sm primary" data-a="receive" data-id="${o.id}">${I('check','sm')}Réceptionner</button><button class="btn ghost sm" data-a="ord-cancel" data-id="${o.id}">Annuler</button></div>`:pill('Reçue','good')}</td></tr>`).join('')}</tbody></table></div>`:`<div class="empty">${U.ordTab==='open'?'Aucune commande en cours. Utilisez « Commander » sur une ligne du tableau.':'Aucune commande reçue pour le moment.'}</div>`}</div></section></div>`};
const expQty=m=>sum(m.lots.filter(l=>daysTo(l.exp)<0),l=>l.q);

V.cl=()=>{
  const q=norm(U.cq),rows=CLI.filter(c=>!q||norm(c.n).includes(q)||c.ph.replace(/\s/g,'').includes(q.replace(/\s/g,''))),c=CLI.find(x=>x.id===U.csel);
  const bt=1240+CLI.length;
  return`<div class="page"><div class="pagehead"><div><h2>Gestion des clients</h2><p>Gérer les informations client et l'historique des achats</p></div><button class="btn primary" data-a="cli-new">${I('plus','sm')}Ajouter un client</button></div>
  <div class="grid4">${kpi('Nombre total de clients',nfi.format(bt),'user','var(--c1)','var(--brand-50)',dl(12))}${kpi('Actifs ce mois-ci','856','users','var(--info)','var(--info-50)',dl(8))}${kpi("Chiffre d'affaires clients",'124,5 k EGP','dollar','var(--good)','var(--good-50)',dl(15))}${kpi('Achat moyen','245 EGP','cart','var(--c4)','var(--brand-50)',dl(5))}</div>
  <div class="cols"><section class="card"><div class="bd stack"><label class="field">${I('search')}<span class="sr">Rechercher</span><input id="cq" data-in="cq" value="${esc(U.cq)}" placeholder="Rechercher un client par nom ou téléphone…"></label>
   ${rows.length?`<div class="tw"><table><thead><tr><th>Client</th><th>Contact</th><th>Achats totaux</th><th>Statut</th><th></th></tr></thead><tbody>${rows.map(r=>`<tr class="click" data-a="cli-sel" data-id="${r.id}" ${r.id===U.csel?'style="background:var(--brand-50)"':''}><td><div class="row"><span class="av sm" style="background:${AVC[r.id%6]}">${initials(r.n)}</span><div class="med"><b>${esc(r.n)}</b><small>ID : ${r.id}</small></div></div></td><td><div>${esc(r.ph)}</div><small class="mute">${esc(r.e)}</small></td><td class="num"><b style="color:var(--good)">${eg(r.tot)}</b></td><td>${pill(r.last.includes('juil')?'Inactif':'Actif',r.last.includes('juil')?'':'good')}</td><td><button class="btn ghost sm" data-a="cli-sel" data-id="${r.id}">Voir</button></td></tr>`).join('')}</tbody></table></div>`:`<div class="empty">Aucun client trouvé.<br><button class="btn sm primary" data-a="cli-new">Ajouter ce client</button></div>`}</div></section>
  <aside class="card">${c?`<div class="bd stack"><div class="row"><span class="av" style="background:${AVC[c.id%6]};width:52px;height:52px;font-size:16px">${initials(c.n)}</span><div><h3>${esc(c.n)}</h3>${pill(c.last.includes('juil')?'Inactif':'Actif',c.last.includes('juil')?'':'good')}</div></div>
   <div class="stack" style="gap:6px"><div class="row mute">${I('phone','sm')}${esc(c.ph)}</div><div class="row mute">${I('mail','sm')}${esc(c.e)}</div></div>
   <div class="grid2"><div class="mini"><small>Achats</small><b>${c.cnt}</b></div><div class="mini"><small>Panier moyen</small><b>${c.cnt?eg(c.tot/c.cnt):'—'}</b></div></div>
   <div><h4 style="font-size:14px;margin-bottom:6px">Derniers achats</h4><div class="feed">${SALES.filter(s=>s.cust===c.n).slice(0,3).map(s=>`<button class="it" style="border:0;background:none;text-align:left;padding:11px 0;cursor:pointer;border-bottom:1px solid var(--line-2)" data-a="receipt" data-id="${s.id}"><div class="ic">${I('cart')}</div><div><b>${s.id} · ${eg(s.total,1)}</b><small>${fd(s.ts)} · ${s.items.length} article${s.items.length>1?'s':''}</small></div></button>`).join('')||`<div class="mute" style="padding:8px 0">Dernier achat : ${esc(c.last)}</div>`}</div></div>
   <button class="btn primary" data-a="cli-sale" data-id="${c.id}">${I('cart','sm')}Nouvelle vente pour ${esc(c.n.split(' ')[0])}</button></div>`:`<div class="panel-empty">${I('user','lg')}Sélectionnez un client pour afficher les détails.</div>`}</aside></div></div>`};

V.ex=()=>{
  const lots=allLots(),f=U.xf,exp=lots.filter(x=>x.st.k==='expired'),soon=lots.filter(x=>x.st.k==='soon'),watch=lots.filter(x=>x.st.k==='watch');
  const rows=lots.filter(x=>f==='all'?x.st.k!=='ok':x.st.k===f);
  const risk=sum([...exp,...soon],x=>x.m.cost*x.l.q);
  return`<div class="page"><div class="pagehead"><div><h2>Suivi d'expiration</h2><p>Surveillez les lots dont la date de péremption approche.</p></div></div>
  <div class="grid4">${kpi('Lots expirés',exp.length,'alert','var(--crit)','var(--crit-50)',`<span>${sum(exp,x=>x.l.q)} unités à retirer</span>`)}${kpi('Expirent sous '+SET.expDays+' jours',soon.length,'clock','var(--warn)','var(--warn-50)',`<span>${sum(soon,x=>x.l.q)} unités concernées</span>`)}${kpi('Dans 31 à 90 jours',watch.length,'calendar','var(--good)','var(--good-50)','<span>à surveiller</span>')}${kpi('Valeur à risque',eg(risk),'dollar','var(--info)','var(--info-50)',`<span>au prix d'achat${WRITEOFF?` · ${eg(WRITEOFF)} déjà passés en perte`:''}</span>`)}</div>
  <section class="card"><div class="hd"><h3>Lots à surveiller</h3>${segH('xf',[['all','Tous'],['expired','Expirés'],['soon','Sous '+SET.expDays+' j'],['watch','31 à 90 jours']],f,{all:exp.length+soon.length+watch.length,expired:exp.length,soon:soon.length,watch:watch.length})}</div><div class="bd alerts">
  ${rows.map(x=>`<div class="alert ${x.st.c==='info'?'info':x.st.c}" style="grid-template-columns:36px 1fr auto;align-items:center"><div class="ai">${I(x.st.k==='expired'?'alert':'clock')}</div><div><b>${esc(x.m.n)}</b><p>Lot : ${x.l.lot} · ${x.l.q} unités · ${fd(x.l.exp)}</p></div><div class="row wrap">${pill(x.st.t,x.st.c)}${x.st.k==='expired'?`<button class="btn sm" data-a="writeoff" data-m="${x.m.id}" data-lot="${x.l.lot}">${I('trash','sm')}Retirer du stock</button>`:`<button class="btn sm" data-a="order" data-id="${x.m.id}">${I('cart','sm')}Commander</button>`}</div></div>`).join('')||`<div class="empty">${I('check','lg')}Aucun lot dans cette catégorie.</div>`}</div></section></div>`};

/* ================= vues : gestion ================= */
const anSeries=p=>{const a=AN[p];return a.labels.map((l,i)=>({label:l,long:a.long[i],rev:a.rev[i],pf:Math.round(a.rev[i]*.288)}))};
V.an=()=>{
  const a=AN[U.aper],b=anSeries(U.aper),rev=sum(b,x=>x.rev),pf=sum(b,x=>x.pf),sales=Math.round(rev/72.4),cli=Math.round(sales*.189);
  const cats=CATSHARE.map(([n,v],i)=>({name:n,v:v*rev/100,color:`var(--c${i+1})`}));
  return`<div class="page"><div class="pagehead"><div><h2>Analyses et rapports</h2><p>Analyses commerciales complètes et indicateurs de performance · ${a.name}</p></div><div class="actions">${segH('aper',[['week','Semaine'],['month','Mois'],['year','Année']],U.aper)}<button class="btn" data-a="report">${I('file','sm')}Rapport</button></div></div>
  <div class="grid4">${kpi("Chiffre d'affaires",eg(rev),'dollar','var(--good)','var(--good-50)',dl(a.d[0])+'<span>vs période précédente</span>')}${kpi('Bénéfice net',eg(pf),'trend','var(--info)','var(--info-50)',dl(a.d[1])+'<span>vs période précédente</span>')}${kpi('Ventes totales',nfi.format(sales),'box','var(--warn)','var(--warn-50)',dl(a.d[2])+'<span>vs période précédente</span>')}${kpi('Clients actifs',nfi.format(cli),'users','var(--crit)','var(--crit-50)',dl(a.d[3])+'<span>vs période précédente</span>')}</div>
  <div class="chartgrid"><section class="card"><div class="hd"><h3>Revenus et bénéfices</h3><div class="legend"><span><i style="background:var(--c1)"></i>Revenu</span><span><i style="background:var(--c2)"></i>Bénéfice</span></div></div><div class="bd">${PharmaCharts.barChart(b,[{key:'rev',color:'var(--c1)',name:'Revenu'},{key:'pf',color:'var(--c2)',name:'Bénéfice'}])}</div></section>
  <section class="card"><div class="hd"><h3>Ventes par catégorie</h3></div><div class="bd">${PharmaCharts.donut(cats)}<div class="legend col">${CATSHARE.map(([n,v],i)=>`<span><span><i style="background:var(--c${i+1})"></i>${n}</span><b>${v} %</b></span>`).join('')}</div></div></section></div>
  <div class="chartgrid"><section class="card"><div class="hd"><h3>Médicaments les plus vendus</h3></div><div class="bd toplist">${TOP.map(([n,u,p,t,up],i)=>{const uu=Math.round(u*a.f);return`<div class="toprow"><div class="rank">${i+1}</div><div><b>${n}</b><small>${nfi.format(uu)} unités vendues</small></div><div class="amt">${eg(uu*p)}<br><span class="delta ${up?'up':'down'}">${I(up?'up':'down','sm')}${t} %</span></div></div>`}).join('')}</div></section>
  <section class="card"><div class="hd"><h3>Transactions des 7 derniers jours</h3></div><div class="bd">${PharmaCharts.lineChart(LINE.map((v,i)=>({label:LINEL[i],long:LINEL[i],v:v+(i===6?NEWCOUNT:0)})))}</div></section></div></div>`};

V.sa=()=>{
  const q=norm(U.salq),rows=SALES.filter(s=>(U.salpay==='Toutes'||s.pay===U.salpay)&&(!q||norm(s.id).includes(q)||norm(s.cust).includes(q)));
  return`<div class="page"><div class="pagehead"><div><h2>Rapports de vente</h2><p>Visualisez et analysez les performances de vente</p></div><button class="btn" data-a="export-sales">${I('download','sm')}Exporter en CSV</button></div>
  <div class="grid3">${kpi('Ventes du jour (HT)',eg(todayNet()),'dollar','var(--good)','var(--good-50)',dl(12.5)+'<span>par rapport à hier</span>')}${kpi('Cette semaine (HT)',eg(WEEK_BASE+todayNet()),'trend','var(--info)','var(--info-50)',dl(8.2)+'<span>par rapport à la semaine dernière</span>')}${kpi('Transactions (7 jours)',nfi.format(187+NEWCOUNT),'cart','var(--c4)','var(--brand-50)','<span>sur 7 jours glissants</span>')}</div>
  <section class="card"><div class="hd"><h3>Transactions récentes</h3><div class="row wrap"><label class="field" style="height:38px;width:230px">${I('search','sm')}<span class="sr">Rechercher</span><input id="salq" data-in="salq" value="${esc(U.salq)}" placeholder="Facture ou client…"></label>${segH('salpay',[['Toutes','Toutes'],['Espèces','Espèces'],['Carte','Carte']],U.salpay)}</div></div><div class="bd">
  ${rows.length?`<div class="tw"><table><thead><tr><th>Facture</th><th>Date</th><th>Client</th><th>Articles</th><th class="right">Montant TTC</th><th>Paiement</th></tr></thead><tbody>${rows.slice(0,U.salmore).map(s=>`<tr class="click" data-a="receipt" data-id="${s.id}"><td><b style="color:var(--brand)">${s.id}</b></td><td>${fd(s.ts)} · ${ftime(s.ts)}</td><td>${esc(s.cust||'Passage')}</td><td>${sum(s.items,i=>i.q)} article${sum(s.items,i=>i.q)>1?'s':''}</td><td class="right num"><b>${eg(s.total,1)}</b></td><td><span class="tag">${s.pay}</span></td></tr>`).join('')}</tbody></table></div>`:'<div class="empty">Aucune transaction ne correspond à ces filtres.</div>'}</div></section></div>`};

V.su=()=>`<div class="page"><div class="pagehead"><div><h2>Fournisseurs</h2><p>Gérer les informations et les commandes des fournisseurs</p></div><button class="btn primary" data-a="sup-new">${I('plus','sm')}Ajouter un fournisseur</button></div><div class="cards3">${SUP.map(s=>{const n=MEDS.filter(m=>m.sup===s.id).length,o=ORDERS.filter(x=>x.sup===s.id&&x.st==='open').length;
  return`<div class="card sup"><h3>${esc(s.n)}</h3><dl><dt>Contact</dt><dd>${esc(s.c)}</dd><dt>Téléphone</dt><dd class="num">${esc(s.ph)}</dd><dt>Produits fournis</dt><dd style="color:var(--good)">${n} article${n>1?'s':''}</dd><dt>Délai de livraison</dt><dd>${s.lead} jours</dd><dt>Commandes en cours</dt><dd>${o||'Aucune'}</dd></dl><button class="btn" data-a="sup-view" data-id="${s.id}">Voir les détails</button></div>`}).join('')}</div></div>`;

V.st=()=>`<div class="page"><div class="pagehead"><div><h2>Accès du personnel</h2><p>Gérer les rôles et les permissions des utilisateurs</p></div><button class="btn primary" data-a="staff-new">${I('plus','sm')}Ajouter un membre</button></div>
  <section class="card">${STAFF.map(s=>{const [c,ic]=ROLECLS[s.role];return`<div class="staff"><span class="av" style="background:${AVC[s.id%6]}">${initials(s.n)}</span><div class="grow"><b>${esc(s.n)}</b><div class="mute">${esc(s.e)}</div><span class="rolepill ${c}">${I(ic,'sm')}${esc(s.role)}</span></div>${pill(s.on?'Actif':'Désactivé',s.on?'good':'')}<button class="btn sm" data-a="staff-edit" data-id="${s.id}">Gérer</button></div>`}).join('')}</section>
  <section class="card"><div class="hd"><div><h3>Permissions par rôle</h3><p>Cochez un module pour l'autoriser. Les menus non autorisés sont masqués pour l'utilisateur.</p></div></div><div class="bd"><div class="tw"><table class="perm"><thead><tr><th>Module</th>${ROLES.map(r=>`<th>${esc(r)}</th>`).join('')}</tr></thead><tbody>${MODS.map(([k,l])=>`<tr><td>${l}</td>${ROLES.map(r=>`<td><input class="chk" type="checkbox" data-perm="${esc(r)}|${k}" ${PERM[r].has(k)?'checked':''} ${r==='Administrateur'?'disabled':''} aria-label="${l} pour ${esc(r)}"></td>`).join('')}</tr>`).join('')}</tbody></table></div></div></section></div>`;

const sw=(t,d,k)=>`<div class="setrow"><div><b>${t}</b><small>${d}</small></div><label class="sw"><input type="checkbox" data-sw="${k}" ${SET[k]?'checked':''} aria-label="${t}"><i></i></label></div>`;
V.se=()=>{const th=document.documentElement.dataset.theme||'auto';return`<div class="page" style="max-width:860px"><div class="pagehead"><div><h2>Paramètres</h2><p>Configurer les préférences du système</p></div></div>
  <section class="card"><div class="bd setgroup"><div class="ico">${I('bell')}</div><div class="body"><h3>Notifications</h3><p class="d">Choisissez les alertes affichées dans le centre d'alertes</p>${sw('Alertes de stock faible','Stock sous le seuil minimal','low')}${sw("Notifications d'expiration",'Lots expirés ou proches de la péremption','exp')}${sw('Résumé quotidien des ventes',"Ajouté à l'activité récente",'report')}</div></div></section>
  <section class="card"><div class="bd setgroup"><div class="ico">${I('gear')}</div><div class="body"><h3>Pharmacie</h3><p class="d">Valeurs utilisées dans la caisse, les alertes et les rapports</p><div class="grid2"><div><label class="lb" for="s-tax">TVA (%)</label><input id="s-tax" class="input" inputmode="numeric" data-set="tax" value="${SET.tax}"></div><div><label class="lb" for="s-exp">Alerte de péremption (jours)</label><input id="s-exp" class="input" inputmode="numeric" data-set="expDays" value="${SET.expDays}"></div></div></div></div></section>
  <section class="card"><div class="bd setgroup"><div class="ico">${I('lock')}</div><div class="body"><h3>Sécurité</h3><p class="d">Mettez à jour vos paramètres de sécurité</p><button class="btn" data-a="pwd">Changer le mot de passe</button></div></div></section>
  <section class="card"><div class="bd setgroup"><div class="ico">${I('globe')}</div><div class="body"><h3>Langue et région</h3><p class="d">Langue, devise et apparence</p><div class="grid3"><div><label class="lb" for="l1">Langue</label><select id="l1" class="select"><option>Français</option><option disabled>العربية (bientôt)</option></select></div><div><label class="lb" for="l2">Devise</label><select id="l2" class="select"><option>EGP · Livre égyptienne</option></select></div><div><label class="lb">Thème</label>${segH('themeset',[['light','Clair'],['dark','Sombre'],['auto','Auto']],th)}</div></div></div></div></section></div>`};

/* ================= modales ================= */
function orderDlg(mid,pre){
  const m=medById(mid),qty=(pre&&pre.qty)||suggest(m),sup=supById(m.sup),eta=isoD(addDays(sup.lead));
  openDlg(dlg('Nouvelle commande',`${esc(m.cat)} · Stock actuel : ${stock(m)} unités`,`<span class="pill good nodot" style="align-self:flex-start">${esc(m.n)}</span>
   <div><label class="lb" for="o-sup">Fournisseur</label><select id="o-sup" class="select" data-oc>${SUP.map(s=>`<option value="${s.id}" ${s.id===m.sup?'selected':''}>${esc(s.n)}</option>`).join('')}</select></div>
   <div class="grid2"><div><label class="lb" for="o-qty">Quantité (unités)</label><input id="o-qty" class="input" inputmode="numeric" value="${qty}" data-oc></div><div><label class="lb">Priorité</label><div class="seg" style="display:flex" id="o-prio"><button type="button" style="flex:1;justify-content:center" data-a="prio" data-v="Normale" aria-pressed="true">Normale</button><button type="button" style="flex:1;justify-content:center" data-a="prio" data-v="Urgent" aria-pressed="false">Urgent</button></div></div></div>
   <div><label class="lb" for="o-eta">Livraison prévue</label><input id="o-eta" class="input" type="date" value="${eta}"></div>
   <div><label class="lb" for="o-note">Notes (facultatives)</label><textarea id="o-note" class="textarea" placeholder="Instructions particulières ou exigences relatives aux lots…"></textarea></div>
   ${err('o-err')}<div class="estimate"><div class="row">${I('box')}<span>Estimation du coût total<br><small id="o-det"></small></span></div><b id="o-tot"></b></div><input type="hidden" id="o-mid" value="${m.id}">`,
   `<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="order-save">${I('cart','sm')}Passer la commande</button>`));
  orderCalc()}
function orderCalc(){const m=medById(+$('#o-mid').value),q=parseInt($('#o-qty').value)||0;$('#o-tot').textContent=eg(q*m.cost);$('#o-det').textContent=`${q} unités × ${nf2.format(m.cost)} EGP · hors taxes`;}
function setEta(){const s=supById(+$('#o-sup').value),urg=$('#o-prio button[aria-pressed=true]').dataset.v==='Urgent';$('#o-eta').value=isoD(addDays(urg?Math.max(1,Math.ceil(s.lead/2)):s.lead))}
function nextOrderId(){return 'CMD-'+(2040+ORDERS.length+1)}
function medDlg(id){
  const m=id?medById(id):null;
  openDlg(dlg(m?'Modifier le médicament':'Ajouter un médicament',m?esc(m.n):"Renseignez l'article et son premier lot",`
   <div><label class="lb" for="f-n">Nom et dosage</label><input id="f-n" class="input" value="${esc(m?m.n:'')}" placeholder="Ex. Paracétamol 500 mg"></div>
   <div class="grid2"><div><label class="lb" for="f-c">Catégorie</label><input id="f-c" class="input" list="cats" value="${esc(m?m.cat:'')}" placeholder="Choisir ou saisir"><datalist id="cats">${[...new Set(MEDS.map(x=>x.cat))].map(c=>`<option value="${esc(c)}">`).join('')}</datalist></div><div><label class="lb" for="f-s">Fournisseur</label><select id="f-s" class="select">${SUP.map(s=>`<option value="${s.id}" ${m&&m.sup===s.id?'selected':''}>${esc(s.n)}</option>`).join('')}</select></div></div>
   <div class="grid3"><div><label class="lb" for="f-p">Prix de vente (EGP)</label><input id="f-p" class="input" inputmode="decimal" value="${m?m.price:''}"></div><div><label class="lb" for="f-k">Prix d'achat (EGP)</label><input id="f-k" class="input" inputmode="decimal" value="${m?m.cost:''}"></div><div><label class="lb" for="f-m">Seuil minimal</label><input id="f-m" class="input" inputmode="numeric" value="${m?m.min:50}"></div></div>
   <label class="row" style="gap:10px"><input id="f-rx" type="checkbox" class="chk" ${m&&m.rx?'checked':''}> Délivrance sur ordonnance (Rx)</label>
   ${m?'':`<div class="grid3"><div><label class="lb" for="f-lot">Numéro de lot</label><input id="f-lot" class="input" placeholder="Ex. LOT26-01"></div><div><label class="lb" for="f-q">Quantité reçue</label><input id="f-q" class="input" inputmode="numeric" value="100"></div><div><label class="lb" for="f-e">Expiration</label><input id="f-e" class="input" type="date" value="${isoD(addDays(540))}"></div></div>`}
   ${err('f-err')}<input type="hidden" id="f-id" value="${m?m.id:''}">`,
   `<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="med-save">${m?'Enregistrer':'Ajouter à l\'inventaire'}</button>`))}
function cliDlg(){openDlg(dlg('Ajouter un client',"Inscription d'un nouveau client",`<div><label class="lb" for="c-n">Nom complet</label><input id="c-n" class="input"></div><div class="grid2"><div><label class="lb" for="c-p">Téléphone</label><input id="c-p" class="input" placeholder="+20 1XX XXX XXXX"></div><div><label class="lb" for="c-e">E-mail (facultatif)</label><input id="c-e" class="input" type="email"></div></div>${err('c-err')}`,`<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="cli-save">Enregistrer le client</button>`))}
function supDlg(){openDlg(dlg('Ajouter un fournisseur','Coordonnées et délai de livraison',`<div><label class="lb" for="u-n">Nom de l'entreprise</label><input id="u-n" class="input"></div><div class="grid3"><div><label class="lb" for="u-c">Contact</label><input id="u-c" class="input"></div><div><label class="lb" for="u-p">Téléphone</label><input id="u-p" class="input"></div><div><label class="lb" for="u-l">Délai (jours)</label><input id="u-l" class="input" inputmode="numeric" value="3"></div></div>${err('u-err')}`,`<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="sup-save">Ajouter</button>`))}
function staffDlg(id){const s=id?STAFF.find(x=>x.id===id):null;openDlg(dlg(s?'Gérer '+esc(s.n):'Ajouter un membre',s?esc(s.e):"Il pourra se connecter avec ce rôle",`${s?'':`<div class="grid2"><div><label class="lb" for="t-n">Nom complet</label><input id="t-n" class="input"></div><div><label class="lb" for="t-e">E-mail</label><input id="t-e" class="input" type="email"></div></div>`}<div><label class="lb" for="t-r">Rôle</label><select id="t-r" class="select">${ROLES.map(r=>`<option ${s&&s.role===r?'selected':''}>${esc(r)}</option>`).join('')}</select></div>${s?`<div class="setrow"><div><b>Compte actif</b><small>Un compte désactivé ne peut plus se connecter</small></div><label class="sw"><input id="t-on" type="checkbox" ${s.on?'checked':''} ${s.id===1?'disabled':''}><i></i></label></div>`:''}${err('t-err')}<input type="hidden" id="t-id" value="${s?s.id:''}">`,`<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="staff-save">${s?'Enregistrer':'Ajouter'}</button>`))}
function receiptTxt(s){const w=38,ln='-'.repeat(w);return[`PHARMACIE PHARMAERP`,`Facture ${s.id}`,`${fd(s.ts)} ${ftime(s.ts)}`,`Client : ${s.cust||'Passage'}`,ln,...s.items.map(i=>pad(`${i.q} x ${i.n}`,nf2.format(i.p*i.q),w)),ln,pad('Sous-total HT',nf2.format(s.net),w),pad(`TVA ${nf1.format(s.tax/s.net*100)} %`,nf2.format(s.tax),w),pad('TOTAL TTC',nf2.format(s.total),w),pad(`Payé (${s.pay})`,nf2.format(s.paid||s.total),w),...(s.pay==='Espèces'&&s.paid>s.total?[pad('Rendu',nf2.format(s.paid-s.total),w)]:[]),ln,'Merci de votre visite'].join('\n')}
function receiptDlg(id,fresh){const s=SALES.find(x=>x.id===id);if(!s)return;openDlg(dlg(fresh?'Vente enregistrée':'Facture '+s.id,fresh?`${s.id} · ${eg(s.total,1)} encaissés`:`${fd(s.ts)} · ${s.pay}`,`<pre class="receipt" id="rc">${esc(receiptTxt(s))}</pre>`,`<button class="btn" data-a="copy" data-t="rc">${I('copy','sm')}Copier le reçu</button><button class="btn primary" data-a="close">${fresh?'Nouvelle vente':'Fermer'}</button>`))}
function csvDlg(title,sub,rows){openDlg(dlg(title,sub,`<textarea id="csv" class="textarea" style="height:220px;font-family:ui-monospace,Menlo,monospace;font-size:12px" readonly>${esc(csvOf(rows))}</textarea><small class="mute">Séparateur point-virgule, compatible Excel. ${rows.length-1} lignes.</small>`,`<button class="btn" data-a="close">Fermer</button><button class="btn primary" data-a="copy" data-t="csv">${I('copy','sm')}Copier le CSV</button>`,true))}
function reportDlg(p){p=p||'month';const a=AN[p],b=anSeries(p),rev=sum(b,x=>x.rev),pf=sum(b,x=>x.pf),al=alerts();
  const txt=`RAPPORT PHARMAERP · ${a.name}\nChiffre d'affaires HT : ${eg(rev)}\nBénéfice net : ${eg(pf)} (${nf1.format(pf/rev*100)} %)\nVentes : ${nfi.format(Math.round(rev/72.4))}\n\nTop ventes :\n${TOP.slice(0,3).map(t=>`- ${t[0]} : ${nfi.format(Math.round(t[1]*a.f))} unités`).join('\n')}\n\nÀ traiter : ${al.filter(x=>x.sev==='crit').length} alertes critiques, ${allLots().filter(x=>x.st.k==='expired').length} lot(s) expiré(s)`;
  openDlg(dlg('Générer un rapport','Résumé de la période, prêt à copier',`${segH('rper',[['week','Semaine'],['month','Mois'],['year','Année']],p)}<pre class="receipt" id="rep">${esc(txt)}</pre>`,`<button class="btn" data-a="close">Fermer</button><button class="btn primary" data-a="copy" data-t="rep">${I('copy','sm')}Copier le rapport</button>`));
  if(!window.__repLogged){logAct('file','Rapport généré',a.name);window.__repLogged=1}}

/* ================= actions ================= */
const A={
 go:(t)=>go(t.dataset.v,{ui:t.dataset.xf?{xf:t.dataset.xf}:null,scroll:t.dataset.scroll}),
 close:closeDlg,
 navtoggle:()=>$('#app').classList.toggle('nav-open'),
 menu:t=>{U.menu=U.menu===t.dataset.v?null:t.dataset.v;renderTop()},
 theme:()=>{const d=document.documentElement,dark=d.dataset.theme==='dark'||(!d.dataset.theme&&matchMedia('(prefers-color-scheme:dark)').matches);d.dataset.theme=dark?'light':'dark';render()},
 themeset:t=>{if(t.dataset.v==='auto')delete document.documentElement.dataset.theme;else document.documentElement.dataset.theme=t.dataset.v;render()},
 'switch-user':t=>{U.user=+t.dataset.id;U.menu=null;const u=curUser();toast('Connecté : '+u.n+' ('+u.role+')');go(can(U.view)?U.view:NAV.find(n=>can(n[0]))[0])},
 'bell-go':t=>{const a=alerts().find(x=>x.id===t.dataset.id);U.menu=null;if(a&&a.kind==='stock')orderDlg(a.m.id);else go('ex',{ui:{xf:'all'}});renderTop()},
 'gs-med':t=>{const m=medById(+t.dataset.id);U.menu=null;U.gq='';go('inv',{ui:{iq:m.n,ist:'all',icat:'all'}})},
 'gs-cli':t=>{U.menu=null;U.gq='';go('cl',{ui:{csel:+t.dataset.id,cq:''}})},
 scroll:t=>{const el=document.getElementById(t.dataset.v);if(el)el.scrollIntoView({behavior:'smooth',block:'start'})},
 sf:t=>{U.sf=t.dataset.v;render()},af:t=>{U.af=t.dataset.v;render()},alall:()=>{U.alAll=!U.alAll;render()},actall:()=>{U.actAll=!U.actAll;render()},
 dismiss:t=>{DISM.add(t.dataset.id);render();toast('Alerte ignorée')},
 'export-stock':()=>csvDlg('Exporter le stock','Inventaire complet avec statut',[['Médicament','Catégorie','Stock','Seuil','Prix de vente','Statut'],...[...MEDS].sort(byUrg).map(m=>[m.n,m.cat,stock(m),m.min,m.price,ST[status(m)][0]])]),
 'export-sales':()=>csvDlg('Exporter les ventes','Transactions affichées',[['Facture','Date','Client','Articles','Montant TTC','Paiement'],...SALES.map(s=>[s.id,fd(s.ts)+' '+ftime(s.ts),s.cust||'Passage',sum(s.items,i=>i.q),s.total.toFixed(2).replace('.',','),s.pay])]),
 report:()=>reportDlg(U.aper==='week'?'week':U.view==='an'?U.aper:'month'),rper:t=>reportDlg(t.dataset.v),
 copy:async t=>{const el=document.getElementById(t.dataset.t),txt=el.value!==undefined&&el.tagName==='TEXTAREA'?el.value:el.textContent;try{await navigator.clipboard.writeText(txt);toast('Copié dans le presse-papiers')}catch(e){try{el.select&&el.select();toast('Sélectionnez le texte puis copiez-le (Ctrl+C)')}catch(_){toast('Copie impossible dans ce contexte')}}},
 'med-new':()=>medDlg(),'med-edit':t=>medDlg(+t.dataset.id),
 'med-save':()=>{const n=$('#f-n').value.trim(),c=$('#f-c').value.trim(),p=parseFloat($('#f-p').value.replace(',','.')),k=parseFloat($('#f-k').value.replace(',','.')),mn=parseInt($('#f-m').value),id=$('#f-id').value,e=$('#f-err');
  if(!n)return e.textContent='Saisissez le nom du médicament.';if(!c)return e.textContent='Choisissez ou saisissez une catégorie.';if(!(p>0))return e.textContent='Le prix de vente doit être supérieur à 0.';if(!(k>=0))return e.textContent="Saisissez le prix d'achat.";if(k>p)return e.textContent="Le prix d'achat dépasse le prix de vente : vérifiez les montants.";
  if(id){const m=medById(+id);Object.assign(m,{n,cat:c,price:p,cost:k,min:mn||0,sup:+$('#f-s').value,rx:$('#f-rx').checked});toast('Médicament mis à jour');logAct('box','Fiche modifiée',n)}
  else{const q=parseInt($('#f-q').value)||0,lot=$('#f-lot').value.trim()||'LOT-'+(SEQ+1),ex=$('#f-e').value;if(!ex)return e.textContent="Indiquez la date d'expiration du lot.";
   const m={id:++SEQ,n,cat:c,price:p,cost:k,min:mn||0,sup:+$('#f-s').value,rx:$('#f-rx').checked,bc:'6221'+String(100000000+SEQ*7919311).slice(0,9),lots:q>0?[{lot,exp:parseD(ex),q}]:[]};MEDS.push(m);toast('Médicament ajouté à l\'inventaire');logAct('box','Nouveau médicament',n)}
  closeDlg();render()},
 order:t=>orderDlg(+t.dataset.id),
 prio:t=>{$$('#o-prio button').forEach(b=>b.setAttribute('aria-pressed',b===t));setEta()},
 'order-save':()=>{const mid=+$('#o-mid').value,m=medById(mid),q=parseInt($('#o-qty').value),eta=$('#o-eta').value;if(!(q>0))return $('#o-err').textContent='Saisissez une quantité supérieure à 0.';if(!eta)return $('#o-err').textContent='Choisissez une date de livraison.';
  const o={id:nextOrderId(),mid,sup:+$('#o-sup').value,qty:q,prio:$('#o-prio button[aria-pressed=true]').dataset.v,eta:parseD(eta),cost:q*m.cost,st:'open'};ORDERS.unshift(o);logAct('truck','Commande passée',`${q} × ${m.n} · ${supById(o.sup).n}`);closeDlg();render();toast(`Commande ${o.id} passée : ${q} × ${m.n}`)},
 'order-crit':()=>{const list=MEDS.filter(m=>['critique','rupture'].includes(status(m))&&!ORDERS.some(o=>o.mid===m.id&&o.st==='open')).sort(byUrg);
  if(!list.length)return toast('Aucune référence critique sans commande en cours');
  openDlg(dlg('Commander les critiques',`${list.length} référence${list.length>1?'s':''} en rupture ou en stock critique, sans commande en cours`,`<div class="tw"><table><thead><tr><th>Médicament</th><th>Fournisseur</th><th>Quantité</th><th class="right">Coût</th></tr></thead><tbody>${list.map(m=>`<tr><td class="med"><b>${esc(m.n)}</b><small>Stock ${stock(m)}</small></td><td>${esc(supById(m.sup).n)}</td><td class="num">${suggest(m)}</td><td class="right num">${eg(suggest(m)*m.cost)}</td></tr>`).join('')}</tbody></table></div><div class="estimate"><span>Total estimé (hors taxes)</span><b>${eg(sum(list,m=>suggest(m)*m.cost))}</b></div>`,`<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="order-crit-ok">${I('cart','sm')}Passer ${list.length} commande${list.length>1?'s':''}</button>`,true))},
 'order-crit-ok':()=>{const list=MEDS.filter(m=>['critique','rupture'].includes(status(m))&&!ORDERS.some(o=>o.mid===m.id&&o.st==='open'));list.forEach(m=>{const s=supById(m.sup),q=suggest(m);ORDERS.unshift({id:nextOrderId(),mid:m.id,sup:m.sup,qty:q,prio:'Urgent',eta:addDays(Math.max(1,Math.ceil(s.lead/2))),cost:q*m.cost,st:'open'})});logAct('truck','Commandes groupées',list.length+' références critiques commandées');closeDlg();render();toast(list.length+' commandes passées')},
 review:()=>{const al=alerts();openDlg(dlg('Revue des actions',`${al.length} élément${al.length>1?'s':''} à traiter`,`<div class="alerts">${al.map(a=>`<div class="alert ${a.sev}"><div class="ai">${I(a.kind==='stock'?'box':'clock')}</div><div><b>${esc(a.t)}</b><p>${esc(a.x)}</p><div class="ft">${a.kind==='stock'?`<button class="btn sm primary" data-a="order" data-id="${a.m.id}">Commander</button>`:lotSt(a.l).k==='expired'?`<button class="btn sm primary" data-a="writeoff" data-m="${a.m.id}" data-lot="${a.l.lot}">Retirer du stock</button>`:`<button class="btn sm primary" data-a="go" data-v="ex" data-xf="soon">Voir le suivi</button>`}</div></div></div>`).join('')||'<div class="empty">Rien à traiter.</div>'}</div>`,`<button class="btn" data-a="close">Fermer</button>`,true))},
 receive:t=>{const o=ORDERS.find(x=>x.id===t.dataset.id),m=medById(o.mid);openDlg(dlg('Réceptionner '+o.id,`${esc(m.n)} · ${esc(supById(o.sup).n)}`,`<div class="grid3"><div><label class="lb" for="r-lot">Numéro de lot</label><input id="r-lot" class="input" value="REC-${o.id.slice(4)}"></div><div><label class="lb" for="r-q">Quantité reçue</label><input id="r-q" class="input" inputmode="numeric" value="${o.qty}"></div><div><label class="lb" for="r-e">Expiration</label><input id="r-e" class="input" type="date" value="${isoD(addDays(540))}"></div></div>${err('r-err')}<input type="hidden" id="r-id" value="${o.id}">`,`<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="receive-ok">${I('check','sm')}Ajouter au stock</button>`))},
 'receive-ok':()=>{const o=ORDERS.find(x=>x.id===$('#r-id').value),m=medById(o.mid),q=parseInt($('#r-q').value),e=$('#r-e').value;if(!(q>0))return $('#r-err').textContent='Saisissez la quantité reçue.';if(!e)return $('#r-err').textContent="Indiquez la date d'expiration du lot.";if(parseD(e)<=TODAY)return $('#r-err').textContent="Ce lot est déjà expiré : refusez la livraison ou corrigez la date.";
  m.lots.push({lot:$('#r-lot').value.trim()||'REC',exp:parseD(e),q});o.st='done';logAct('box','Réception de commande',`${q} × ${m.n} ajoutés au stock`);closeDlg();render();toast(`${q} unités de ${m.n} ajoutées au stock`)},
 'ord-cancel':t=>{const i=ORDERS.findIndex(x=>x.id===t.dataset.id);ORDERS.splice(i,1);render();toast('Commande annulée')},
 ordtab:t=>{U.ordTab=t.dataset.v;render()},
 ist:t=>{U.ist=t.dataset.v;render()},'inv-reset':()=>{U.iq='';U.icat='all';U.ist='all';render()},
 xf:t=>{U.xf=t.dataset.v;render()},
 writeoff:t=>{const m=medById(+t.dataset.m),l=m.lots.find(x=>x.lot===t.dataset.lot);openDlg(dlg('Retirer le lot du stock',`${esc(m.n)} · lot ${esc(l.lot)}`,`<p>${l.q} unités expirées le ${fd(l.exp)} seront retirées du stock et comptées en perte.</p><div class="estimate" style="background:var(--crit-50);color:var(--crit)"><span>Valeur perdue (prix d'achat)</span><b>${eg(l.q*m.cost)}</b></div><input type="hidden" id="w-m" value="${m.id}"><input type="hidden" id="w-l" value="${esc(l.lot)}">`,`<button class="btn" data-a="close">Annuler</button><button class="btn danger" data-a="writeoff-ok">${I('trash','sm')}Retirer ${l.q} unités</button>`))},
 'writeoff-ok':()=>{const m=medById(+$('#w-m').value),i=m.lots.findIndex(x=>x.lot===$('#w-l').value),l=m.lots[i];WRITEOFF+=l.q*m.cost;m.lots.splice(i,1);logAct('trash','Lot retiré du stock',`${l.q} × ${m.n} (lot ${l.lot})`);closeDlg();render();toast(`Lot ${l.lot} retiré : ${eg(l.q*m.cost)} passés en perte`)},
 'cli-new':cliDlg,
 'cli-save':()=>{const n=$('#c-n').value.trim(),p=$('#c-p').value.trim(),e=$('#c-e').value.trim(),er=$('#c-err');if(!n)return er.textContent='Saisissez le nom du client.';if(p.replace(/\D/g,'').length<10)return er.textContent='Saisissez un numéro de téléphone valide (10 chiffres minimum).';if(CLI.some(c=>c.ph.replace(/\s/g,'')===p.replace(/\s/g,'')))return er.textContent='Ce numéro est déjà enregistré.';
  const c={id:CLI.length+1,n,ph:p,e:e||'—',tot:0,cnt:0,last:'Jamais'};CLI.push(c);U.csel=c.id;logAct('users','Nouveau client enregistré',n+' a été ajouté');closeDlg();go('cl');toast('Client ajouté : '+n)},
 'cli-sel':t=>{U.csel=+t.dataset.id;render()},
 'cli-sale':t=>{const c=CLI.find(x=>x.id===+t.dataset.id);U.cn=c.n;U.cp=c.ph;go('pos')},
 'sup-new':supDlg,
 'sup-save':()=>{const n=$('#u-n').value.trim(),c=$('#u-c').value.trim(),p=$('#u-p').value.trim(),l=parseInt($('#u-l').value);if(!n)return $('#u-err').textContent="Saisissez le nom de l'entreprise.";if(!c)return $('#u-err').textContent='Saisissez un contact.';if(!(l>0))return $('#u-err').textContent='Le délai doit être d\'au moins 1 jour.';SUP.push({id:SUP.length+1,n,c,ph:p||'—',lead:l});closeDlg();render();toast('Fournisseur ajouté : '+n)},
 'sup-view':t=>{const s=supById(+t.dataset.id),ms=MEDS.filter(m=>m.sup===s.id),os=ORDERS.filter(o=>o.sup===s.id&&o.st==='open');
  openDlg(dlg(esc(s.n),`${esc(s.c)} · ${esc(s.ph)} · livraison en ${s.lead} jours`,`<div><h4 style="font-size:14px;margin-bottom:8px">Produits fournis (${ms.length})</h4>${ms.length?`<div class="tw"><table><tbody>${ms.map(m=>`<tr><td class="med"><b>${esc(m.n)}</b><small>Stock ${stock(m)}</small></td><td>${stPill(m)}</td><td class="right"><button class="btn sm" data-a="order" data-id="${m.id}">Commander</button></td></tr>`).join('')}</tbody></table></div>`:'<div class="empty">Aucun produit rattaché à ce fournisseur.</div>'}</div><div><h4 style="font-size:14px;margin-bottom:8px">Commandes en cours (${os.length})</h4>${os.map(o=>`<div class="row between" style="padding:6px 0"><span><b>${o.id}</b> · ${o.qty} × ${esc(medById(o.mid).n)}</span><span class="mute">Livraison ${fd(o.eta)}</span></div>`).join('')||'<span class="mute">Aucune commande en cours.</span>'}</div>`,`<button class="btn primary" data-a="close">Fermer</button>`,true))},
 'staff-new':()=>staffDlg(),'staff-edit':t=>staffDlg(+t.dataset.id),
 'staff-save':()=>{const id=$('#t-id').value,r=$('#t-r').value;if(id){const s=STAFF.find(x=>x.id===+id);s.role=r;const on=$('#t-on');if(on)s.on=on.checked;toast('Accès mis à jour : '+s.n)}else{const n=$('#t-n').value.trim(),e=$('#t-e').value.trim();if(!n)return $('#t-err').textContent='Saisissez le nom du membre.';if(!/^\S+@\S+\.\S+$/.test(e))return $('#t-err').textContent='Saisissez une adresse e-mail valide.';if(STAFF.some(x=>x.e===e))return $('#t-err').textContent='Cette adresse e-mail existe déjà.';STAFF.push({id:STAFF.length+1,n,e,role:r,on:true});toast('Membre ajouté : '+n)}
  if(!curUser().on)U.user=1;closeDlg();render()},
 pwd:()=>openDlg(dlg('Changer le mot de passe','Au moins 8 caractères, avec un chiffre',`<div><label class="lb" for="p0">Mot de passe actuel</label><input id="p0" class="input" type="password" autocomplete="current-password"></div><div class="grid2"><div><label class="lb" for="p1">Nouveau mot de passe</label><input id="p1" class="input" type="password" autocomplete="new-password"></div><div><label class="lb" for="p2">Confirmation</label><input id="p2" class="input" type="password" autocomplete="new-password"></div></div>${err('p-err')}<small class="mute">Aperçu : aucun mot de passe n'est enregistré.</small>`,`<button class="btn" data-a="close">Annuler</button><button class="btn primary" data-a="pwd-ok">Mettre à jour</button>`)),
 'pwd-ok':()=>{const a=$('#p0').value,b=$('#p1').value,c=$('#p2').value,e=$('#p-err');if(!a)return e.textContent='Saisissez votre mot de passe actuel.';if(b.length<8||!/\d/.test(b))return e.textContent='Le nouveau mot de passe doit contenir 8 caractères et un chiffre.';if(b!==c)return e.textContent='Les deux mots de passe ne correspondent pas.';closeDlg();toast('Mot de passe validé (simulation)')},
 aper:t=>{U.aper=t.dataset.v;render()},salpay:t=>{U.salpay=t.dataset.v;render()},
 receipt:t=>{U.menu=null;receiptDlg(t.dataset.id);renderTop()},
 pcat:t=>{U.pcat=t.dataset.v;render()},
 padd:t=>cartAdd(+t.dataset.id,1),qplus:t=>cartAdd(+t.dataset.id,1),qminus:t=>{const id=+t.dataset.id,n=(CART.get(id)||0)-1;if(n<=0)CART.delete(id);else CART.set(id,n);render()},qdel:t=>{CART.delete(+t.dataset.id);render()},
 'cart-clear':()=>{CART.clear();U.rxok=false;render()},pay:t=>{U.pay=t.dataset.v;render()},
 exact:()=>{const tot=cartTotal();U.paid=nf2.format(tot).replace(/ /g,'');render()},
 checkout:()=>{const lines=[...CART].map(([id,n])=>({m:medById(id),n})),net=sum(lines,l=>l.m.price*l.n),tax=net*SET.tax/100,tot=net+tax,paid=U.pay==='Carte'?tot:parseFloat(String(U.paid).replace(',','.'))||0;
  lines.forEach(({m,n})=>{let left=n;m.lots.filter(l=>daysTo(l.exp)>=0).sort((a,b)=>a.exp-b.exp).forEach(l=>{const t=Math.min(l.q,left);l.q-=t;left-=t});m.lots=m.lots.filter(l=>l.q>0||daysTo(l.exp)<0)});
  const s={id:'INV-'+(INV++),ts:new Date(2026,9,28,new Date().getHours(),new Date().getMinutes()),cust:U.cn.trim(),pay:U.pay,items:lines.map(({m,n})=>({id:m.id,n:m.n,q:n,p:m.price,c:m.cost})),net,cost:sum(lines,l=>l.m.cost*l.n),tax,total:tot,paid};
  SALES.unshift(s);NEWNET+=net;NEWCOUNT++;const c=CLI.find(x=>x.n===s.cust);if(c){c.tot+=tot;c.cnt++;c.last='28 oct. 2026'}
  logAct('cart','Vente conclue',`Facture ${s.id} · ${eg(tot,1)}`);CART.clear();U.paid='';U.rxok=false;U.cn='';U.cp='';render();receiptDlg(s.id,true);
  const low=lines.filter(({m})=>['critique','rupture'].includes(status(m)));if(low.length)toast(`Stock critique : ${low.map(l=>l.m.n).join(', ')}`)}
};
const cartTotal=()=>{const sub=sum([...CART],([id,n])=>medById(id).price*n);return sub*(1+SET.tax/100)};
function cartAdd(id,d){const m=medById(id),n=(CART.get(id)||0)+d,s=stock(m);if(n>s)return toast(`Stock insuffisant : ${s} unité${s>1?'s':''} disponible${s>1?'s':''} pour ${m.n}`);CART.set(id,n);render()}

/* ================= événements ================= */
document.addEventListener('click',e=>{
  const mod=$('#modal');if(e.target===mod){closeDlg();return}
  const t=e.target.closest('[data-a]');
  if(t&&A[t.dataset.a]){e.preventDefault();A[t.dataset.a](t);return}
  if(U.menu&&!e.target.closest('.menuwrap')&&!e.target.closest('.gsearch')&&!e.target.closest('.me')){U.menu=null;renderTop()}
  if(e.target.id==='scrim')$('#app').classList.remove('nav-open')});
document.addEventListener('input',e=>{const t=e.target;
  if(t.dataset.in){U[t.dataset.in]=t.value;if(t.dataset.in==='gq'){U.menu=t.value.trim().length>1?'search':null;renderTop();const g=$('#gq');g.focus();g.setSelectionRange(t.value.length,t.value.length)}else render()}
  else if(t.dataset.set){const v=parseFloat(t.value.replace(',','.'));if(v>=0&&v<=100000)SET[t.dataset.set]=v;render()}
  else if(t.hasAttribute('data-oc'))orderCalc()});
document.addEventListener('change',e=>{const t=e.target;
  if(t.dataset.chk){U[t.dataset.chk]=t.checked;render()}
  else if(t.dataset.sw){SET[t.dataset.sw]=t.checked;if(t.dataset.sw==='report'&&t.checked){logAct('file','Résumé quotidien activé','Résumé des ventes ajouté chaque soir')}render();toast(t.checked?'Option activée':'Option désactivée')}
  else if(t.dataset.sel){U[t.dataset.sel]=t.value;render()}
  else if(t.dataset.perm){const [r,k]=t.dataset.perm.split('|');t.checked?PERM[r].add(k):PERM[r].delete(k);if(!can(U.view)){go(NAV.find(n=>can(n[0]))[0])}else renderSide();toast(`${t.checked?'Accès autorisé':'Accès retiré'} : ${MODS.find(m=>m[0]===k)[1]} pour ${r}`)}
  else if(t.id==='o-sup')setEta()});
document.addEventListener('keydown',e=>{
  if(e.key==='Escape'){if($('#modal').classList.contains('open'))closeDlg();else if(U.menu){U.menu=null;renderTop()}}
  if(e.key==='Enter'&&e.target.id==='pq'){const q=norm(U.pq),l=MEDS.filter(m=>(U.pcat==='Tous'||m.cat===U.pcat)&&(m.bc===U.pq.trim()||norm(m.n).includes(q)));if(l.length===1&&stock(l[0])>0){U.pq='';cartAdd(l[0].id,1)}}});
setInterval(()=>{const c=$('#clock');if(c)c.textContent=ftime(new Date())},20000);

/* ================= démarrage ================= */
$('#app').insertAdjacentHTML('beforeend','<div id="scrim"></div>');
render();
window.__pharma={A,U,MEDS,go,render};
})();

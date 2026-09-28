<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>MatchIQ · Operations</title>
<style>
:root{color-scheme:dark;font:15px system-ui;background:#080e1a;color:#e8eef9}*{box-sizing:border-box}body{margin:0}header{padding:22px 5%;border-bottom:1px solid #223047;display:flex;justify-content:space-between;align-items:center}h1{font-size:22px;letter-spacing:3px;margin:0}header span{color:#8ea3c1;font-size:12px;letter-spacing:1px}main{max-width:1250px;margin:36px auto;padding:0 24px}h2{font-size:30px}p{color:#91a4c2;line-height:1.6}.card{background:#121d30;border:1px solid #223047;border-radius:18px;padding:22px;margin-bottom:16px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px}.metric{font-size:32px;font-weight:700;margin-top:12px}button,input,select{font:inherit;padding:12px;border:1px solid #32425c;border-radius:10px;background:#152239;color:inherit}button{cursor:pointer}button.primary{background:#306aff}button:hover{filter:brightness(1.2)}input{display:block;width:100%;margin:12px 0}nav{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:14px;border-bottom:1px solid #223047}th{color:#92a9cb}#login{max-width:420px;margin:80px auto}.error{color:#ffb59d}label{display:block}small{color:#91a4c2}.bar{height:12px;background:#367bff;border-radius:4px;min-width:2px}.scroll{overflow:auto}.actions{display:flex;gap:12px;align-items:center;flex-wrap:wrap}[hidden]{display:none!important}
</style></head><body><header><div><h1>MATCHIQ</h1><span>INTELLIGENCE OPERATIONS</span></div><button id="logout" hidden>Sign out</button></header><main>
<form id="login" class="card"><h2>Operations access</h2><p>Sign in with an administrator account.</p><div id="register-fields" hidden><label>Name<input id="name" autocomplete="name" maxlength="100"></label></div><label>Email<input type="email" id="email" autocomplete="username" required></label><label>Password<input type="password" id="password" autocomplete="current-password" required></label><div id="confirm-fields" hidden><label>Confirm password<input type="password" id="confirmation" autocomplete="new-password"></label><p>Use at least 12 characters, uppercase and lowercase letters, and a number. Creating a sign-in does not grant admin access; the project owner must enable it.</p></div><button id="submit-login" class="primary">Sign in</button><button type="button" id="register-toggle">Create a password sign-in</button></form>
<p id="error" class="error" role="alert"></p><section id="app" hidden><nav><button data-tab="dashboard">Overview</button><button data-tab="users">Users</button><button data-tab="fixtures">Football</button><button data-tab="settings">Configuration</button></nav><div id="content"></div></section>
</main><script>
let token=null;const el=id=>document.getElementById(id);const content=el('content');
function node(tag,text,cls){const n=document.createElement(tag);if(text!==undefined)n.textContent=String(text);if(cls)n.className=cls;return n}
async function api(path,method='GET',body){const r=await fetch('/api/'+path,{method,headers:{Accept:'application/json','Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(body?{body:JSON.stringify(body)}:{})});const d=r.status===204?{}:await r.json();if(!r.ok)throw Error(d.message||'Request failed');return d}
function report(e){el('error').textContent=e.message}function title(s){return s.replaceAll('_',' ').replace(/\b\w/g,c=>c.toUpperCase())}
let registering=false;
el('register-toggle').onclick=()=>{registering=!registering;el('register-fields').hidden=!registering;el('confirm-fields').hidden=!registering;el('name').required=registering;el('confirmation').required=registering;el('password').autocomplete=registering?'new-password':'current-password';el('submit-login').textContent=registering?'Create sign-in':'Sign in';el('register-toggle').textContent=registering?'Back to sign in':'Create a password sign-in'};
el('login').onsubmit=async e=>{e.preventDefault();el('error').textContent='';try{
const body={email:el('email').value,password:el('password').value};if(registering){body.name=el('name').value;body.password_confirmation=el('confirmation').value}
const d=await api(registering?'auth/register':'auth/login','POST',body);token=d.token;el('password').value='';el('confirmation').value='';
if(registering){await api('auth/logout','POST');token=null;el('register-toggle').click();el('error').textContent='Sign-in created. Ask the project owner to enable administrator access, then sign in.';return}
await api('admin/dashboard');el('login').hidden=true;el('app').hidden=false;el('logout').hidden=false;await load('dashboard')
}catch(e){token=null;report(e)}};
el('logout').onclick=async()=>{try{await api('auth/logout','POST')}finally{token=null;location.reload()}};
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>load(b.dataset.tab).catch(report));
async function load(tab){el('error').textContent='';content.replaceChildren(node('p','Loading…'));
if(tab==='dashboard'){const d=await api('admin/dashboard');content.replaceChildren(node('h2','A clear view of your platform'));const grid=node('div',undefined,'grid');for(const [k,v]of Object.entries(d)){if(Array.isArray(v))continue;const card=node('div',undefined,'card');card.append(node('small',title(k)),node('div',v===null?'No data':typeof v==='number'?Number(v.toFixed(2)):v,'metric'));grid.append(card)}content.append(grid);
for(const key of ['analysis_volume','model_performance']){content.append(node('h3',title(key)));if(!d[key].length){content.append(node('p','No recorded data yet.'));continue}if(key==='analysis_volume'){const max=Math.max(...d[key].map(x=>x.count));for(const x of d[key]){const r=node('div',undefined,'card');r.append(node('small',x.date+' · '+x.count));const bar=node('div',undefined,'bar');bar.style.width=(x.count/max*100)+'%';r.append(bar);content.append(r)}}else table(d[key],['market','count','brier_score','log_loss'])}}
if(tab==='users'){
content.replaceChildren(node('h2','Account management'),node('p','Search by name or email. Check the account ID when the same email appears on multiple phones. Trials expire automatically.'));
const search=node('input');search.placeholder='Search name or email';content.append(search);const area=node('div');content.append(area);let timer;let page=1;
async function users(){
const d=await api('admin/users?search='+encodeURIComponent(search.value)+'&page='+page);area.replaceChildren();
for(const u of d.data){
const row=node('div',undefined,'card actions');row.append(node('span','#'+u.id+' · '+u.name+' · '+u.email));
row.append(node('small',u.trial_expires_at?'Trial expires: '+new Date(u.trial_expires_at).toLocaleString():'No active trial'));
const days=node('select');days.setAttribute('aria-label','Trial duration for account '+u.id);
for(const n of [7,14,30,90]){const o=node('option',n+' days');o.value=n;days.append(o)}
const grant=node('button','Give Pro trial','primary');grant.disabled=!!u.disabled_at;
grant.onclick=async()=>{grant.disabled=true;try{await api('admin/users/'+u.id+'/trial','PUT',{days:Number(days.value)});await users()}catch(e){report(e);grant.disabled=false}};
const revoke=node('button','Revoke trial');revoke.disabled=!u.trial_expires_at;
revoke.onclick=async()=>{revoke.disabled=true;try{await api('admin/users/'+u.id+'/trial','DELETE');await users()}catch(e){report(e);revoke.disabled=false}};
const b=node('button',u.disabled_at?'Restore account':'Disable account');b.onclick=async()=>{try{await api('admin/users/'+u.id,'PATCH',{disabled:!u.disabled_at});await users()}catch(e){report(e)}};
row.append(days,grant,revoke,b);area.append(row)}
const prev=node('button','Previous'),next=node('button','Next');prev.disabled=page<=1;next.disabled=page>=d.last_page;
prev.onclick=()=>{page--;users().catch(report)};next.onclick=()=>{page++;users().catch(report)};
area.append(prev,node('span',' Page '+page+' / '+d.last_page+' '),next);
}
search.oninput=()=>{clearTimeout(timer);page=1;timer=setTimeout(()=>users().catch(report),350)};await users()}
if(tab==='fixtures'){const d=await api('fixtures');content.replaceChildren(node('h2','Football synchronization'),node('p','Last sync: '+(d.synced_at||'Not synchronized')));table(d.data.map(f=>({league:f.league.name,home:f.home_team.name,away:f.away_team.name,kickoff:f.kickoff,status:f.status})),['league','home','away','kickoff','status'])}
if(tab==='settings'){const d=await api('admin/settings');content.replaceChildren(node('h2','Analysis limits'));const values=Object.fromEntries(d.map(s=>[s.key,JSON.parse(s.value)]));for(const key of ['free_limit','pro_limit']){const form=node('form',undefined,'card');form.append(node('label',title(key)));const input=node('input');input.type='number';input.min=key==='free_limit'?0:1;input.max=key==='free_limit'?100:1000;input.required=true;input.value=values[key]??(key==='free_limit'?3:100);form.append(input,node('button','Save','primary'));form.onsubmit=async e=>{e.preventDefault();try{await api('admin/settings/'+key,'PUT',{value:Number(input.value)});el('error').textContent='Saved.'}catch(e){report(e)}};content.append(form)}}}
function table(rows,keys){if(!rows.length){content.append(node('p','No data available.'));return}const wrap=node('div',undefined,'card scroll');const t=node('table'),h=node('tr');keys.forEach(k=>h.append(node('th',title(k))));t.append(h);rows.forEach(r=>{const tr=node('tr');keys.forEach(k=>tr.append(node('td',r[k]??'—')));t.append(tr)});wrap.append(t);content.append(wrap)}
</script></body></html>

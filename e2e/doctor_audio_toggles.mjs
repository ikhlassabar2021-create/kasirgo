import fs from 'fs';
import { chromium } from 'playwright';
const BASE='https://ikhlassabar2021-create.github.io/kasirgo/';
const SUPA='https://lmvjecdvfzsmrowwwpck.supabase.co';
const KEY='sb_publishable_8RJnG66i_37cih8GTG1sBA_0B91KOW_';
const OUTLET='229c94d7-ce6d-4be1-98f5-448f600528cc';
const TOKEN=fs.readFileSync('/tmp/opencode/owner_token.txt','utf8').trim();
const H={apikey:KEY,Authorization:`Bearer ${TOKEN}`,'Content-Type':'application/json'};
const profile=async()=>{const r=await fetch(`${SUPA}/rest/v1/doctor_outlet_profile?outlet_id=eq.${OUTLET}&select=preferred_tone,audio_prefs`,{headers:H});return r.json();};
const before=await profile();
console.log('BEFORE',JSON.stringify(before));
const b=await chromium.launch({args:['--no-sandbox']});
const c=await b.newContext({viewport:{width:1280,height:1200},serviceWorkers:'block'});
const p=await c.newPage();
const errs=[];p.on('console',m=>{if(m.type()==='error')errs.push(m.text().slice(0,150));});
const clickText=async(t)=>{const els=p.locator('flt-semantics',{hasText:t});const n=await els.count();for(let i=n-1;i>=0;i--){const el=els.nth(i);const bx=await el.boundingBox();if(!bx||bx.width===0)continue;await p.mouse.click(bx.x+bx.width/2,bx.y+bx.height/2);return true;}return false;};
await p.goto(BASE+'?cb='+Date.now(),{waitUntil:'networkidle',timeout:120000});
await p.waitForTimeout(6000);
await p.locator('flt-semantics-placeholder').evaluate(el=>el.click());
await p.waitForTimeout(2500);
await clickText('Saya Penjual');
await p.waitForTimeout(4000);
const eb=await p.locator('input[aria-label="Email Bisnis / Owner"]').boundingBox();
await p.mouse.click(eb.x+eb.width/2,eb.y+eb.height/2);
await p.waitForTimeout(500);
await p.keyboard.type('ikhlassabar2021@gmail.com',{delay:25});
await p.keyboard.press('Tab');
await p.waitForTimeout(600);
await p.keyboard.type('sabar2021',{delay:40});
await p.waitForTimeout(800);
await clickText('MASUK KE KASIRGO');
await p.waitForTimeout(12000);
await clickText('Dokter Bisnis AI');
await p.waitForTimeout(6000);
const card=await p.evaluate(()=>{const el=[...document.querySelectorAll('flt-semantics')].find(e=>(e.getAttribute('aria-label')||'').startsWith('Suara Interaktif'));if(!el)return null;const r=el.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height};});
console.log('CARD',JSON.stringify(card));
if(card){
  for(const [name,f] of [['soundbox',0.58],['teguran',0.83]]){
    await p.mouse.click(card.x+card.w*0.92, card.y+card.h*f);
    await p.waitForTimeout(2500);
    console.log('AFTER_'+name.toUpperCase(),JSON.stringify((await profile())[0]?.audio_prefs));
  }
}
await fetch(`${SUPA}/rest/v1/doctor_outlet_profile?outlet_id=eq.${OUTLET}`,{method:'PATCH',headers:{...H,Prefer:'return=minimal'},body:JSON.stringify({preferred_tone:before[0].preferred_tone,audio_prefs:before[0].audio_prefs})});
console.log('RESTORED',JSON.stringify(await profile()));
console.log('ERRORS',errs.length,JSON.stringify(errs.slice(0,3)));
await b.close();

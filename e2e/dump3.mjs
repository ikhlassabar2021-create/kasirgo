import { chromium } from 'playwright';
const base='https://ikhlassabar2021-create.github.io/kasirgo/';
const b=await chromium.launch({args:['--no-sandbox']});
const c=await b.newContext({viewport:{width:1280,height:1000},serviceWorkers:'block'});
const p=await c.newPage();
const clickText=async(t)=>{const els=p.locator('flt-semantics',{hasText:t});const n=await els.count();for(let i=n-1;i>=0;i--){const el=els.nth(i);const bx=await el.boundingBox();if(!bx||bx.width===0)continue;await p.mouse.click(bx.x+bx.width/2,bx.y+bx.height/2);return true;}return false;};
const clickLabel=async(t)=>{const r=await p.evaluate((t)=>{const els=[...document.querySelectorAll('flt-semantics')];const hit=els.find(e=>(e.getAttribute('aria-label')||'').includes(t)&&e.getBoundingClientRect().width>0);if(!hit)return null;const bb=hit.getBoundingClientRect();return{x:bb.x+bb.width/2,y:bb.y+bb.height/2};},t);if(!r)return false;await p.mouse.click(r.x,r.y);return true;};
await p.goto(base+'?cb='+Date.now(),{waitUntil:'networkidle',timeout:120000});
await p.waitForTimeout(5000);
await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
await p.waitForTimeout(2000);
await clickText('Saya Penjual'); await p.waitForTimeout(3500);
await p.mouse.click(640,455); await p.waitForTimeout(700);
await p.keyboard.type('ikhlassabar2021@gmail.com',{delay:20});
await p.keyboard.press('Tab'); await p.waitForTimeout(400);
await p.keyboard.type('sabar2021',{delay:20});
await p.waitForTimeout(500);
await clickText('MASUK KE KASIRGO'); await p.waitForTimeout(11000);
await clickText('Pesanan Masuk'); await p.waitForTimeout(2500);
await clickText('Pesanan Online'); await p.waitForTimeout(3000);
await clickLabel('Aktif'); await p.waitForTimeout(3000);
const html = await p.evaluate(()=>{
  const els=[...document.querySelectorAll('flt-semantics')];
  const hit=els.find(e=>(e.textContent||'').includes('Selesai') && e.getBoundingClientRect().y>100 && e.getBoundingClientRect().y<400);
  if(!hit) return 'none';
  return hit.outerHTML.slice(0,4000);
});
console.log(html);
const hits = await p.evaluate(()=>{
  const out=[];
  document.querySelectorAll('flt-semantics').forEach(e=>{
    const t=(e.textContent||'');
    if(t.includes('Selesai')){
      const r=e.getBoundingClientRect();
      out.push({role:e.getAttribute('role'),label:e.getAttribute('aria-label'),txt:t.slice(0,80),y:Math.round(r.y),h:Math.round(r.height),w:Math.round(r.width),kids:e.children.length});
    }
  });
  return out;
});
console.log(JSON.stringify(hits,null,1));
await b.close();

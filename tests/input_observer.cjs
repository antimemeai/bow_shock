// Instrumentation lifecycle/data check with Node's actual EventTarget. This is
// not Chromium dispatch/default-action testing or a fake website acceptance run.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {performance} = require('node:perf_hooks');
const window = new EventTarget();
window.scrollX = 3; window.scrollY = 4;
const document = {activeElement:window,getSelection:()=>null};
const context = vm.createContext({window,document,EventTarget,performance,setTimeout,clearTimeout,
  location:{href:'native-eventtarget-check:'},navigator:{userAgent:'Node EventTarget check',language:'en'},
  devicePixelRatio:2,screen:{width:1400,height:900},innerWidth:600,innerHeight:800});
const install = vm.runInContext(fs.readFileSync(require('node:path').join(__dirname,'../native/cef/input_observer.js'),'utf8'),context);
(async () => {
  const records = [];
  const dispose = install(record => records.push(record));
  const event = new Event('keydown',{cancelable:true});
  Object.defineProperties(event,{key:{value:'😀'},code:{value:'KeyA'},repeat:{value:false},data:{value:null}});
  window.addEventListener('keydown',e=>{e.preventDefault();window.scrollY=97;},{once:true});
  window.dispatchEvent(event);
  const capture = records.find(x=>x.kind==='capture');
  assert.equal(capture.key,'😀'); assert.equal(capture.data,null);
  assert.equal(capture.default_prevented,false); assert.equal(capture.state.window_scroll_y,4);
  assert.equal(records.some(x=>x.kind==='settled'),false);
  await new Promise(resolve=>setTimeout(resolve,15));
  const settled = records.find(x=>x.kind==='settled');
  assert.equal(settled.event_id,capture.event_id);
  assert.equal(settled.default_prevented,true); assert.equal(settled.state.window_scroll_y,97);
  assert.equal(settled.sample_trigger,'next_task');
  const wheel = new Event('wheel');
  Object.defineProperties(wheel,{deltaY:{value:23},deltaMode:{value:0}});
  window.dispatchEvent(wheel);
  // Cleanup drains pending observations immediately, then removes listeners.
  dispose();
  assert.equal(records.filter(x=>x.kind==='capture').length,2);
  assert.equal(records.filter(x=>x.kind==='settled').length,2);
  assert.equal(records.filter(x=>x.kind==='settled').at(-1).sample_trigger,'observer_dispose');
  assert.equal(records.at(-1).kind,'observer_stopped');
  const count = records.length;
  window.dispatchEvent(new Event('keydown'));
  await new Promise(resolve=>setTimeout(resolve,15));
  assert.equal(records.length,count);
  assert.equal(Object.keys(window).includes('record'),false);
  assert.equal(records.some(x=>x.kind==='observer_error'),false);
  const next = [];
  const finishNext = install(record=>next.push(record));
  window.dispatchEvent(new Event('keypress')); finishNext();
  assert.equal(next.find(x=>x.kind==='capture').event_id,1);
  assert.equal(records.length,count);
  console.log('Private observer data, deferred cancellation, cleanup and restart passed');
})().catch(error=>{console.error(error);process.exitCode=1;});

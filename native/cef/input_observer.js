// Fixed, read-only renderer instrumentation. The private sink is a native V8
// callback passed as an argument; no window binding, JSON, or model script.
(function (sink) {
  "use strict";
  const now = performance.now.bind(performance);
  const origin = performance.timeOrigin;
  const later = setTimeout.bind(window), cancel = clearTimeout.bind(window);
  const add = EventTarget.prototype.addEventListener;
  const remove = EventTarget.prototype.removeEventListener;
  const ids = new WeakMap();
  let nextNode = 0, nextEvent = 0, timer = null, pending = [], active = true;
  const types = ("keydown keypress keyup beforeinput input textInput compositionstart compositionupdate compositionend " +
    "focus blur focusin focusout change selectionchange select selectstart " +
    "pointerover pointerenter pointermove pointerrawupdate pointerdown pointerup pointercancel pointerout pointerleave gotpointercapture lostpointercapture " +
    "mouseover mouseenter mousemove mousedown mouseup mouseout mouseleave click dblclick auxclick contextmenu " +
    "wheel scroll scrollend submit reset invalid formdata beforetoggle toggle DOMActivate dragstart drag dragenter dragover dragleave drop dragend").split(" ");
  function nodeId(node) {
    if (!node || (typeof node !== "object" && typeof node !== "function")) return "";
    if (!ids.has(node)) ids.set(node, String(++nextNode));
    return ids.get(node);
  }
  function target(node) {
    const result = {id:nodeId(node), name:String(node?.nodeName || ""),
      element_id:typeof node?.id === "string" ? node.id : ""};
    if (node?.getBoundingClientRect) {
      const r = node.getBoundingClientRect();
      result.rect = {x:r.x,y:r.y,width:r.width,height:r.height};
    }
    if (typeof node?.type === "string") result.field_type = node.type;
    return result;
  }
  function state(node) {
    const r = {target:target(node),active:target(document.activeElement),
      window_scroll_x:window.scrollX,window_scroll_y:window.scrollY};
    // Full field text is deliberate recording content, including intermediate typos.
    if (typeof node?.value === "string") r.value = node.value;
    for (const key of ["selectionStart","selectionEnd","selectionDirection","scrollTop","scrollLeft","scrollWidth","scrollHeight","clientWidth","clientHeight"]) {
      const value = node?.[key];
      if (typeof value === "string" || typeof value === "number") r[key] = value;
    }
    const s = document.getSelection();
    if (s) r.selection = {anchor:nodeId(s.anchorNode),anchor_offset:s.anchorOffset,
      focus:nodeId(s.focusNode),focus_offset:s.focusOffset,is_collapsed:s.isCollapsed};
    return r;
  }
  function point(e) {
    const r = {};
    for (const k of ["timeStamp","pointerId","pointerType","isPrimary","clientX","clientY","screenX","screenY","pageX","pageY","movementX","movementY","button","buttons","width","height","pressure","tangentialPressure","tiltX","tiltY","twist","altitudeAngle","azimuthAngle"]) {
      const v = e[k];
      if (["number","boolean","string"].includes(typeof v) && (typeof v !== "number" || Number.isFinite(v))) r[k] = v;
    }
    return r;
  }
  function flush(trigger = "next_task") {
    timer = null;
    const batch = pending; pending = [];
    for (const {e,id,node} of batch) {
      try {
        const sample = {kind:"settled",event_id:id,performance_now:now(),time_origin:origin,
          sample_trigger:trigger,default_prevented:e.defaultPrevented,state:state(node)};
        sample.observer_snapshot_ms = now() - sample.performance_now;
        sink(sample);
      }
      catch (error) { sink({kind:"observer_error",event_id:id,message:String(error)}); }
    }
  }
  function observe(e) {
    if (!active) return;
    const id = ++nextEvent;
    try {
      const path = e.composedPath(), node = path[0] || e.target;
      const r = {kind:"capture",event_id:id,type:e.type,event_timestamp:e.timeStamp,
        performance_now:now(),time_origin:origin,is_trusted:e.isTrusted,
        bubbles:e.bubbles,cancelable:e.cancelable,composed:e.composed,
        default_prevented:e.defaultPrevented,event_phase:e.eventPhase,
        target:target(e.target),path:path.map(target),state:state(node)};
      for (const k of ["key","code","keyCode","charCode","which","location","repeat","isComposing","altKey","ctrlKey","metaKey","shiftKey","data","inputType","deltaX","deltaY","deltaZ","deltaMode","detail"]) {
        const v = e[k];
        if (v === null || (["number","boolean","string"].includes(typeof v) && (typeof v !== "number" || Number.isFinite(v)))) r[k] = v;
      }
      Object.assign(r,point(e));
      if (typeof e.getCoalescedEvents === "function") r.coalesced = e.getCoalescedEvents().map(point);
      if (typeof e.getTargetRanges === "function") r.target_ranges = e.getTargetRanges().map(x => ({
        start:nodeId(x.startContainer),start_offset:x.startOffset,end:nodeId(x.endContainer),end_offset:x.endOffset}));
      r.observer_snapshot_ms = now() - r.performance_now;
      sink(r);
      pending.push({e,id,node});
      if (timer === null) timer = later(flush,0);
    } catch (error) { sink({kind:"observer_error",event_id:id,message:String(error)}); }
  }
  function dispose() {
    active = false;
    for (const type of types) remove.call(window,type,observe,true);
    if (timer !== null) cancel(timer);
    flush("observer_dispose");
    sink({kind:"observer_stopped",performance_now:now(),time_origin:origin});
  }
  try {
    for (const type of types) add.call(window,type,observe,{capture:true,passive:true});
    sink({kind:"observer_started",performance_now:now(),time_origin:origin,
      url:location.href,user_agent:navigator.userAgent,language:navigator.language,
      device_pixel_ratio:devicePixelRatio,screen_width:screen.width,screen_height:screen.height,
      viewport_width:innerWidth,viewport_height:innerHeight,types});
    return dispose;
  } catch (error) {
    dispose(); throw error;
  }
})

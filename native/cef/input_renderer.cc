#include "input_renderer.h"
#include "input_observer_script.h"
#include "include/cef_browser.h"
#include "include/cef_frame.h"
#include "include/cef_process_message.h"
#include "include/cef_render_process_handler.h"
#include "include/cef_v8.h"
#include "include/wrapper/cef_helpers.h"
#include <cmath>
#include <string>
#include <vector>
#include <uuid/uuid.h>

namespace {
// Only receives the fixed observer's acyclic native-data records. Depth rejection
// is an explicit instrumentation failure, never truncated event content.
CefRefPtr<CefValue> Native(CefRefPtr<CefV8Value> value, unsigned depth = 0) {
  if (!value || depth > 16) return nullptr;
  auto out = CefValue::Create();
  if (value->IsNull() || value->IsUndefined()) out->SetNull();
  else if (value->IsBool()) out->SetBool(value->GetBoolValue());
  else if (value->IsInt()) out->SetInt(value->GetIntValue());
  else if (value->IsDouble() || value->IsUInt()) {
    double n = value->GetDoubleValue();
    if (!std::isfinite(n)) return nullptr;
    out->SetDouble(n);
  } else if (value->IsString()) out->SetString(value->GetStringValue());
  else if (value->IsArray()) {
    auto list = CefListValue::Create();
    for (int i = 0; i < value->GetArrayLength(); ++i) {
      auto item = Native(value->GetValue(i),depth + 1); if (!item) return nullptr;
      list->SetValue(i,item);
    }
    out->SetList(list);
  } else if (value->IsObject() && !value->IsFunction()) {
    std::vector<CefString> keys;
    if (!value->GetKeys(keys)) return nullptr;
    auto dict = CefDictionaryValue::Create();
    for (const auto& key : keys) {
      auto item = Native(value->GetValue(key),depth + 1); if (!item) return nullptr;
      dict->SetValue(key,item);
    }
    out->SetDictionary(dict);
  } else return nullptr;
  return out;
}
void Send(CefRefPtr<CefFrame> frame, const std::string& kind, const std::string& context,
          const std::string& recording, CefRefPtr<CefDictionaryValue> fields = nullptr) {
  if (!frame || !frame->IsValid()) return;
  auto message = CefProcessMessage::Create("oxcart.input.record");
  auto args = message->GetArgumentList();
  args->SetString(0,kind); args->SetString(1,context); args->SetString(2,recording);
  args->SetDictionary(3,fields ? fields : CefDictionaryValue::Create());
  frame->SendProcessMessage(PID_BROWSER,message);
}
class Sink final : public CefV8Handler {
 public:
  Sink(CefRefPtr<CefFrame> frame, std::string context, std::string recording)
      : frame_(frame), context_(context), recording_(recording) {}
  bool Execute(const CefString&, CefRefPtr<CefV8Value>, const CefV8ValueList& args,
               CefRefPtr<CefV8Value>& retval, CefString&) override {
    retval = CefV8Value::CreateUndefined();
    if (!active_) return true;
    auto record = args.size() == 1 ? Native(args[0]) : nullptr;
    if (record && record->GetType() == VTYPE_DICTIONARY)
      Send(frame_,"observer",context_,recording_,record->GetDictionary());
    else Send(frame_,"observer_conversion_failed",context_,recording_);
    return true;
  }
  void Deactivate() { active_ = false; frame_ = nullptr; }
 private:
  bool active_ = true;
  CefRefPtr<CefFrame> frame_;
  std::string context_, recording_;
  IMPLEMENT_REFCOUNTING(Sink);
};
struct Context {
  int browser;
  CefRefPtr<CefFrame> frame;
  CefRefPtr<CefV8Context> v8;
  std::string id, recording;
  CefRefPtr<CefV8Value> dispose;
  CefRefPtr<Sink> sink;
};
class App final : public CefApp, public CefRenderProcessHandler {
 public:
  CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() override { return this; }
  void OnContextCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
                        CefRefPtr<CefV8Context> context) override {
    CEF_REQUIRE_RENDERER_THREAD();
    uuid_t nonce; char text[37]; uuid_generate_random(nonce); uuid_unparse_lower(nonce,text);
    const std::string id(text);
    contexts_.push_back({browser->GetIdentifier(),frame,context,id,"",nullptr,nullptr});
    Send(frame,"context_ready",id,"");
  }
  void Stop(Context& entry) {
    if (entry.recording.empty()) return;
    if (entry.dispose) entry.dispose->ExecuteFunction(nullptr,{});
    if (entry.sink) entry.sink->Deactivate();
    Send(entry.frame,"context_disabled",entry.id,entry.recording);
    entry.dispose = nullptr; entry.sink = nullptr; entry.recording.clear();
  }
  void OnContextReleased(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame>,
                         CefRefPtr<CefV8Context> context) override {
    CEF_REQUIRE_RENDERER_THREAD();
    for (auto it = contexts_.begin(); it != contexts_.end(); ++it) {
      if (!it->v8->IsSame(context)) continue;
      const auto recording = it->recording;
      if (context->Enter()) { Stop(*it); context->Exit(); }
      else if (it->sink) it->sink->Deactivate();
      Send(it->frame,"context_released",it->id,recording);
      contexts_.erase(it); break;
    }
  }
  bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
      CefProcessId source, CefRefPtr<CefProcessMessage> message) override {
    CEF_REQUIRE_RENDERER_THREAD();
    if (source != PID_BROWSER || message->GetName() != "oxcart.input.set") return false;
    auto args = message->GetArgumentList();
    if (args->GetSize() != 2 || args->GetType(0) != VTYPE_STRING || args->GetType(1) != VTYPE_STRING) return true;
    const std::string recording = args->GetString(0), context = args->GetString(1);
    for (auto& entry : contexts_) {
      if (entry.browser != browser->GetIdentifier() || entry.frame->GetIdentifier() != frame->GetIdentifier() || entry.id != context) continue;
      if (entry.recording == recording) break;
      if (!entry.v8->Enter()) { Send(frame,"context_unavailable",context,recording); break; }
      Stop(entry);
      if (!recording.empty()) {
        entry.recording = recording;
        entry.sink = new Sink(frame,context,recording);
        CefRefPtr<CefV8Value> factory;
        CefRefPtr<CefV8Exception> exception;
        if (entry.v8->Eval(kOXInputObserver,"oxcart:input-observer",1,factory,exception) && factory && factory->IsFunction()) {
          entry.dispose = factory->ExecuteFunction(nullptr,{CefV8Value::CreateFunction("record",entry.sink)});
        }
        if (!entry.dispose || !entry.dispose->IsFunction()) {
          auto details = CefDictionaryValue::Create();
          details->SetString("message",exception ? exception->GetMessage() : "observer did not return its cleanup function");
          Send(frame,"observer_install_failed",context,recording,details);
          entry.sink->Deactivate(); entry.sink = nullptr; entry.dispose = nullptr;
        }
      }
      entry.v8->Exit(); break;
    }
    return true;
  }
 private:
  std::vector<Context> contexts_;
  IMPLEMENT_REFCOUNTING(App);
};
}
CefRefPtr<CefApp> OXInputRendererApp() { return new App; }

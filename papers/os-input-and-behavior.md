# Native input, contextual behavior, and external network intervention

Research pass: 2026-10-01. Scope: the operator's dedicated browser window,
macOS first and Linux second. The model must not directly actuate the page;
keyboard, pointer, and scrolling actions are to pass through the OS. The
operator subsequently clarified that network interruptions should be deliberately
caused **outside** the browser, so Chromium encounters an actual change in its
environment, with the intended privacy effect of perturbing tracker inference.
This is distinct from reacting to naturally occurring interruptions.

This report establishes mechanisms and research questions, not an implementation
or an assertion that generated activity is indistinguishable from a person.
No input was injected, no permission was requested, and no host network setting
was changed. References are for study; no dependency was adopted.

`os-input-sources.json` contains 17 papers, 31 documentation/source records,
and three reference repositories, plus seven pinned source snapshots. D means substantive relevant sections read;
A means original abstract or selected excerpt; L means a verified lead whose
substantive text remains unread. D does not mean every page or source path was
read. Actual acquisition and revision records belong to the unified manifest.

## The claims have different boundaries

| Claim | Evidence needed | What it does not establish |
| --- | --- | --- |
| The agent uses OS input | Native actuation path and a receiver-side event trace | A physical device or person originated it |
| The browser treats input as normal native input | Browser event sequence, focus, coordinates, scroll and text outcome on a controlled page | A site will accept it or its broader behavior is human |
| A page event has `isTrusted=true` | The page's event observation | Human authenticity, authority to spend, or privacy |
| Behavior matches measured human interaction | Held-out, task/device-conditioned comparisons of complete trajectories and sequences | Equivalence for all people, sites, tasks or trackers |
| An external interruption reached Chromium | OS state plus Chromium/page/network observations | Packet loss necessarily caused an `offline` event |
| The intervention protects privacy | A defined observer and direct inference/linkability measurement | Erasure of identity, cookies, account state or engine fingerprint |

WHATWG defines `isTrusted` in terms of user-agent dispatch. Script
`dispatchEvent()` sets it false; the standard's event creation algorithms can
set it true. This is provenance within the event system, not an authentication
claim about the actor. OS input must be tested in the chosen browser build;
the standard alone does not prove every native injection path's exact behavior.
[DOM Standard](https://dom.spec.whatwg.org/#dom-event-istrusted).

## Human movement is structured variation

Fitts' law describes a speed–accuracy relationship for aimed movements. The HCI
Shannon form is `MT = a + b log2(A/W + 1)`, with movement amplitude A and target
width W measured consistently. It predicts aggregate movement time; it does not
generate a complete cursor trace. MacKenzie's analysis addresses effective target
width, approach angle, error handling, device and task differences, and the danger
of transplanting coefficients between experiments. For Bow Shock, it suggests
conditioning timing on actual target geometry and calibrating on the intended
device/display/task conditions, rather than choosing a universal pause range.
[Fitts 1954](https://doi.org/10.1037/h0055392),
[MacKenzie 1992](https://www.yorku.ca/mack/hci1992.html).

Flash and Hogan's minimum-jerk model predicts smooth, approximately straight
point-to-point arm movements and bell-shaped velocity profiles under the studied
conditions. It offers a candidate mean movement shape. It is a planar arm-motion
model, not evidence that a fixed polynomial plus random cursor offsets reproduces
desktop behavior. Harris and Wolpert instead relate variation to the magnitude
of the motor command. Together these sources motivate correlated trajectory
variation with task constraints, rather than independent, constant-variance
position and timing noise. Transferring either motor account to OS cursor input
requires measurement.
[Flash and Hogan 1985](https://pubmed.ncbi.nlm.nih.gov/4020415/),
[Harris and Wolpert 1998](https://www.nature.com/articles/29528).

Todorov and Jordan's stochastic optimal feedback account resolves variation
and goal achievement together: correction depends on whether a deviation matters
to the task. An inference for this project is that behavior should retain a goal
and update against observations during an action, instead of replaying an entire
precomputed noisy path after the UI has moved. Their biological control model
does not determine a browser's safety policy. A human moving the pointer, focus
loss, or a stale target must take precedence over any motion model.
[Todorov and Jordan 2002](https://doi.org/10.1038/nn963).

Input hardware and OS transfer functions change the relation between hand motion
and visible cursor motion. Casiez and Roussel document raw device counts,
display resolution, sampling and velocity-dependent transfer functions; their
libpointing toolkit separates devices from transfer functions. Its 2011 OS
measurements are historical, so current macOS behavior needs remeasurement.
Generating absolute display positions at Quartz level and generating relative
device motion at Linux uinput level need not encounter the same transfer path.
The visible result is the relevant measurement boundary.
[No more bricolage!](https://gery.casiez.net/publications/UIST2011-NoMoreBricolage.pdf),
[libpointing](https://github.com/INRIA/libpointing).

Scrolling needs a distinct model. Hinckley and colleagues find that distance,
required tolerance, device and acceleration affect target acquisition while
scrolling. Turner and colleagues studied reading and skimming with 18 company
employees using a wheel and formatted Wikipedia passages. Scrolls arrived in
chunks with retained context; viewport preferences and paragraph boundaries
mattered. Their unusually large font and one-paragraph-per-heading layout limit
generalization, and headings cannot be separated from paragraph boundaries in
that study. Applying one smooth cursor-motion model to both wheel bursts and
trackpad momentum would discard the relevant mechanism.
[Hinckley et al. 2002](https://cutrell.org/papers/Scrolling_CHI02.pdf),
[Turner et al. 2015](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/PETMEI2015scrolling_petmei_15_final.pdf).

The reading and search literature also warns against equating dwell with one
process. Cursor position sometimes reflects attention, while search examination
varies with the person and task; text difficulty and reader background affect
scrolling. KLM separates motor operations, mental preparation and system response
for expert fixed-method tasks. Its constants are not a general distribution for
thinking, typing, reading or waiting. Plausible pauses should follow the task's
actual state, and the model should report waiting explicitly to the person.
[Huang et al. 2011](https://www.microsoft.com/en-us/research/publication/no-clicks-no-problem-using-cursor-movements-to-understand-and-improve-search-2/),
[White and Dumais 2012](https://www.microsoft.com/en-us/research/publication/large-scale-analysis-of-individual-and-task-differences-in-search-result-page-examination-strategies/),
[Readability study 2021](https://arxiv.org/abs/2105.06354),
[Card, Moran and Newell 1980](https://doi.org/10.1145/358886.358895).

Interruption is another state transition. Altmann and Trafton's memory-for-goals
model concerns cues, interference and goal resumption. Their 2004 experiment
series involved 96 students; preserving cues during an impending interruption
helped reliably in the eight-second-lag experiment, not uniformly at every lag.
The design inference is to preserve the intended action and visible context,
then reacquire the current target before resuming. It does not justify inserting
arbitrary delays or manufacturing human confusion.
[Memory for goals](https://doi.org/10.1207/s15516709cog2601_2),
[Task interruption](https://www.interruptions.net/literature/Altmann-CogSci04.pdf).

### Annotated paper reading register

| Source | Depth | Relevant boundary or next read |
| --- | --- | --- |
| Fitts 1954 | A | Physical stylus task and original introduction/experiment excerpt; not a desktop generator |
| MacKenzie 1992 | D | Formula, effective width, corrections and methodological limits |
| Flash–Hogan 1985 | A | Abstract and original model/results excerpts; read remaining experimental detail |
| Meyer et al. 1988 | L | Bibliography verified; stochastic optimized submovement account described by MacKenzie; obtain original full text |
| Harris–Wolpert 1998 | A | Publisher abstract and original author PDF model excerpts |
| Todorov–Jordan 2002 | D | Feedback/variability/minimal-intervention framework; not all experimental examples |
| Accot–Zhai 1997 | A | Original abstract excerpt; trajectory constraints/steering differ from free pointing |
| Hinckley et al. 2002 | A | Original abstract/opening; read device experiment details |
| Casiez–Roussel 2011 | D | Toolkit, transfer units, OS function and evaluation excerpts |
| Quinn et al. 2013 | L | Touch-scrolling author index verified; primary HAL PDF retrieval failed |
| Turner et al. 2015 | D | Methods, results and explicit layout limitations |
| Altmann–Trafton 2002 | A | Abstract and interruption section, not full theoretical paper |
| Altmann–Trafton 2004 | D | Methods, results and discussion |
| Huang et al. 2011 | A | Original abstract; full PDF located |
| White–Dumais 2012 | A | Original abstract and original feature/results excerpts |
| Readability 2021 | A | Original abstract only; dataset and covariate details still to read |
| Card–Moran–Newell 1980 | A | Original paper opening; cannot claim measured keystroke distributions |

The paper and acquisition URLs are in [the source catalog](os-input-sources.json).

## Native actuation and capture

### macOS

Apple describes Quartz events originating through device drivers, the window
server and the target application's event handling. `CGEventPost` posts a
constructed event into this stream, before taps at the selected location.
Creating/posting an event is software input synthesis; posting at a location
named HID does not itself create a physical HID device.
[CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent),
[CGEventPost](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:)).

Event synthesis, event listening, accessibility access and screen capture are
separate operations to account for. The installed MacOSX15.5 SDK's `CGEvent.h`
documents `CGPreflightPostEventAccess` and `CGPreflightListenEventAccess` as checks
for those respective access classes, with separate request functions that may
prompt. Apple DocC's `AXIsProcessTrustedWithOptions` documentation says the
accessibility prompt is asynchronous and does not affect the immediate return
value. A permission request must therefore not be treated as successful grant.
This research only read the declarations and documentation.
[Posting access](https://developer.apple.com/documentation/coregraphics/cgpreflightposteventaccess()),
[Listening access](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()),
[Accessibility trust](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).

Hammerspoon provides concrete native source for study:
`extensions/eventtap/libeventtap.m` and `libeventtap_event.m`. Reviewed functions
create key pairs and scroll events, choose session/process posting paths and
maintain a private CGEventSource. Its docs call out Secure Input preventing
keyboard interception and wheel line/pixel units. Its default delays are library
choices, not measurements of human behavior. Do not adopt its broad OS automation
interface as Bow Shock's delegation interface.
[Source](https://github.com/Hammerspoon/hammerspoon/tree/master/extensions/eventtap),
[Eventtap docs](https://www.hammerspoon.org/docs/hs.eventtap.html).

Design questions for a dedicated window include display scale and coordinate
mapping, foreground/focused window identity, keyboard layout and composition,
modifier state, held buttons, nested scroll targets, display changes, app switch,
and cancellation between down/up events. The broker must contain the authority
to actuate, bound each action to the delegated window and stop on human takeover.
Checking focus then posting is potentially racy; the eventual design needs to
state and directly test the allowed race, rather than assume a separate window
is an OS security boundary. Process-targeted posting is a different routing
choice whose behavior and permitted scope also need testing.

### Linux

| Mechanism | Source-grounded role | Implication |
| --- | --- | --- |
| uinput | Creates a userspace-controlled virtual input device whose events enter kernel/userspace consumers | Device capabilities, node permissions and seat routing matter; potentially broad authority |
| XTEST | X11 input-synthesis extension | Server/session-specific; not a general Wayland API |
| X RECORD | Records X protocol and device/delivered events; supports synchronization information for replay | Observation does not enforce replay synchronization or a grant boundary |
| libei/EIS | Emulated input enters the compositor's normal input stack | Compositor can distinguish and control it; ordinary Wayland clients see normal device input |
| RemoteDesktop portal | Consented session, granted device types, EIS connection or legacy Notify methods | Backend support and session revocation/persistence must be explicit |
| InputCapture portal | Compositor-activated, barrier-triggered input capture | Redirects active input; cannot be assumed passive whole-desktop monitoring for takeover |

[Kernel uinput](https://docs.kernel.org/input/uinput.html),
[XTEST](https://xorg.freedesktop.org/archive/X11R7.7/doc/libXtst/xtestlib.html),
[X RECORD](https://www.x.org/releases/current/doc/libXtst/recordlib.pdf),
[libei](https://libinput.pages.freedesktop.org/libei/),
[RemoteDesktop](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.RemoteDesktop.html),
[InputCapture](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.InputCapture.html).

The portal's `parent_window` identifies UI association; it should not be inferred
to confine keyboard/pointer authority to that window. A Wayland port must examine
the actual compositor/backend and determine how ordinary human activity cancels
agent actions. Current documentation describes version 2; availability on a
specific Linux desktop remains untested. The libei GitLab source page was
bot-blocked; public protocol documentation was readable. Do not invent an
official GitHub mirror.

## Network simulation outside the browser

The desired intervention has a real implementation path, but the word
“interruption” hides different observables. A dropped packet, failed request,
unreachable destination, missing default route, lost interface address and
disconnected link are different conditions. Disabling one interface also may
leave another usable path. A browser's network-quality estimate and online state
are distinct again.

WHATWG defines `navigator.onLine=false` as definitely offline and true as possibly
online, and specifies `online`/`offline` events when that value changes. It
explicitly calls this indicator unreliable for Internet access. Therefore
packet loss or an unreachable server can coexist with `onLine=true`.
[HTML online state](https://html.spec.whatwg.org/multipage/system-state.html#navigator.online).

### What Chromium currently observes

Selected upstream code was read at commit
`914e10757b012f036db5a1fcbb9367815a799091`; the seven reviewed source snapshots
are separately cataloged. A mutable `main` discovery URL must not substitute
for the eventual CEF/Chromium version pin. Older documents referring to
`network_change_notifier_mac.cc` do not describe the current path.

On Apple, `net/base/network_change_notifier_apple.mm` contains a feature-controlled
`nw_path_monitor` path and a legacy SCNetworkReachability implementation guarded
by build flags. The monitor maps satisfied paths to an interface-derived type,
satisfiable paths to unknown, and invalid/unsatisfied paths to none. The older
macOS watcher receives SCDynamicStore network configuration changes, including
IPv4/IPv6 and primary interface state. Configuration/IP and connection-type
notifications are separate; aggregate notification parameters include delays.
Consequently neither firewall loss nor a brief interface change can be assumed
to produce a specific immediate page event. Bow Shock's own NWPathMonitor can
observe native conditions but cannot set them or certify a destination works.
[Apple notifier source](https://chromium.googlesource.com/chromium/src/+/914e10757b012f036db5a1fcbb9367815a799091/net/base/network_change_notifier_apple.mm),
[Configuration watcher](https://chromium.googlesource.com/chromium/src/+/914e10757b012f036db5a1fcbb9367815a799091/net/base/network_config_watcher_apple.cc),
[NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor).

On Linux, the address tracker processes netlink address/link changes and checks
non-loopback links against UP, LOWER_UP and RUNNING flags. It derives connection
type from the available interfaces; the reviewed code also filters `tun` tunnel
interfaces. The current notifier adds feature-controlled XDG NetworkMonitor
portal online-state handling alongside netlink. Portal offline can force none;
portal online can turn a netlink-none result into unknown. An isolated network
namespace that shares a host desktop's D-Bus portal may therefore yield a
different result than a netlink-only assumption predicts. The derived notifier
also has delay parameters. Build features and backend configuration need to be
recorded with an experiment.
[Linux notifier](https://chromium.googlesource.com/chromium/src/+/914e10757b012f036db5a1fcbb9367815a799091/net/base/network_change_notifier_linux.cc),
[Address tracker](https://chromium.googlesource.com/chromium/src/+/914e10757b012f036db5a1fcbb9367815a799091/net/base/address_tracker_linux.cc),
[Portal integration](https://chromium.googlesource.com/chromium/src/+/914e10757b012f036db5a1fcbb9367815a799091/net/base/network_change_notifier_linux_portal.cc).

Blink's `NavigatorOnLine` getter returns `GetNetworkStateNotifier().OnLine()`.
The platform notifier separately stores online state and network-quality/type
information. The complete browser-to-renderer IPC path was not traced in this
pass; it remains a version-specific follow-up before designing a guarantee about
the page's resulting event order.
[Getter](https://chromium.googlesource.com/chromium/src/+/914e10757b012f036db5a1fcbb9367815a799091/third_party/blink/renderer/core/frame/navigator_on_line.h),
[Blink state notifier](https://chromium.googlesource.com/chromium/src/+/914e10757b012f036db5a1fcbb9367815a799091/third_party/blink/renderer/platform/network/network_state_notifier.cc).

### Candidate mechanisms and their limits

| External mechanism | Changes | Expected browser observation to test |
| --- | --- | --- |
| macOS Network Link Conditioner | Transport conditions on traffic through an existing connection | Latency/loss/timeout/quality changes; do not assume offline state |
| macOS PF filtering | Matching packets; state/rule selection is relevant | Request/transport failure; does not by itself change interface link state |
| macOS interface/address/route intervention | Actual network configuration/path state | Native path/config callbacks, then Chromium state; surviving paths may prevent offline |
| Linux namespace with veth | Browser network devices/stacks/routes/firewall scope | Netlink inside namespace; verify network service and child processes share scope |
| Linux `tc netem` | Queued packet delay/loss/corruption/reordering/rate | Request and measured network quality; link generally remains present |
| Linux link/address removal in isolated topology | Link/address state that Chromium tracks | Connection/IP notification and possibly online/offline; portal state can modify result |

Apple's WWDC19 transcript recommends Network Link Conditioner for adverse-network
testing on macOS. That confirms the developer-tool approach, not current package
compatibility or per-browser isolation. The installed SDK's `pfctl(8)` describes
packet filtering and separate anchors; its semantics were read without invoking
the utility. Apple publishes ifconfig and route source manuals. PF packet rules,
route manipulation and link state should not be treated as interchangeable, and
the current OpenBSD PF manual is not a substitute for Apple's implementation.
[Apple adverse-network session](https://developer.apple.com/videos/play/wwdc2019/422/),
[Apple interface manual](https://raw.githubusercontent.com/apple-oss-distributions/network_cmds/main/ifconfig.tproj/ifconfig.8),
[Apple route manual](https://raw.githubusercontent.com/apple-oss-distributions/network_cmds/main/route.tproj/route.8).

Linux namespaces isolate network devices, routing, firewalls and protocol stacks.
They do not independently isolate GUI focus, desktop permission or external agent
transport. Netem provides correlated loss/jitter and distribution choices, but
the manual identifies timer granularity, TCP and placement constraints. It is a
network-test mechanism, not a promise of faithful reproduction of every physical
network condition. No commands to create a namespace or modify a queue were run.
[Namespaces](https://www.man7.org/linux/man-pages/man7/network_namespaces.7.html),
[Netem](https://www.man7.org/linux/man-pages/man8/netem.8.html).

A dedicated window does not imply dedicated network scope. If windows share a
browser/network service process, a process/network intervention may affect all
of them; host interface changes can also disconnect Codex. On macOS, the isolated
test environment and deployment mechanism need separate design work; on Linux,
the browser's process tree and its portal connection need examination. The
environment controller should remain outside the model's direct actuation
authority. During an interruption the input broker should preserve human
control, invalidate pending stale actions and require a fresh observation on
recovery. These are design proposals, not findings that the sources implement
Bow Shock's control policy.

## What to specify and measure next

The proposed behavioral model should condition on task mode, target geometry,
device/input path, window/display state, prior action, page response and actual
interruption state. Parameters should vary across a coherent action or session,
with corrections driven by updated observations. The intended privacy
intervention is a separate experimental variable. Neither a universal “human”
profile nor independent random delays is justified by this literature.

| Question | Direct evaluation proposed |
| --- | --- |
| Did the native action reach the intended control? | Controlled receiver records focus, event sequence and resulting UI state |
| Can a person take control back? | Race tests interleave real human input/focus change with bounded native sequences; inspect last effect and held state |
| Does motion match the specified population and task? | Held-out sessions compare timing/geometry/corrections, velocity and autocorrelation jointly, conditioned on task/device |
| Does scrolling preserve context? | Controlled read/search tasks measure chunks, reversals, pause context and completion, with separate wheel/trackpad groups |
| Did the intervention cause the intended network state? | Record OS path/link/address and browser/page events alongside request outcomes in isolated tests |
| Does tracker inference change? | A stated observer evaluates linkability or task/behavior inference with intervention on/off; measure utility cost at the same time |

Receiver-side native/browser behavior and statistical similarity are different
fault classes; neither certifies the other. Privacy effectiveness must be judged
against an observer's actual retained information. A synchronized interruption
and unusual recovery pattern might add a useful identifying feature; that is an
experimental concern, not a demonstrated result of this pass. The tracking
literature and broader observer model are covered in the separate privacy lane.

## Retrieval gaps and deferred work

- Initial Iowa Fitts and old MIT Flash/Hogan PDF URLs returned 404 during unified
  acquisition. Fitts' UW mirror currently requires institutional login. An
  [updated MIT author-hosted Flash/Hogan copy](https://bpb-us-e1.wpmucdn.com/sites.mit.edu/dist/5/1384/files/2025/02/1985-the-coordination-of-arm-movements-an-experimentally-confirmed-mathematical-model.pdf)
  was verified readable as the original 16-page article; the publisher-deposited
  [PMC record](https://pmc.ncbi.nlm.nih.gov/articles/PMC6565116/) also links a PDF.
- Obtain and deeply read Meyer et al. 1988 from an author/publisher/institutional
  source; this pass verified its bibliographic record and read MacKenzie's account.
- HAL's author-deposited Quinn touch-scroll PDF failed through the web tool.
  Locate an author-accessible copy before using its specific transfer results.
- Apple DocC HTML often exposes only a JavaScript shell. Relevant accessibility
  and permission DocC JSON plus installed MacOSX15.5 SDK declarations were read;
  minimal public pages do not justify undocumented permission mapping claims.
- Verify current Network Link Conditioner distribution/compatibility with the
  operator's macOS version. Apple's documented macOS recommendation is historical.
- Apple archived PF manual is a retrieval lead. The actual local SDK `pfctl(8)`
  was readable. Preserve local/manual provenance rather than silently substituting
  current OpenBSD behavior.
- libei's official GitLab source was bot-blocked. Public protocol/API docs were
  accessible; acquire a pinned release/source through a verified official route.
- Read the chosen Chromium release's network feature defaults/build flags,
  event plumbing and tests. Pin that version before drawing product guarantees
  from current upstream selected functions.
- Acquire modern keyboard/composition and macOS trackpad/scroll-momentum evidence;
  the present corpus does not establish these distributions.

There is no completeness claim. This pass establishes a concrete primary-source
starting point and identifies the measurements needed to turn the operator's
behavioral and environmental preferences into a reviewable design.

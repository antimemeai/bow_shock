# Fingerprint consistency and privacy experiments

Reviewed 2026-10-01. Scope: the two papers' abstracts and principal findings,
Brave's historical design account, and the native implementation review linked
below. This is not a survey of current commercial bot detectors.

The operator wants ordinary site compatibility while disrupting intrusive
inferences. Runtime identity, tracking resistance, and motor behavior need
separate measurements. A browser can have internally consistent API outputs
while its interaction timing or network interventions remain distinctive.

[FP-Scanner (2018)](https://www.usenix.org/conference/usenixsecurity18/presentation/vastel)
studies inconsistencies introduced by fingerprint countermeasures. Its enduring
lesson for this project is to examine relationships among exposed properties,
rather than change an isolated user-agent string and assume acceptance. Its
historical detector results do not establish what today's sites accept. The
acquired Chromium code independently makes user-agent/client-hint consistency
an implementation concern; see [native browser surfaces](native-browser-surfaces.md).

[FP-Inspector](https://arxiv.org/abs/2008.04480) combines analysis of scripts and
their behavior to identify fingerprinting. It is relevant to recognizing
observation activity in our logs, rather than synthesizing an undetectable
browser. Requests alone cannot reveal every local computation or every use of
fingerprinting data.

[Brave's 2020 farbling design](https://brave.com/privacy-updates/4-fingerprinting-defenses-2.0/)
describes perturbing selected API outputs with consistency within a site and
session. This is a useful comparison for privacy experiments: variation has a
scope and lifetime, rather than independent randomness on each access. The
article is historical evidence, not verification of current Brave behavior or
support for changing Bow Shock's engine APIs.

The operator's proposed external interruption is a different intervention.
It changes the environment through which Chromium runs. That can affect request
completion, retry behavior, timing, and possibly reachability observations.
It does not by itself conceal stable browser properties or already transmitted
identifiers. Whether it disrupts a particular tracker inference must be tested
against that inference. See [OS and network signals](os-input-and-behavior.md)
and [traffic baselines](network-observatory.md).

## Measurements to specify before implementation

- Compatibility: page functionality, login/session continuity, and observed
  challenge/error rates on representative permitted workflows.
- Identity: agreement across engine, platform, user agent, client hints, and
  other exposed properties; describe which measurements the test actually sees.
- Privacy: a defined inference and its accuracy across baseline and intervention
  conditions. Reduced inference accuracy is different from added randomness.
- Behavioral effects: input and network traces, repeatability, retry bursts,
  and any new pattern created by the intervention itself.

Use controlled pages and an owned server to correlate renderer-visible,
OS-level, and server-visible signals. Compare conditions with the same browser
version and task. Record interventions explicitly in the observatory so their
effects can be explained. No fingerprint spoofing or network intervention has
been implemented, and this review makes no undetectability claim.

Acquisition: [fingerprint catalog](fingerprint-sources.json) and
[actual artifacts](acquisition.json).

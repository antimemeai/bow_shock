# Human-input original artifacts and restoration

Acquired 2026-10-16 for source study. Original archives are intact under ignored
`quarantine/human-input/`; no acquired implementation was executed or adopted.
The binary ledger `quarantine/human-input/acquisition.bplist` records exact URLs,
resolved URLs, acquisition times, byte lengths and hashes. Individual acquisition
records remain under `quarantine/human-input/acquisitions/`; the ledger is a
convenience index. The typing ZIP is retained whole, not a sample download.

## Originals

| Source | Artifact under `quarantine/human-input/` | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| [aalto-capture](https://codeload.github.com/aalto-ui/136m-keystrokes/tar.gz/98dcee94dc6c0464b35e8ca43d60e1b225cc621f) | `aalto-capture-98dcee94.tar.gz` | 69807558 | `f9d9d7d1f14473c2e89fbe98850a03e9394046ddc20fff8a98bbeccb5d2e3670` |
| [aalto-keystrokes](https://userinterfaces.aalto.fi/136Mkeystrokes/data/Keystrokes.zip) | `Keystrokes.zip` | 1572785433 | `5fb217e0e1273017a6789c5c7ebcc00eed624f2f6426c284da2077a88e270420` |
| [aalto-paper](https://userinterfaces.aalto.fi/136Mkeystrokes/resources/chi-18-analysis.pdf) | `dhakal-2018.pdf` | 2905386 | `e5e72facf874deed7b18fcf87f827dce565a8c56f6f7a99de4564303301496a2` |
| [balabit-mouse](https://codeload.github.com/balabit/Mouse-Dynamics-Challenge/tar.gz/d00d6f779254a2a917deeab4a5b7a9e8643bd91e) | `balabit-d00d6f77.tar.gz` | 44628882 | `f4c484c30678c3c58235f6ee78e35636f29abd2e69f379bbb46aec7ca083acef` |
| [character-errors](https://www.yorku.ca/mack/nordichi2002-shortpaper.pdf) | `mackenzie-soukoreff-2002.pdf` | 203349 | `ec8950f158338bc0164eae291fd4bbb4ef63dd45f354493f1f66eb372018b6bf` |
| [error-metrics](https://www.yorku.ca/mack/chi03.pdf) | `soukoreff-mackenzie-2003.pdf` | 429104 | `46f5ec133e20dbdad91ae80d05e0694297c2d918dbcf7d0ba2df883983999b29` |
| [input-events](https://www.w3.org/TR/2026/WD-input-events-2-20261015/) | `input-events-2-20261015.html` | 136597 | `d4669f3a34c978edd329ed3fd37fc36d20fe1b473b310d3c600934262ed07ca3` |
| [pointer-events](https://www.w3.org/TR/pointerevents3/) | `pointer-events.html` | 595222 | `552c4d85256fbeb1a54aea79f03d9ae7e1f99bcbbc65fcf35c3b355574deb6e5` |
| [ui-events](https://www.w3.org/TR/2026/WD-uievents-20260221/) | `ui-events-20260221.html` | 920762 | `8ded5eaf4f190b13c59582d5e92b81d3585112dde963d71d65d8e5991212b918` |

Repository sources: Aalto capture is pinned at
`98dcee94dc6c0464b35e8ca43d60e1b225cc621f`; Balabit data is pinned at
`d00d6f779254a2a917deeab4a5b7a9e8643bd91e`. The retained Pointer Events page
identifies its dated version as `REC-pointerevents3-20260630`; UI Events and
Input Events snapshots are the dated drafts shown in their filenames.

## Terms and scope

The Aalto dataset README permits non-commercial research/projects with author
attribution. Its capture software separately has an MIT license; that software
license is not the data license. The Balabit archive has a public research
README but no LICENSE file. Papers retain their author/publisher notices; W3C
snapshots link their document licenses. These are research materials; no source
code, dataset or fitted behavioral model is selected for product redistribution.

The Aalto ZIP contains 168,593 participant files, readme and participant metadata.
Only a deterministic 100-participant sample was analyzed in this pass. The entire
Balabit training subset was inspected; the preserved original archive also
contains the challenge test files and public labels. Original ZIP/TAR bytes have
not been edited. PDF reading copies are under `papers/pdfs/human-input/`.

## Restore

```sh
python3.13 scripts/acquire-human-input.py
python3.13 scripts/inspect-human-input.py
```

The first utility also accepts source IDs, for example
`python3.13 scripts/acquire-human-input.py aalto-paper`. Existing files are checked
against their recorded digest. Failed/changed downloads remain separately named
`.partial` files and do not replace an original. When restoring without the
local ledger, compare the downloaded SHA-256 values with the table above.

Clean reference extraction uses the existing owned extractor:

```sh
python3.13 - <<'PYTHON'
from pathlib import Path
from scripts.acquire import extract
root = Path.cwd() / 'quarantine/human-input'
extract(root / 'balabit-d00d6f77.tar.gz', root / 'balabit', [])
extract(root / 'aalto-capture-98dcee94.tar.gz', root / 'aalto-capture', [
    'LICENSE', 'README.md', 'public/javascripts/typingtest.js',
    'app/models/Keystroke.scala', 'app/db/Keystrokes.scala'])
PYTHON
```

This retains all Balabit data and a declared five-file Aalto source subset;
Git metadata, node_modules and filesystem detritus are excluded by the extractor.
The complete original source archive remains available. No 16 GB typing-tree
extraction is needed: the inspection utility reads selected members directly
from the complete ZIP, preserving their original bytes.

[Reading and direct observations](empirical-human-input.md) distinguish corpus
inspection from calibration or implementation of the native executor.

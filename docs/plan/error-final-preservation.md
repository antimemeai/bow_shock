# Retain failed admitted model turns

The real Python.org extraction failed after its first model tool proposal.
Blackbird sent error then final, while Oxcart treated the error as the end of
the attempt and closed early. That discarded the final event and skipped the
attempt's response/received/model_finished artifacts. Command rejection instead
has an error with no final. Add an explicit final_follows flag on the Blackbird
side and use it in the native connection and extraction coordinator. Retain
request ownership through a failed admitted turn's final; report the error while
still working. Save its submission, response, failed outcome and actual error
message before finishing, without triggering the automatic tweak. Keep rejected
steer restoration and command rejection behavior. Check both native process
transport and coordinator artifacts with the actual event order, then exercise
the retained real reading through the repaired Blackbird without launching CEF.

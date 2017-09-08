#  ARCMS - Skygear demo of newly introduced ARKit and Vision framework in iOS11

* ARKit
* Vision: best performance according to Apple, Vision>CIDector>AVCapture

## Some flaws and workarounds...
Entity|Flaw|Workaround
-|-|-
Vision|expected: 1 QR code<br>actual: 2 same QR codes|Assumption: no twin in a session<br>Solution: Set([QRCode])
Vision|unstable result  for detecting multiple QR codes|Solution: do not remove node once added into session

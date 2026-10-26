# CDC macros - phase 2

Planned: watermark handling so each run reads only bronze rows newer than the last processed
`__load_timestamp` (Load_Pattern step 1), instead of re-reading all of bronze.

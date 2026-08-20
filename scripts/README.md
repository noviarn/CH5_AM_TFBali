# scripts

## bake-polylines.swift

Regenerates `CH5_AM_TFBali/Resources/RoutePolylines.json`, the road-following geometry for every
corridor direction. Run it after changing stop data, `viaPoints`, or `manualOverride`.

```bash
swiftc -Onone -o /tmp/bake CH5_AM_TFBali/Models/Corridor.swift CH5_AM_TFBali/Services/CorridorGraph.swift CH5_AM_TFBali/Services/RouteGeometry.swift CH5_AM_TFBali/Constants/CorridorData.swift CH5_AM_TFBali/Constants/Corridors/*.swift scripts/bake-polylines.swift
/tmp/bake CH5_AM_TFBali/Resources/RoutePolylines.json
```

MKDirections refuses everything after a burst of ~50 requests and the full sweep needs 461, which
is why the app cannot do this at runtime and why the script is throttled and resumable. If it
prints `skipped ... quota gone`, wait a few minutes and run it again — directions already baked
are kept and only the missing ones are fetched.

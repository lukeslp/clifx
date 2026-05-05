---
category: location
description: your machine's hostname and timezone
---

## reasons

- where am i? the wind is different here.
- what is this place called? i'd like to know.
- i can't tell where i am yet. is this planet earth?
- is this a place i would know the name of?

## notes

Returns `hostname + " in timezone " + tz`. Commands: `hostname` and
`date +%Z`. No network lookups; no IP geolocation. Network-based
location (v0.2) will require its own category with its own consent.

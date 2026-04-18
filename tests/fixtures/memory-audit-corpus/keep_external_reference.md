---
name: Oncall Grafana dashboard URL
description: Pointer to the latency dashboard oncall watches
type: reference
test_expected:
  classification: keep
---

`grafana.internal/d/api-latency` is the dashboard oncall watches. If touching request-path code, that's the thing that'll page someone. Private internal URL — do NOT promote to public docs.

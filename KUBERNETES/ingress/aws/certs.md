```bash
┌──────────────────────────────────────────────────────────────────────────┐
│ TLS CERTIFICATE STRATEGY — MAIN IDEAS                                   │
│                                                                          │
│ 1) SINGLE SAN / WILDCARD CERTIFICATES                                   │
│ • Easier to manage (fewer certs)                                        │
│ • Larger blast radius if compromised                                   │
│ • Wildcard certs do NOT cover apex domain                               │
│   (e.g., *.example.com ≠ example.com)                                   │
│                                                                          │
│ 2) MULTIPLE SMALL CERTIFICATES                                          │
│ • One cert per subdomain / app (+ apex)                                 │
│ • Better isolation and security                                        │
│ • Independent rotation and revocation                                  │
│ • Works well with ALB + SNI                                             │
│ • Requires more tracking and management                                │
│                                                                          │
│ 3) PRODUCTION BEST PRACTICE                                             │
│ • Issue separate cert for apex domain                                  │
│ • Issue separate certs for high-value subdomains                        │
│                                                                          │
│ 4) WILDCARD CERT USAGE GUIDELINES                                       │
│ • Use wildcard only for low-risk subdomains                             │
│ • Pair wildcard cert with a dedicated apex cert                         │
│                                                                          │
│ 5) KEY TRADE-OFF                                                        │
│ • Convenience vs Security                                               │
│ • Fewer certs → higher impact on compromise                             │
│ • More certs → better isolation, more operational effort               │
│                                                                          │
│ SUMMARY                                                                │
│ • Wildcards = easy, risky                                               │
│ • Small certs = secure, manageable with discipline                      │
│ • Critical systems should prefer isolation                              │
└──────────────────────────────────────────────────────────────────────────┘
```
* We can also use the single cert with (apex domain, wildcard-subdomains).

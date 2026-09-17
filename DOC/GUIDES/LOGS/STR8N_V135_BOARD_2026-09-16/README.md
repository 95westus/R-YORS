# STR8-N v1.35 board update — 2026-09-16

Status: PASS for the ordinary guarded top update and policy restoration on
COM4. This does not claim a new factory-migration qualification.

The canonical v1.35 top BIN SHA-256 is
`96416190B7E1A37E2C01A407AB9C8EA4ADE06855BBFD0DDCC306FF68418A359A`.
The v1.35 build retained the public ABI hash and layout, with 134 resident
bytes free.

The guarded updater verified the old B3:F backup in B2:F, installed v1.35,
verified the live top, and returned through software reset. A complete
four-bank archive then proved that only B2:F and B3:F changed and that B2:F
was the exact old top. The resulting flash SHA-256 was
`C0C0398CFB3A8A027963C341351418EAE311B868ED5E106D88F03D81F44118D3`.

The v1.35 STR8-iN Bank Maintenance editor restored scoped-search policy A6.
Its S-record SHA-256 is
`84F6887FFC75C2C8B4F6DF58DF4D48882DB64E94ABD46C882D24F0993B22D142`.
A second complete archive proved B1:A scratch restoration, B3:F-only change,
and no other flash changes. The accepted v1.35/policy-A6 baseline SHA-256 is
`D1D4B9DB35106CE84AC9F55983A745BD852A6ACBC4594F4D3AEC74FBFACF45AF`.

Machine-readable results are in `preflight.json`, `install.json`,
`verification.json`, `policy.json`, and `policy-verification.json`; raw serial
traffic is retained in `serial-com4.jsonl`.

# APMAN Read-Only Carrier Inspection Board Test

Status: accepted on COM4, 2026-09-10. The first board attempt exposed that the
resident HIMON `AP` front door did not forward `D`; the accepted pair therefore
includes the narrow HIMON dispatch bridge as well as the APMAN carrier.

`AP D Bn name|s000` uses APMAN's existing full-sector staging and AP-v2
validation path. It restores Bank 3 before printing from the `$0A00-$19FF` RAM
copy, reports all five section offset ranges, dumps exactly envelope offsets
`$0000-$003F`, and returns without loading or executing the selected BODY.

## Candidate identity

Build and check from the repository root:

```text
make -C SRC apman
```

Required host result:

```text
APMAN inspect check OK package=$0C23 body-end=$7BF5 sections=S:0005-0012,R:0013-0016,E:0017-0026,I:0027-002A,B:002B-0C22 dump=0000-003F self=APMAN read-only
```

The candidate AP-v2 package is `$0C23` bytes. Its BODY is `$7000-$7BF4`
(`$0BF5` bytes) with FNV-1a `$91D1C38E`.

## Installation precondition

Install `SRC/BUILD/s19/apman-v1-bank2-8000.s19` only into the currently
approved APMAN carrier location. Install the matching
`SRC/BUILD/s19/himon-apv2-bank3-c-e.s19` only into Bank 3 sectors C-E. Preserve
the previous accepted artifacts for recovery. STR8-N may update its Bank-3 F
directory journal while enrolling either image. Record complete CRC tables
after both approved installations; all 32 CRCs must remain identical across
the read-only command and regression phase.

Reset through STR8-N into HIMON before testing. Confirm ordinary inventory can
find the new manager and the existing carriers.

## 1. Inspect APMAN by name

At HIMON:

```text
AP D B2 APMAN
```

Required output for APMAN at B2:8:

```text
APD B2 8000 APC APMAN L=0C23 @7000
S 0005-0012
R 0013-0016
E 0017-0026
I 0027-002A
B 002B-0C22
0000: 41 50 02 23 0C 53 0B 00 01 00 70 F5 7B F5 0B 8E
0010: C3 D1 91 52 01 00 00 45 0D 00 01 81 00 00 20 86
0020: 16 9A 05 CD 08 70 08 49 01 00 00 42 F5 0B 80 04
0030: 41 4D 30 31 9C 61 7C 9C 6E 7C AD 60 7C C9 01 F0
```

Require one following HIMON prompt and no `AP LOAD`, `GO`, or child-manager
error. The command must not print bytes after offset `$003F`.

## 2. Inspect the same carrier by address

```text
AP D B2 8000
```

Require byte-for-byte identical output to the name-selected inspection above.

## 3. Rejection rails

Run these without changing flash:

```text
AP D B2 NO_SUCH_AP
AP D B2 8FFF
AP D B3 APMAN
AP D B2 APMAN 2000
```

Require the established APMAN errors for not-found/bad command cases, no dump
after any rejection, and one clean return to HIMON. Also exercise a known
malformed carrier fixture and duplicate-name fixture if those remain on the
approved test media; both must be rejected exactly as ordinary named `AP` is.

## 4. Regression and immutability

Run the existing `APS`, named `AP`, and `AP L` carrier checks with a safe
non-manager application. Then physically reset and confirm normal Bank-3 boot.
Capture a second complete 32-sector CRC table. It must match the table taken
after candidate installation exactly.

Append the exact identity, commands, output, CRC tables, and result to
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`. Do not check the feature-queue item or
publish `AP D` as hardware-accepted until this card passes.

## Accepted result

The name and address forms produced the exact output above. All four rejection
rails returned one established error and no dump. `APS`, `AP L`, and named
`AP` remained operational. A physical reset returned to HIMON
`00.0910(1343)`, and the complete post-test CRC table matched the post-install
baseline exactly. See [the focused transcript](../LOGS/APMAN_INSPECT_2026-09-10.md).

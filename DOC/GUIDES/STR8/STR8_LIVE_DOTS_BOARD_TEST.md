# STR8 Live-Dots and Warm-Selector Board Test

Status: hardware accepted.

This is the focused, non-destructive board rail for the compact startup and
prompt selector. It supersedes the startup spacing in earlier transcripts but
does not rewrite those accepted records.

Do not flash `str8-v1-installer-dry-f000.s19`; it deliberately overlaps the
stored worker. Until the V1 migration artifact exists, use the normal resident
STR8 candidate and expect `U 0-3 J0-3`. The eventual V1 artifact must instead
show the V1.02 surface `I H J0-3`. The accepted captures below retain the
earlier `3` spelling and are not rewritten.

The current generated normal candidate is `STR8-N V 00.0805(1704) $F`, staged
by `DOC/GUIDES/ASM/SAMPLES/OLD/str8n-topwrite-transient-3000.a`. Before writing,
require these exact resident bytes:

```text
F000: 4C 13 F0 4C 24 F3 4C 40 F3 4C 7E F4 53 52 01 07
F010: 4C 2B F3 78
FFFA: B6 F0 00 F0 CA F0
```

## Install the Normal Top-Sector Candidate

At HIMON, enter `ASM NEW`, send the complete topwriter source named above,
require `ASM OK` and `SEAL>`, then paste:

```text
.
G 3000
S
Q
```

Require `TW STG` and `TW OK`. Before programming, dump `$0A00-$0A13` and
require the same 20 header bytes shown above. Then paste:

```text
G 3000
P
WRITE
I
Q
D 1A00 1A03
D F000 F013
D FFFA FFFF
```

Require `TW PRG`, `TW OK`, `TW MODE=$01 RES=$AC @=$0000`, result bytes
`01 AC 00 00`, and the exact header/vectors above. Stop and preserve the
result tuple on any mismatch; do not retry `P` first.

## Required Startup Shape

STR8 first emits exactly 35 LF bytes to scroll a connected terminal clear.
The next phase is an approximately 5.904-second enumeration quarantine; its
16 dots are never polled. STR8 then flushes queued RX, prints its identity and
selector on consecutive lines, and opens 16 live dots over another 5.904
seconds:

```text
................
STR8-N V 00.mmdd(hhmm) $F
0/1/2=BOOT 3=HIMON S=STR8 ................
```

After the intentional 35-line clear there is no extra blank line before either
dot run, no numeric `6 5 4 3 2 1` countdown, and no repeated identity after
selecting `S`.

## Test 1: Enumeration Quarantine and Removed Keys

1. Enter STR8 from HIMON.
2. During the first dot run, transmit one valid `0` around dot 8.
3. After the banner appears, transmit `G`, then `R`, then `S` on successive
   live dots.

Require the early `0` to be discarded. Require live `G` and `R` to produce no
echo or action. Only `S` may echo and terminate the dots:

```text
................
STR8-N V 00.mmdd(hhmm) $F
0/1/2=BOOT 3=HIMON S=STR8 ...S
U 0-3 J0-3
STR8-N>
```

For a V1.02 candidate, substitute `I H J0-3` for the help line and use `H`
for the local warm entry. The bare-digit tests below describe the accepted
legacy image only.

## Test 2: Warm Prompt Selectors

At `STR8-N>`, exercise each bare digit separately:

- `0`, `1`, and `2` must immediately print `J B0`, `J B1`, or `J B2` and use
  the existing Bank Jump Record handoff. They must not print `BOOT IN 3S`.
- `3` must enter HIMON warm without printing the retired `G HIMON` message.
- `G` and `R` must remain at STR8 and print the compact help as unknown input.

Use the existing HIMON `STR8` entry or explicit `J3` to return between cases.
Dump `$1FFD-$1FFF` after each bank handoff and require `42 4A 00`, `42 4A 01`,
or `42 4A 02` respectively.

## Test 3: Explicit J3 Remains Distinct

Issue `J3` at `STR8-N>`. Require `J B3`, followed immediately by the first dot
run on the next line. The complete two-phase startup must recur. This remains
the explicit Bank-3/STR8 re-entry; bare `3` remains HIMON warm.

## Test 4: Live Selector Paths and Timeout

Run separate resets for these cases:

- live `0`, `1`, or `2`: echo the digit, print `J Bn`, retain `BOOT IN 3S`, and
  launch the same bank path as before;
- live `3`: enter HIMON warm;
- live `S`: print only the compact help and `STR8-N>` prompt;
- no input: finish all 16 live dots and enter HIMON cold.

Append the raw transcript to `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`. Record the
candidate identity and direct `$F000-$F013`/`$FFFA-$FFFF` reads before marking
this board rail accepted.

## 2026-08-05 Board Progress

The board run regenerated the same source as `STR8-N V 00.0805(1807) $F`.
Its pasted TopWriter image carried the pinned header and vectors above.
TopWriter first proved the negative confirmation path (`I` at the `WRITE`
prompt produced `TW CANCEL`), then completed stage, program, and verify with
`TW MODE=$01 RES=$AC @=$0000`.

The installed Bank-3 image visibly emitted the 35-LF clear before its first
dot run. Live `S` produced only `U 0-3 J0-3`; explicit `J3` printed `J B3`,
repeated the clear and complete two-phase startup, and timed out through HIMON
cold. A later live `3` printed `BOOT WARM` and entered HIMON immediately,
without a second 35-LF clear. `$1FFD-$1FFF` remained `42 4A 03`.

The same session ran the maintenance copy order chosen to preserve an older
fallback image:

```text
COPY 30  ........ OK
COPY 12  ........ OK
COPY 31  ........ OK
```

Thus B0 and B1 now contain the Bank-3 candidate, while B2 preserves the former
Bank-1 image. The final map showed every B0-B2 sector used and B3 sectors 8-E
used with B3F protected.

The continuation used `D F000 FFFF` in Bank 3 and Bank 1. Both reads contained
the exact header, identity, resident body, stored worker, and vector tail for
`1807`. B0 and B1 then repeatedly booted `1807`; B2 still booted the preserved
`1203` fallback and exposed its distinct header/vector image. This closes the
direct readback and post-copy boot checks.

The operator confirms that an early valid key was transmitted during the
unpolled first 16 dots and that live `G` and `R` were transmitted before the
accepted path. All three were ignored as required. This closes Test 1 and the
complete board rail; no further flash operation is required.

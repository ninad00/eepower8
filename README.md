# Z-bus Matrix Portal (MATLAB)

A general MATLAB program that holds the bus impedance matrix (Z-bus) of an N-bus
power system, waits for commands that change the network, works out which kind of
change each one is, updates the Z-bus and prints the new matrix.

Plain MATLAB, no toolboxes needed (tested in MATLAB R2026b).

## Files

| File | Purpose |
|------|---------|
| `zbus_portal.m`   | **Main program**: interactive portal (run this) |
| `zbus_modify.m`   | Engine: one topology change, with the type found automatically |
| `zbus_build.m`    | Builds the Z-bus from branch data with the building algorithm |
| `zbus_show.m`     | Prints the matrix with bus numbers (in column blocks for large N) |
| `zbus_branches.m` | Prints the branch list |
| `zbus_verify.m`   | Checks the Z-bus against `inv(Ybus)` |
| `zfmt.m`          | Formats an impedance as text |
| `zbus_demo.m`     | Self-test: every kind of change, plus 300 random changes on 60-bus systems |
| `zbus_fault_examples.m` | Fault-analysis lecture examples (9–23 Oct), solved with the Z-bus program and checked against the slides (separate from the portal) |
| `fault_examples_output.txt` | Output of `zbus_fault_examples` (90 checks passed, 0 failed) |
| `example_commands.txt` | A recorded session: answers and commands, one per line |
| `sample_run.txt`  | Output of `zbus_portal('example_commands.txt')` |
| `selftest_output.txt` | Output of `zbus_demo` (25 checks passed, 0 failed) |

## How to run

```matlab
>> cd C:\eeass
>> zbus_portal
```

1. **Insert the network.** Pick one:
   - Enter the N x N Z-bus. You can type it element by element (upper triangle;
     the matrix is symmetric), type it as one expression such as `[0.2j 0.1j; 0.1j 0.3j]`,
     or load it from a file with `load('zbus.txt')` for a large system.
   - Enter branch data `[from to Zb]`, with bus 0 as the reference. The Z-bus is
     then built step by step.
   - Use the built-in 4-bus example.
2. **Give a command** to change the topology. Pick it from the menu by number, or
   type it in one line:

   | Command | Meaning |
   |---------|---------|
   | `add p q Zb`       | add a branch or a new bus (Type 1 to 4, found automatically) |
   | `remove p q [Zb]`  | remove a branch (line outage) |
   | `change p q Znew`  | change a branch impedance |
   | `delbus k`         | remove bus k with all its branches |
   | `show`, `branches`, `verify`, `undo`, `save`, `help`, `exit` | utilities |

3. The program names the type of change, applies the formula and **prints the new Z-bus**.

Impedances can be complex, for example `0.25j` or `0.02+0.08j`.

**Replaying a command file.** `zbus_portal('example_commands.txt')` reads the answers
and commands from a file, one per line, and prints the session. This is useful for a
large system, and it also works from the command line:
`matlab -batch "zbus_portal('example_commands.txt')"`.

## How each change is identified and applied

The program looks at which ends of branch p-q are already in the matrix (bus 0 is
the reference):

| Situation | Type | New Z-bus |
|-----------|------|-----------|
| new bus p to reference         | 1 | `[Z 0; 0 Zb]` |
| new bus p to existing bus k    | 2 | `[Z Z(:,k); Z(k,:) Zkk+Zb]` |
| existing bus k to reference    | 3 | `Z - Z(:,k)Z(k,:)/(Zkk+Zb)` |
| existing bus j to existing bus k | 4 | `Z - (Zj-Zk)(Zj-Zk)ᵀ/(Zjj+Zkk-2Zjk+Zb)` |
| remove branch Zb               | 3/4 | the same formula with `-Zb` (a branch of `-Zb` in parallel cancels it) |
| change Zold to Znew            | 3/4 | add `Zx = Zold·Znew/(Zold-Znew)` in parallel |
| remove bus k                   | – | remove all its branches, then delete its row and column |

**Removing a radial branch.** If the branch was the only path to the reference for
some buses, the removal denominator becomes 0. The program detects this, finds the
isolated buses from the matrix itself (their entries in `Z(:,k)-Z(:,j)` equal ±Zb),
and deletes their rows and columns. This works even when you entered only the
matrix and not the branch data.

If you entered the matrix directly, you can also give the branch data (optional).
The program uses it to look up branch impedances by name and to check results
against `inv(Ybus)`. Without it, the program asks for the impedance when you
remove or change a branch.

Branches are assumed to have no mutual coupling.

## Self-test

```matlab
>> zbus_demo
```

This builds the example, applies every type of change and checks each result
against `inv(Ybus)`. It then runs 300 random changes on random 60-bus networks.

## Fault-analysis examples (separate from the portal)

```matlab
>> zbus_fault_examples
```

`zbus_fault_examples.m` works through the EE 315 fault-analysis examples from 9–23 Oct.
It solves each one with the Z-bus program and checks every answer against the slide
(90 checks).

| Example | Slides | How the Z-bus program is used | Slide answers checked |
|---------|--------|-------------------------------|-----------------------|
| A | 14 Oct, sequence components | – (sequence transformation only) | V0 = 27.03∠−79.32°, V1 = 85.68∠21.83°, V2 = 26.01∠−11.78° kV; balanced set; 10∠30° set |
| B | 13 Oct, Ex. 4 | Z-bus built line by line (types 1, 1, 2, 4 found automatically), then line 1–3 **removed** | final Z-bus to 6 decimals, P = 1.85, P = −0.033784, matrix after removal |
| C | 13 Oct, Ex. 5 | 4-bus Z-bus; three-phase fault on bus 4 using I_f = V_r/(Z_rr+Z_f) and V_i = V_i − Z_ir·I_f (9 Oct) | Z-bus, I_f = −j7.375, bus voltages, line currents |
| D | 13 Oct, Ex. 1 | radial network with **complex** impedances; Thevenin impedance = Z_FF | Z_th = 1.674 + j4.82, I_sc = 1715 A, 11 kV bus = 9.68 kV |
| E | 13 Oct, Ex. 2 | generator + 3 motors; breaker current by **removing** motor 3's branch; interrupting current by **changing** motor reactances X″d → X′d | −j4.22, −j3.42 pu (7479.5 A), 11967 A, 3.1515 pu (7581 A) |
| F | 13 Oct, Ex. 3 | loaded system: prefault current + pure-fault change from the Z-bus (superposition) | I″g = 0.6226 − j1.6746, I″m = −0.6226 − j6.8906, I_f = −j8.5653 pu (−j11,239 A) |
| G | 23 Oct (and 16 Oct formulas) | positive, negative and zero sequence Z-buses; LG fault on bus 2; generator currents and voltages from Z_ir | Z1 = j0.157, Z0 = j0.051, I_f = 8.22 pu (5392.9 A), Vb, Vc at F, G1 and G2 currents and voltages |

Notes on the slide values:
- **Rounding.** The slides round intermediate values, so each check uses a tolerance
  that matches the slide's rounding. For example, in G the slide rounds Z1 and Z0 to
  three decimals before dividing, and gets about 0.4 % more current than the exact
  calculation.
- **Example C line currents.** The rounded slide values I13 = j0.182 and I23 = −j0.177
  don't quite satisfy KCL at bus 3, which has no load. The exact values do: I13 = −I23 =
  j0.1806.
- **Example G, G1 current.** The slide prints Ib = 2.40∠270° for G1, but
  Ib = a²I1 + aI2 = −Ia = 2.40∠90°. The magnitudes agree.
- **LL and LLG faults.** Example G also applies the LL and LLG fault formulas from
  16 Oct at the same fault point. The slides give no answers for these, so the program
  checks their boundary conditions instead: Ia = 0, Ib = −Ic and Vb = Vc for LL;
  Vb = Vc = 0 for LLG.

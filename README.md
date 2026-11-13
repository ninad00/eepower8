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
| `zbus_stability_examples.m` | Lecture examples on stability and the equal area criterion, checked against the slides (separate from the portal) |
| `stability_examples_output.txt`, `eac_example_b.png`, `eac_example_c.png` | Output and plots of `zbus_stability_examples` (25 checks passed) |
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

## Stability examples (separate from the portal)

```matlab
>> zbus_stability_examples
```

`zbus_stability_examples.m` works through the EE 315 lecture examples from 27–30 Oct
(machine dynamics, swing equation, equal area criterion, problem practice). It checks
each result against the answer on the slide.

| Example | What is checked | Slide answer |
|---------|-----------------|--------------|
| A: 100 MVA, H = 8 turbogenerator   | stored energy, rotor acceleration | 800 MJ, 337.5 elect deg/s² |
| B: fault on one of two parallel lines (Problem practice, Ex. 1) | X_I, Pmax_I/II/III, δ0, δmax, δcr | 0.522 pu, 2.3 / 0 / 1.5, 25.8°, 2.41 rad, 55.8° |
| C: Pmax 2.0 / 0.5 / 1.5 pu (Problem practice, Ex. 2) | δ0, δmax, cos δcr, δcr | 0.523 rad, 2.41 rad, 0.337, 70.3° |

**How Example B uses the Z-bus program.** The prefault network is built from branch
data. The fault at P is a **Type 3** change with Zb = 0 (bus grounded through zero
impedance). Clearing the fault is the **removal** of the j0.4 line. For each network,
the program reduces the Z-bus to the generator EMF bus and the infinite bus and inverts
it. That gives the transfer reactance, and then Pmax = |E'||V|/X.

Example B also adds a j1.0 shunt at the generator bus and at the infinite bus, so that
a Z-bus exists at all. These shunts do not change the answer: shunts at the two buses
that are kept only change the diagonal of the reduced Ybus, and the transfer reactance
comes from the off-diagonal term.

**Swing-equation check.** Examples B and C also solve the swing equation numerically
(RK4) with H = 5 MJ/MVA. H is **assumed**, because the problems don't give it. The
checks are:
- clearing 1° before δcr is stable, and 1° after is unstable;
- the critical clearing time found by simulation matches the closed-form formula
  `t_cr = sqrt(2H(δcr-δ0)/(πf Pm))`, which applies when Pe = 0 during the fault;
- the rotor angle at that time equals the δcr from the equal area criterion.

The stable/unstable result for a given clearing angle does not depend on H. Only the
times do.

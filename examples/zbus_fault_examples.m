function zbus_fault_examples()
%ZBUS_FAULT_EXAMPLES  Worked examples from the fault-analysis lectures
%   (EE 315, 9-23 Oct: fault analysis using Z-bus, problem practice on fault
%   analysis, sequence components, asymmetrical faults, problem practice),
%   solved with the Z-bus program and checked against the answers on the slides.
%
%   This file is separate from the Z-bus portal; it only calls zbus_build /
%   zbus_modify / zbus_show / zbus_verify. Run:  >> zbus_fault_examples
%
%   Slide answers are rounded (often to 2-3 digits, sometimes from rounded
%   intermediate values), so each check uses a tolerance that matches the
%   rounding on the slide. Exact values are always printed as well.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));   % Z-bus engine
npass = 0; nfail = 0;
a = exp(2j * pi / 3);
A = [1 1 1; 1 a^2 a; 1 a a^2];          % [Va; Vb; Vc] = A * [V0; V1; V2]

% =====================================================================
hdr('Example A (14 Oct, Sequence components): symmetrical components');
% A1: Va = 110/_0, Vb = 88/_-100, Vc = 80/_175 kV
Vabc = [110; pd(88, -100); pd(80, 175)];
V012 = A \ Vabc;
fprintf('  Va = 110 /_ 0, Vb = 88 /_ -100, Vc = 80 /_ 175 kV  ->\n');
fprintf('     V0 = %s kV\n     V1 = %s kV\n     V2 = %s kV\n', pz(V012(1)), pz(V012(2)), pz(V012(3)));
check('|V0| = 27.03 kV', abs(V012(1)), 27.03, 0.01);   checkAng('angle V0 = -79.32 deg', V012(1), -79.32, 0.02);
check('|V1| = 85.68 kV', abs(V012(2)), 85.68, 0.01);   checkAng('angle V1 = 21.83 deg', V012(2), 21.83, 0.02);
check('|V2| = 26.01 kV', abs(V012(3)), 26.01, 0.01);   checkAng('angle V2 = -11.78 deg', V012(3), -11.78, 0.02);
% A2: balanced currents have only a positive sequence component
I012 = A \ [100; pd(100, -120); pd(100, 120)];
fprintf('  Balanced Ia = 100 /_ 0, Ib = 100 /_ -120, Ic = 100 /_ 120 A -> I0 = %.3g, I1 = %s, I2 = %.3g A\n', ...
    abs(I012(1)), pz(I012(2)), abs(I012(3)));
check('balanced set: I0 = 0, I1 = 100 /_ 0, I2 = 0', I012, [0; 100; 0], 1e-9);
% A3: I0 = I1 = I2 = 10 /_ 30 A
Iabc = A * pd(10, 30) * [1; 1; 1];
fprintf('  I0 = I1 = I2 = 10 /_ 30 A -> Ia = %s, Ib = %.3g, Ic = %.3g A\n', pz(Iabc(1)), abs(Iabc(2)), abs(Iabc(3)));
check('Ia = 30 /_ 30 A, Ib = Ic = 0', Iabc, [pd(30, 30); 0; 0], 1e-9);

% =====================================================================
hdr('Example B (13 Oct, Example 4): build Z-bus step by step, then remove line 1-3');
% Line data (p-q, Z):  R-1 0.6,  R-2 0.5,  2-3 0.5,  1-3 0.25   (R = reference = 0)
L = [0 1 0.6; 0 2 0.5; 2 3 0.5; 1 3 0.25];
S = struct('Z', zeros(0), 'bus', zeros(1, 0), 'br', zeros(0, 3), 'topo', true);
types = zeros(1, 4);
for k = 1:4
    if k == 4
        P = S.Z(1, 1) + S.Z(3, 3) - 2 * S.Z(1, 3) + 0.25;   % Type 4 denominator
        Zstep3 = S.Z;
    end
    [S, msg, types(k)] = zbus_modify(S, 'add', L(k, 1), L(k, 2), L(k, 3));
    fprintf('  Line %d: %s\n', k, msg);
end
zbus_show(Zstep3_struct(Zstep3), 1, '  Z-bus after step 3');
zbus_show(S, 1, '  Final Z-bus');
check('modification types found: 1, 1, 2, 4', types, [1 1 2 4], 0);
check('step-3 Z-bus = [0.6 0 0; 0 0.5 0.5; 0 0.5 1.0]', Zstep3, [0.6 0 0; 0 0.5 0.5; 0 0.5 1.0], 1e-12);
check('Type 4 denominator P = 1.85', P, 1.85, 1e-12);
Zbook = [0.405405 0.162162 0.324324; 0.162162 0.364865 0.229730; 0.324324 0.229730 0.459459];
check('final Z-bus = slide matrix (6 decimals)', S.Z, Zbook, 1e-6);
check('final Z-bus = inv(Ybus)', zbus_verify(S, true), true, 0);
Pr = S.Z(1, 1) + S.Z(3, 3) - 2 * S.Z(1, 3) - 0.25;
[S2, msg] = zbus_modify(S, 'remove', 1, 3);
fprintf('\n  Remove line 1-3: %s\n', msg);
zbus_show(S2, 1, '  Z-bus with line 1-3 removed');
check('removal denominator P = -0.033784', Pr, -0.033784, 1e-6);
check('after removal Z-bus = [0.6 0 0; 0 0.5 0.5; 0 0.5 1.0]', S2.Z, [0.6 0 0; 0 0.5 0.5; 0 0.5 1.0], 1e-9);

% =====================================================================
hdr('Example C (13 Oct, Example 5): three-phase fault on bus 4 of a 4-bus system');
% Generator X'd = 0.1 + transformer 0.05 = j0.15 at buses 1 and 2; lines as in the figure.
B = [1 0 0.15j; 2 0 0.15j; 1 2 0.2j; 1 3 0.15j; 1 4 0.1j; 2 3 0.1j; 2 4 0.15j];
S = zbus_build(B);
zbus_show(S, 1, '  Z-bus');
Zbook = 1j * [0.0903 0.0597 0.0719 0.0780; 0.0597 0.0903 0.0780 0.0719
              0.0719 0.0780 0.1356 0.0743; 0.0780 0.0719 0.0743 0.1356];
check('Z-bus = slide matrix (4 decimals)', S.Z, Zbook, 1e-4);
[If, Vf] = fault3(S, 4, 0, ones(4, 1));
fprintf('  I_f = V4/(Z44 + Zf) = %s pu\n', rect(If));
fprintf('  Bus voltages during the fault: V1 = %.4f, V2 = %.4f, V3 = %.4f, V4 = %.4f pu\n', abs(Vf));
check('I_f = -j7.37463 pu', If, -7.37463j, 0.005);
check('V1 = 0.4248 pu', Vf(1), 0.4248, 1e-3);
check('V2 = 0.4698 pu', Vf(2), 0.4698, 1e-3);
check('V3 = 0.4521 pu', Vf(3), 0.4521, 1e-3);
check('V4 = 0', Vf(4), 0, 1e-12);
% The slide divides differences of 4-decimal voltages by the line reactance,
% so each slide current carries up to ~0.0006/|z| of rounding error.
note('slide line currents use voltages rounded to 4 decimals; tolerance = 0.0006/|z|');
lines = {1 3 0.15j 0.182j; 1 2 0.2j 0.225j; 1 4 0.1j -4.248j; 2 4 0.15j -3.132j; 2 3 0.1j -0.177j};
Il = zeros(1, size(lines, 1));
for k = 1:size(lines, 1)
    [i, j, z, want] = lines{k, :};
    Il(k) = (Vf(i) - Vf(j)) / z;
    check(sprintf('line current I%d%d = %s pu', i, j, zfmt(want)), Il(k), want, 0.0006 / abs(z));
end
note('bus 3 has no load, so I13 + I23 = 0 exactly (the rounded slide values j0.182 and -j0.177 do not quite cancel)');
check('KCL at bus 3: I13 + I23 = 0', Il(1) + Il(5), 0, 1e-12);
check('KCL at bus 4: I14 + I24 = I_f', Il(3) + Il(4), If, 1e-12);

% =====================================================================
hdr('Example D (13 Oct, Example 1): radial network with complex impedances');
Sb = 100;                                           % MVA base
XG1 = 0.15 * Sb / 10; XG2 = 0.125 * Sb / 10;         % generators
XT1 = 0.10 * Sb / 10; XT2 = 0.08 * Sb / 5;           % transformers
Zline = 30 * (0.27 + 0.36j) * Sb / 33^2;             % 30 km overhead line, 33 kV
Zcab = 3 * (0.135 + 0.08j) * Sb / 6.6^2;             % 3 km cable, 6.6 kV
fprintf('  Per unit (100 MVA): G1 j%.3g, G2 j%.3g, T1 j%.3g, T2 j%.3g, line %s, cable %s\n', ...
    XG1, XG2, XT1, XT2, rect(Zline), rect(Zcab));
% buses: 1 = 11 kV bus, 2 = T1 HV, 3 = line end (33 kV), 4 = 6.6 kV bus, 5 = F
B = [1 0 1j*XG1; 1 0 1j*XG2; 1 2 1j*XT1; 2 3 Zline; 3 4 1j*XT2; 4 5 Zcab];
S = zbus_build(B);
Zth = S.Z(5, 5);
[If, Vf] = fault3(S, 5, 0, ones(5, 1));
Ibase = Sb * 1e6 / (sqrt(3) * 6.6e3);
fprintf('  Thevenin impedance at F = Z55 = %s = %s pu\n', rect(Zth), pz(Zth));
fprintf('  I_sc = %.4f pu = %.0f A;  11 kV bus voltage = %.4f pu = %.2f kV\n', ...
    abs(If), abs(If) * Ibase, abs(Vf(1)), abs(Vf(1)) * 11);
check('Z_th = 1.674 + j4.82 pu', Zth, 1.674 + 4.82j, 0.006);
check('|Z_th| = 5.1 pu', abs(Zth), 5.1, 0.01);
checkAng('angle Z_th = 70.8 deg', Zth, 70.8, 0.1);
check('I_sc = 0.196 pu', abs(If), 0.196, 5e-4);
check('I_sc = 1715 A', abs(If) * Ibase, 1715, 5);
check('11 kV bus voltage = 0.88 pu (slide rounds 0.875)', abs(Vf(1)), 0.88, 0.006);
check('11 kV bus voltage = 9.68 kV', abs(Vf(1)) * 11, 9.68, 0.06);

% =====================================================================
hdr('Example E (13 Oct, Example 2): generator feeding three motors, fault at F');
% 25 MVA base. Gen X''d 0.2; T1 0.1; line 0.15; T2 0.1; each motor X''d = 0.25*25/5
Xm2 = 0.25 * 25 / 5; Xm1 = 0.30 * 25 / 5;            % subtransient / transient
Ib66 = 25e6 / (sqrt(3) * 6.6e3);
% buses: 1 gen, 2 T1 HV (Q), 3 line end, 4 6.6 kV bus (P), 5 = F (motor 3 side of breaker B)
B = [1 0 0.2j; 1 2 0.1j; 2 3 0.15j; 3 4 0.1j; 4 0 1j*Xm2; 4 0 1j*Xm2; 4 5 0; 5 0 1j*Xm2];
[S, steps] = zbus_build(B);
fprintf('  %s\n', steps{:});
Ia = 1 / S.Z(5, 5);
fprintf('  (a) fault current            = %s pu = %.0f A\n', rect(Ia), abs(Ia) * Ib66);
check('(a) subtransient fault current = -j4.22 pu', Ia, -4.22j, 0.005);
% (b) breaker B carries everything except motor 3's own contribution:
%     remove motor 3's branch and fault F again.
[Sb2, msg] = zbus_modify(S, 'remove', 5, 0, 1j*Xm2);
fprintf('  (b) %s\n', msg);
Ibk = 1 / Sb2.Z(5, 5);
fprintf('      breaker current           = %s pu = %.1f A\n', rect(Ibk), abs(Ibk) * Ib66);
check('(b) breaker current = -j3.42 pu', Ibk, -3.42j, 0.005);
check('(b) breaker current = 7479.5 A', abs(Ibk) * Ib66, 7479.5, 6);
fprintf('  (c) momentary current = 1.6 x %.1f = %.0f A\n', abs(Ibk) * Ib66, 1.6 * abs(Ibk) * Ib66);
check('(c) momentary current = 11967 A', 1.6 * abs(Ibk) * Ib66, 11967, 10);
% (d) interrupting current: motors now behind their transient reactance
[Sd, m1] = zbus_modify(Sb2, 'change', 4, 0, 1j*Xm1, 1j*Xm2);
[Sd, m2] = zbus_modify(Sd, 'change', 4, 0, 1j*Xm1, 1j*Xm2);
fprintf('  (d) %s\n      %s\n', m1, m2);
Iint = abs(1 / Sd.Z(5, 5));
fprintf('      symmetrical current = %.4f pu;  x 1.1 (5 cycles) = %.0f A\n', Iint, 1.1 * Iint * Ib66);
check('(d) symmetrical current = 3.1515 pu', Iint, 3.1515, 5e-4);
check('(d) current to be interrupted = 7581 A', 1.1 * Iint * Ib66, 7581, 3);

% =====================================================================
hdr('Example F (13 Oct, Example 3): fault on a loaded system (superposition)');
% 25 MVA, 11 kV base. Gen and motor X''d = 0.15; T1, line, T2 = 0.1 each.
% Motor draws 15 MW at 0.8 pf leading at 10.6 kV when a fault occurs at its terminals.
B = [1 0 0.15j; 1 2 0.1j; 2 3 0.1j; 3 4 0.1j; 4 0 0.15j];
S = zbus_build(B);
V0 = 10.6 / 11;                                      % prefault voltage at F (bus 4)
I0 = (15 / 25) / (V0 * 0.8) * exp(1j * acos(0.8));  % prefault current gen -> motor
If = V0 / S.Z(4, 4);                                 % Step 3: pure-fault network
dV = -S.Z(:, 4) * If;                                % change in bus voltages
Ig = I0 + (-dV(1)) / 0.15j;                          % Step 4: prefault + change
Im = -I0 + (-dV(4)) / 0.15j;
Ib11 = 25e6 / (sqrt(3) * 11e3);
fprintf('  V0 = %.4f pu, prefault I0 = %s pu\n', V0, rect(I0));
fprintf('  I_f = %s pu,  I''''g = %s pu,  I''''m = %s pu\n', rect(If), rect(Ig), rect(Im));
fprintf('  In amperes: I''''g = %s A, I''''m = %s A, I_f = %s A\n', rect(Ig * Ib11, 1), rect(Im * Ib11, 1), rect(If * Ib11, 1));
check('generator current = 0.6226 - j1.6746 pu', Ig, 0.6226 - 1.6746j, 1e-3);
check('motor current = -0.6226 - j6.8906 pu', Im, -0.6226 - 6.8906j, 1e-3);
check('fault current = -j8.5653 pu', If, -8.5653j, 1e-3);
check('I_f = I''''g + I''''m', If, Ig + Im, 1e-12);
check('fault current = -j11,239 A', If * Ib11, -11239j, 2);

% =====================================================================
hdr('Example G (23 Oct): single line-to-ground fault on bus 2 (sequence Z-buses)');
% 250 MVA base. G1 0.25/0.25/0.05, G2 0.2/0.2/0.05 with Xn = 0.03, T1 (delta-Yg) 0.06,
% T2 (Yg-Yg) 0.07, two lines 0.1/0.1/0.3 each.
% Buses: 1 = G1 terminal, 2 = T1 HV (fault F), 3 = T2 HV, 4 = G2 terminal.
B1 = [1 0 0.25j; 1 2 0.06j; 2 3 0.1j; 2 3 0.1j; 3 4 0.07j; 4 0 0.2j];   % positive (= negative)
B0 = [1 0 0.05j; 2 0 0.06j; 2 3 0.3j; 2 3 0.3j; 3 4 0.07j; 4 0 (0.05 + 3*0.03)*1j];
% zero sequence: T1's delta isolates G1 (bus 1 only sees G1), T1 Yg side grounds bus 2
% through j0.06, G2 is grounded through 3Xn = j0.09.
S1 = zbus_build(B1); S2 = S1; S0 = zbus_build(B0);
zbus_show(S1, 1, '  Positive (and negative) sequence Z-bus');
zbus_show(S0, 1, '  Zero sequence Z-bus');
r = 2;
Z1 = S1.Z(r, r); Z2 = S2.Z(r, r); Z0 = S0.Z(r, r);
fprintf('  Thevenin impedances at F: Z1 = Z2 = %s, Z0 = %s pu\n', rect(Z1), rect(Z0));
check('Z1 = Z2 = j0.157 pu', Z1, 0.157j, 6e-4);
check('Z0 = j0.051 pu', Z0, 0.051j, 5e-4);

% (a) fault current
Ia1 = 1 / (Z1 + Z2 + Z0);  Is = [Ia1; Ia1; Ia1];      % [I0; I1; I2]
IF = A * Is;
IbHV = 250e6 / (sqrt(3) * 220e3); IbLV = 250e6 / (sqrt(3) * 11e3);
fprintf('  (a) Ia0 = Ia1 = Ia2 = %s pu;  Ia = %s pu = %.1f A;  Ib = %.2g, Ic = %.2g\n', ...
    rect(Ia1), rect(IF(1)), abs(IF(1)) * IbHV, abs(IF(2)), abs(IF(3)));
note('the slide rounds Z1, Z2, Z0 to j0.157, j0.157, j0.051 first; the exact values give ~0.4% less current');
checkRel('(a) Ia1 = -j2.74 pu', Ia1, -2.74j, 0.005);
checkRel('(a) fault current Ia = -j8.22 pu', IF(1), -8.22j, 0.005);
checkRel('(a) fault current = 5392.9 A', abs(IF(1)) * IbHV, 5392.9, 0.005);
check('(a) Ib = Ic = 0', IF(2:3), [0; 0], 1e-12);

% (b) voltages at the fault point
VsF = [0; 1; 0] - [Z0; Z1; Z2] .* Is;               % [Va0; Va1; Va2]
VF = A * VsF;
fprintf('  (b) Va1 = %.4f, Va2 = %.4f, Va0 = %.4f pu\n', real(VsF(2)), real(VsF(3)), real(VsF(1)));
fprintf('      Va = %.2g, Vb = %s, Vc = %s pu;  |Vb| = %.2f kV\n', abs(VF(1)), pz(VF(2)), pz(VF(3)), abs(VF(2)) * 220 / sqrt(3));
check('(b) Va1 = 0.57 pu', VsF(2), 0.57, 0.005);
check('(b) Va2 = -0.43 pu', VsF(3), -0.43, 0.005);
check('(b) Va0 = -0.14 pu', VsF(1), -0.14, 0.005);
check('(b) Va = 0 at the fault', VF(1), 0, 1e-12);
check('(b) |Vb| = |Vc| = 0.891 pu', abs(VF(2:3)), [0.891; 0.891], 0.003);
checkAng('(b) angle Vb = 256.37 deg', VF(2), 256.37, 0.4);
checkAng('(b) angle Vc = 103.63 deg', VF(3), 103.63, 0.4);
check('(b) |Vb| = 113.18 kV', abs(VF(2)) * 220 / sqrt(3), 113.18, 0.4);

% (c) generator G2 (bus 4): bus voltages from the sequence Z-buses, then branch currents
k = 4;
V4 = [0; 1; 0] - [S0.Z(k, r); S1.Z(k, r); S2.Z(k, r)] .* Is;
I2s = [-V4(1) / 0.14j; (1 - V4(2)) / 0.2j; -V4(3) / 0.2j];   % G2 -> bus 4
I2p = A * I2s;  V2p = A * V4;
fprintf('  (c) G2: I0 = %s, I1 = %s, I2 = %s pu\n', rect(I2s(1)), rect(I2s(2)), rect(I2s(3)));
fprintf('      Ia = %s, Ib = %s, Ic = %s pu  (Ia = %.0f A)\n', pz(I2p(1)), pz(I2p(2)), pz(I2p(3)), abs(I2p(1)) * IbLV);
fprintf('      Va = %s, Vb = %s, Vc = %s pu  (%.2f, %.2f, %.2f kV)\n', pz(V2p(1)), pz(V2p(2)), pz(V2p(3)), abs(V2p) * 11 / sqrt(3));
checkRel('(c) G2 Ia1 = Ia2 = -j1.35 pu', I2s(2), -1.35j, 0.01);
checkRel('(c) G2 Ia0 = -j0.39 pu', I2s(1), -0.39j, 0.01);
checkRel('(c) G2 |Ia| = 3.09 pu', abs(I2p(1)), 3.09, 0.01);
checkAng('(c) G2 angle Ia = 270 deg', I2p(1), 270, 0.01);
checkRel('(c) G2 |Ib| = |Ic| = 0.96 pu', abs(I2p(2:3)), [0.96; 0.96], 0.01);
checkAng('(c) G2 angle Ib = 90 deg', I2p(2), 90, 0.01);
checkRel('(c) G2 Ia = 40545.73 A', abs(I2p(1)) * IbLV, 40545.73, 0.01);
check('(c) G2 Va0 = -0.0546 pu', V4(1), -0.0546, 5e-4);
check('(c) G2 |Va| = 0.405 pu', abs(V2p(1)), 0.405, 0.005);
check('(c) G2 |Vb| = |Vc| = 0.91 pu', abs(V2p(2:3)), [0.91; 0.91], 0.005);
check('(c) G2 Va = 2.57 kV, Vb = Vc = 5.78 kV', abs(V2p) * 11 / sqrt(3), [2.57; 5.78; 5.78], 0.03);

% (c) generator G1 (bus 1), behind the delta-star transformer T1
k = 1;
V1s = [0; 1; 0] - [S0.Z(k, r); S1.Z(k, r); S2.Z(k, r)] .* Is;   % HV-referred
I1s = [0; (1 - V1s(2)) / 0.25j; -V1s(3) / 0.25j];                % G1 -> bus 1
sh = [1; exp(-1j*pi/6); exp(1j*pi/6)];        % delta-star shift: +seq -30 deg, -seq +30 deg
I1p = A * (sh .* I1s);  V1p = A * (sh .* V1s);
fprintf('  (c) G1: I1 = %s, I2 = %s pu (after the 30 deg shift), I0 = 0\n', pz(sh(2)*I1s(2)), pz(sh(3)*I1s(3)));
fprintf('      Ia = %s, Ib = %s, Ic = %.2g pu  (Ia = %.0f A)\n', pz(I1p(1)), pz(I1p(2)), abs(I1p(3)), abs(I1p(1)) * IbLV);
fprintf('      Va = %s, Vb = %s, Vc = %s pu  (%.2f, %.2f, %.2f kV)\n', pz(V1p(1)), pz(V1p(2)), pz(V1p(3)), abs(V1p) * 11 / sqrt(3));
note('the slide prints Ib = 2.40 /_ 270 for G1, but Ib = a^2 I1 + a I2 = -Ia = 2.40 /_ 90 (sign slip on the slide); magnitudes agree');
checkRel('(c) G1 Ia1 = -j1.39 pu (before shift)', I1s(2), -1.39j, 0.01);
checkAng('(c) G1 Ia1 angle 240 deg after shift', sh(2) * I1s(2), 240, 0.01);
checkAng('(c) G1 Ia2 angle 300 deg after shift', sh(3) * I1s(3), 300, 0.01);
checkRel('(c) G1 |Ia| = |Ib| = 2.40 pu', abs(I1p(1:2)), [2.40; 2.40], 0.01);
checkAng('(c) G1 angle Ia = 270 deg', I1p(1), 270, 0.01);
check('(c) G1 Ic = 0', I1p(3), 0, 1e-12);
checkRel('(c) G1 Ia = 31491.81 A', abs(I1p(1)) * IbLV, 31491.81, 0.01);
check('(c) G1 Va1 = 0.6525 pu', V1s(2), 0.6525, 0.002);
check('(c) G1 Va2 = -0.3475 pu', V1s(3), -0.3475, 0.002);
check('(c) G1 |Va| = |Vb| = 0.566 pu, |Vc| = 1.0 pu', abs(V1p), [0.566; 0.566; 1.0], 0.003);
checkAng('(c) G1 angle Va = 298 deg', V1p(1), 298, 0.5);
checkAng('(c) G1 angle Vb = 242 deg', V1p(2), 242, 0.5);
checkAng('(c) G1 angle Vc = 90 deg', V1p(3), 90, 0.5);
check('(c) G1 Va = Vb = 3.59 kV, Vc = 6.35 kV', abs(V1p) * 11 / sqrt(3), [3.59; 3.59; 6.35], 0.02);

% Other fault types at the same point (16 Oct formulas; no slide answers, so the
% boundary conditions of each fault are checked instead).
fprintf('\n  Same fault point, other fault types (16 Oct formulas, Zf = 0):\n');
I1 = 1 / (Z1 + Z2);  Ill = A * [0; I1; -I1];  Vll = A * ([0; 1; 0] - [Z0; Z1; Z2] .* [0; I1; -I1]);
fprintf('     LL  (b-c): Ib = %s pu, Ic = %s pu\n', pz(Ill(2)), pz(Ill(3)));
check('LL: Ia = 0 and Ib = -Ic', [Ill(1); Ill(2) + Ill(3)], [0; 0], 1e-12);
check('LL: Ib = -j*sqrt(3)*E/(Z1+Z2)', Ill(2), -1j * sqrt(3) / (Z1 + Z2), 1e-12);
check('LL: Vb = Vc at the fault', Vll(2), Vll(3), 1e-12);
I1 = 1 / (Z1 + Z2 * Z0 / (Z2 + Z0));
Is3 = [-I1 * Z2 / (Z2 + Z0); I1; -I1 * Z0 / (Z2 + Z0)];
Illg = A * Is3;  Vllg = A * ([0; 1; 0] - [Z0; Z1; Z2] .* Is3);
fprintf('     LLG (b-c-g): Ib = %s, Ic = %s, ground current 3I0 = %s pu\n', pz(Illg(2)), pz(Illg(3)), pz(3 * Is3(1)));
check('LLG: Ia = 0', Illg(1), 0, 1e-12);
check('LLG: Vb = Vc = 0 at the fault', Vllg(2:3), [0; 0], 1e-12);
I3 = 1 / Z1;
fprintf('     LLL: I_f = %s pu = %.0f A\n', rect(I3), abs(I3) * IbHV);

% =====================================================================
fprintf('\n==== %d checks passed, %d failed ====\n', npass, nfail);

    % ------------------------------------------------------------------
    function check(name, got, want, tol)
        ok = isequal(size(got), size(want)) && all(abs(double(got(:)) - double(want(:))) <= tol);
        report(name, ok, got, want);
    end

    function checkRel(name, got, want, rtol)
        ok = all(abs(got(:) - want(:)) <= rtol * abs(want(:)));
        report(name, ok, got, want);
    end

    function checkAng(name, z, wantDeg, tol)
        d = mod(rad2deg(angle(z)) - wantDeg + 180, 360) - 180;
        report(name, abs(d) <= tol, mod(rad2deg(angle(z)), 360), mod(wantDeg, 360));
    end

    function report(name, ok, got, want)
        if ok
            npass = npass + 1; fprintf('     [PASS] %s', name);
        else
            nfail = nfail + 1; fprintf('     [FAIL] %s', name);
        end
        if isscalar(got) && isnumeric(got) && ~islogical(got)
            fprintf('   (got %s)', val(got));
        end
        fprintf('\n');
        if ~ok && isscalar(want) && isnumeric(want), fprintf('            expected %s\n', val(want)); end
    end
end

% =====================================================================
function [If, Vf] = fault3(S, r, Zf, V0)
% Three-phase fault on bus r through Zf (9 Oct slides):
%   I_f = V_r0 / (Z_rr + Zf),   V_i = V_i0 - Z_ir * I_f
i = find(S.bus == r, 1);
If = V0(i) / (S.Z(i, i) + Zf);
Vf = V0(:) - S.Z(:, i) * If;
end

function T = Zstep3_struct(Z)
T = struct('Z', Z, 'bus', 1:size(Z, 1), 'br', zeros(0, 3), 'topo', false);
end

function z = pd(m, deg)
z = m * exp(1j * deg * pi / 180);
end

function s = pz(z)
s = sprintf('%.4f /_ %.2f deg', abs(z), mod(rad2deg(angle(z)), 360));
end

function s = rect(z, nd)
if nargin < 2, nd = 4; end
s = sprintf(sprintf('%%.%df %%+.%dfj', nd, nd), real(z), imag(z));
end

function s = val(v)
if isreal(v) || abs(imag(v)) < 1e-12 * max(1, abs(v))
    s = sprintf('%.6g', real(v));
else
    s = rect(v, 5);
end
end

function hdr(t)
fprintf('\n=== %s ===\n', t);
end

function note(t)
fprintf('     note: %s\n', t);
end

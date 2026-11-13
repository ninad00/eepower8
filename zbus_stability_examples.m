function zbus_stability_examples(makePlots)
%ZBUS_STABILITY_EXAMPLES  Worked examples from the stability lectures (EE 315,
%   27-30 Oct: machine dynamics, swing equation, equal area criterion,
%   problem practice), checked against the answers on the slides.
%
%   This file is separate from the Z-bus portal. It shows the Z-bus program
%   applied to a stability study:
%     prefault network  -> Z-bus built from branch data
%     fault at point P  -> Type 3 modification with Zb = 0 (bolted fault)
%     fault cleared     -> branch removal (the faulted line is opened)
%   The transfer reactance between the generator EMF E' and the infinite bus,
%   and so Pmax = |E'||V|/X, is read from the Z-bus of each network. The
%   equal area criterion and a numerical solution of the swing equation are
%   then used to find the critical clearing angle and time.
%
%   Run:  >> zbus_stability_examples          (plots when MATLAB has a desktop)
%         >> zbus_stability_examples(false)   (text only)

if nargin < 1, makePlots = usejava('desktop'); end
npass = 0; nfail = 0;
f = 50;            % Hz
Haux = 5;          % MJ/MVA, ASSUMED where a problem gives no H (see notes)

% =====================================================================
fprintf('\n=== Example A (28 Oct, slide 5): stored energy and rotor acceleration ===\n');
% 50 Hz, 4-pole, 100 MVA, 11 kV turbogenerator, H = 8 MJ/MVA.
% Mechanical input suddenly raised to 80 MW for an electrical load of 50 MW.
G = 100; H = 8; Pm = 80; Pe = 50;
KE = G * H;                          % stored energy, MJ
M = G * H / (180 * f);               % MJ-s/elect deg
alpha = (Pm - Pe) / M;               % elect deg/s^2
fprintf('  Stored energy  GH = %g MJ\n', KE);
fprintf('  M = GH/(180f) = %.5f MJ-s/elect deg\n', M);
fprintf('  Acceleration = (Pm - Pe)/M = %.2f elect deg/s^2  (= %.3f elect rad/s^2)\n', ...
    alpha, alpha * pi / 180);
check('stored energy = 800 MJ', KE, 800, 1e-9);
check('acceleration = 337.5 elect deg/s^2', alpha, 337.5, 1e-9);

% =====================================================================
fprintf('\n=== Example B (30 Oct, Example 1): fault on one of two parallel lines ===\n');
% E'=1.2 -- j0.25 -- bus 2 ==(j0.5 and j0.4 in parallel)== bus 3 -- j0.05 -- V=1
% The fault P is on the j0.4 line at the breaker-2 end (bus 3).
% Breakers 1 and 2 open together to clear it. Pm = 1.0 pu.
E = 1.2; V = 1.0; Pm = 1.0;
fprintf(['  Buses: 1 = generator EMF node (E''), 2 = generator terminal, 3 = receiving bus (P),\n' ...
    '         4 = infinite bus.  Bus 0 = neutral (reference).\n' ...
    '  Two auxiliary shunts (1-0 and 4-0, j1.0) give the network a path to the reference so\n' ...
    '  the Z-bus exists.  Shunts at the two retained buses only change the diagonal of the\n' ...
    '  reduced Ybus, so the transfer reactance between buses 1 and 4 is not affected.\n']);
B = [1 2 0.25j
     2 3 0.50j
     2 3 0.40j      % faulted line
     3 4 0.05j
     1 0 1.00j      % auxiliary shunt (any value)
     4 0 1.00j];    % auxiliary shunt (any value)

[Spre, steps] = zbus_build(B);
fprintf('\n  I. Prefault network\n');
fprintf('     %s\n', steps{:});
zbus_show(Spre, 1, '  Prefault Z-bus');
check('prefault Z-bus = inv(Ybus)', zbus_verify(Spre, true), true, 0);

[Sflt, msg] = zbus_modify(Spre, 'add', 3, 0, 0);
fprintf('\n  II. During fault:  %s\n', msg);
zbus_show(Sflt, 1, '  Z-bus during the fault');

[Spost, msg] = zbus_modify(Spre, 'remove', 2, 3, 0.4j);
fprintf('\n  III. Postfault:  %s\n', msg);
zbus_show(Spost, 1, '  Postfault Z-bus');
check('postfault Z-bus = inv(Ybus)', zbus_verify(Spost, true), true, 0);

XI = transfer_x(Spre, 1, 4);
XII = transfer_x(Sflt, 1, 4);
XIII = transfer_x(Spost, 1, 4);
PmaxI = E * V / XI;  PmaxII = E * V / XII;  PmaxIII = E * V / XIII;
fprintf('\n  Transfer reactance and maximum power (from the Z-bus of each network):\n');
fprintf('     prefault   X_I   = %-8.4f  Pmax_I   = %.4f pu\n', XI, PmaxI);
fprintf('     fault      X_II  = %-8.4g  Pmax_II  = %.4f pu   (bus 3 grounded: no transfer)\n', XII, PmaxII);
fprintf('     postfault  X_III = %-8.4f  Pmax_III = %.4f pu\n', XIII, PmaxIII);
check('X_I = 0.522 pu', XI, 0.522, 5e-4);
check('Pe_I = 2.3 sin(delta)', PmaxI, 2.3, 5e-3);
check('Pe_II = 0 (no power during fault)', PmaxII, 0, 1e-9);
check('X_III = 0.8 pu', XIII, 0.8, 1e-9);
check('Pe_III = 1.5 sin(delta)', PmaxIII, 1.5, 1e-9);

[d0, dmax, dcr] = eac(Pm, PmaxI, PmaxII, PmaxIII);
fprintf('\n  Equal area criterion:\n');
fprintf('     delta_0   = asin(Pm/Pmax_I)          = %6.2f deg (%.3f rad)\n', rad2deg(d0), d0);
fprintf('     delta_max = pi - asin(Pm/Pmax_III)   = %6.2f deg (%.3f rad)\n', rad2deg(dmax), dmax);
fprintf('     delta_cr  (A1 = A2)                  = %6.2f deg (%.3f rad)\n', rad2deg(dcr), dcr);
check('delta_0 = 25.8 deg', rad2deg(d0), 25.8, 0.05);
check('delta_max = 2.41 rad', dmax, 2.41, 0.005);
check('delta_cr = 55.8 deg', rad2deg(dcr), 55.8, 0.05);
[A1, A2] = areas(Pm, PmaxII, PmaxIII, d0, dcr, dmax);
fprintf('     A1 = %.4f,  A2 = %.4f  (equal at the critical clearing angle)\n', A1, A2);
check('A1 = A2 at delta_cr', A1, A2, 1e-9);

% Critical clearing time: Pe = 0 during the fault, so the closed form applies.
tcr = sqrt(2 * Haux * (dcr - d0) / (pi * f * Pm));
fprintf(['\n  Critical clearing time (28 Oct, slide 17), H = %g MJ/MVA assumed (not given):\n' ...
    '     t_cr = sqrt(2H(delta_cr - delta_0)/(pi f Pm)) = %.4f s\n'], Haux, tcr);

fprintf('\n  Check by solving the swing equation numerically (RK4):\n');
swing_checks('B', Pm, PmaxII, PmaxIII, d0, dcr, tcr);

% =====================================================================
fprintf('\n=== Example C (30 Oct, Example 2): fault that does not cut off all power ===\n');
% Pm = 1 pu; Pmax = 2.0 before the fault, 0.5 during it, 1.5 after clearing.
Pm2 = 1.0; P1 = 2.0; P2 = 0.5; P3 = 1.5;
[d0c, dmaxc, dcrc] = eac(Pm2, P1, P2, P3);
cosdcr = cos(dcrc);
fprintf('     delta_0   = %6.2f deg (%.3f rad)\n', rad2deg(d0c), d0c);
fprintf('     delta_max = %6.2f deg (%.3f rad)\n', rad2deg(dmaxc), dmaxc);
fprintf('     cos(delta_cr) = %.4f  ->  delta_cr = %.2f deg\n', cosdcr, rad2deg(dcrc));
check('delta_0 = asin(1/2) = 30 deg = pi/6 (slide truncates to 0.523 rad)', d0c, pi/6, 1e-12);
check('delta_max = 2.41 rad', dmaxc, 2.41, 0.005);
check('cos(delta_cr) = 0.337', cosdcr, 0.337, 5e-4);
check('delta_cr = 70.3 deg', rad2deg(dcrc), 70.3, 0.05);
[A1, A2] = areas(Pm2, P2, P3, d0c, dcrc, dmaxc);
fprintf('     A1 = %.4f,  A2 = %.4f\n', A1, A2);
check('A1 = A2 at delta_cr', A1, A2, 1e-9);
fprintf(['\n  Pe is not zero during this fault, so there is no closed form for t_cr\n' ...
    '  (28 Oct, slide 17). It is found numerically from the swing equation,\n' ...
    '  with H = %g MJ/MVA assumed:\n'], Haux);
swing_checks('C', Pm2, P2, P3, d0c, dcrc, []);

% =====================================================================
fprintf('\n==== %d checks passed, %d failed ====\n', npass, nfail);

if makePlots
    plot_case('Example B: fault on one of two parallel lines', ...
        Pm, PmaxI, PmaxII, PmaxIII, d0, dcr, dmax);
    plot_case('Example C: Pmax 2.0 / 0.5 / 1.5 pu', ...
        Pm2, P1, P2, P3, d0c, dcrc, dmaxc);
end

    % -----------------------------------------------------------------
    function swing_checks(name, Pm, P2, P3, d0, dcr, tcrFormula)
        margin = deg2rad(1);
        s1 = swing(Pm, P2, P3, d0, Haux, f, 'angle', dcr - margin);
        s2 = swing(Pm, P2, P3, d0, Haux, f, 'angle', dcr + margin);
        fprintf('     cleared at delta_cr - 1 deg: %s (peak angle %.1f deg)\n', verdict(s1), rad2deg(s1.peak));
        fprintf('     cleared at delta_cr + 1 deg: %s\n', verdict(s2));
        check(sprintf('%s: clearing 1 deg before delta_cr is stable', name), s1.stable, true, 0);
        check(sprintf('%s: clearing 1 deg after delta_cr is unstable', name), s2.stable, false, 0);

        tnum = critical_time(Pm, P2, P3, d0, Haux, f);
        sT = swing(Pm, P2, P3, d0, Haux, f, 'time', tnum);
        dAtT = sT.dclear;
        fprintf('     critical clearing time from the simulation: t_cr = %.4f s\n', tnum);
        fprintf('     rotor angle at that time: %.2f deg  (EAC delta_cr = %.2f deg)\n', ...
            rad2deg(dAtT), rad2deg(dcr));
        check(sprintf('%s: angle at simulated t_cr = EAC delta_cr', name), rad2deg(dAtT), rad2deg(dcr), 0.1);
        if ~isempty(tcrFormula)
            check(sprintf('%s: simulated t_cr = closed-form t_cr', name), tnum, tcrFormula, 5e-4);
        end
    end

    function check(name, got, want, tol)
        if islogical(want) || isempty(got)
            ok = isequal(logical(got), want);
        else
            ok = abs(got - want) <= tol;
        end
        if ok
            npass = npass + 1; fprintf('     [PASS] %s\n', name);
        else
            nfail = nfail + 1; fprintf('     [FAIL] %s  (got %.6g, expected %.6g)\n', name, got, want);
        end
    end
end

% =====================================================================
function X = transfer_x(S, a, b)
% Transfer reactance between buses a and b: reduce the Z-bus to these two
% buses, invert to get the reduced Ybus; X = -1/Y_ab (Inf if no transfer).
i = [find(S.bus == a, 1), find(S.bus == b, 1)];
Yr = inv(S.Z(i, i));
yab = Yr(1, 2);
if abs(yab) < 1e-12
    X = Inf;
else
    X = abs(-1 / yab);
end
end

function [d0, dmax, dcr] = eac(Pm, PmaxI, PmaxII, PmaxIII)
% Equal area criterion: initial angle, maximum permissible angle and
% critical clearing angle (30 Oct, Example 2 formula; PmaxII may be 0).
d0 = asin(Pm / PmaxI);
dmax = pi - asin(Pm / PmaxIII);
c = (Pm * (dmax - d0) - PmaxII * cos(d0) + PmaxIII * cos(dmax)) / (PmaxIII - PmaxII);
dcr = acos(c);
end

function [A1, A2] = areas(Pm, PmaxII, PmaxIII, d0, dc, dmax)
% Accelerating area A1 (during the fault) and decelerating area A2 (after it)
A1 = Pm * (dc - d0) + PmaxII * (cos(dc) - cos(d0));
A2 = PmaxIII * (cos(dc) - cos(dmax)) - Pm * (dmax - dc);
end

function r = swing(Pm, P2, P3, d0, H, f, clearBy, clearAt)
% Swing equation (H/(pi f)) d2delta/dt2 = Pm - Pmax sin(delta), solved with RK4.
% Pmax = P2 until the fault is cleared (at an angle or a time), then P3.
% Unstable if delta passes pi within 3 s.
M = H / (pi * f);
dt = 1e-4; tEnd = 3;
d = d0; w = 0; t = 0; cleared = false;
r.dclear = NaN; r.peak = d0; r.stable = true;
r.t = zeros(1, 0); r.d = zeros(1, 0);
while t < tEnd
    if ~cleared && ((strcmp(clearBy, 'angle') && d >= clearAt) || ...
                    (strcmp(clearBy, 'time') && t >= clearAt - 1e-12))
        cleared = true; r.dclear = d;
    end
    if cleared, Pmax = P3; else, Pmax = P2; end
    k1d = w;               k1w = (Pm - Pmax * sin(d)) / M;
    k2d = w + dt/2 * k1w;  k2w = (Pm - Pmax * sin(d + dt/2 * k1d)) / M;
    k3d = w + dt/2 * k2w;  k3w = (Pm - Pmax * sin(d + dt/2 * k2d)) / M;
    k4d = w + dt * k3w;    k4w = (Pm - Pmax * sin(d + dt * k3d)) / M;
    d = d + dt/6 * (k1d + 2*k2d + 2*k3d + k4d);
    w = w + dt/6 * (k1w + 2*k2w + 2*k3w + k4w);
    t = t + dt;
    r.peak = max(r.peak, d);
    if mod(round(t / dt), 10) == 0, r.t(end+1) = t; r.d(end+1) = d; end
    if d > pi, r.stable = false; break; end
end
end

function tcr = critical_time(Pm, P2, P3, d0, H, f)
% Longest clearing time that keeps the machine in step (bisection).
lo = 0; hi = 1;
for k = 1:30
    mid = (lo + hi) / 2;
    r = swing(Pm, P2, P3, d0, H, f, 'time', mid);
    if r.stable, lo = mid; else, hi = mid; end
end
tcr = lo;
end

function s = verdict(r)
if r.stable, s = 'STABLE'; else, s = 'UNSTABLE (loses synchronism)'; end
end

function plot_case(ttl, Pm, P1, P2, P3, d0, dcr, dmax)
fig = figure('Name', ttl, 'Color', 'w');
try, theme(fig, 'light'); catch, end   % newer MATLAB may default to a dark theme
x = linspace(0, pi, 400);
subplot(1, 2, 1); hold on; box on;
dA = linspace(d0, dcr, 100);
fill([dA fliplr(dA)], [P2 * sin(dA), Pm * ones(size(dA))], [1 .8 .8], 'EdgeColor', 'none');
dB = linspace(dcr, dmax, 100);
fill([dB fliplr(dB)], [P3 * sin(dB), Pm * ones(size(dB))], [.8 .9 1], 'EdgeColor', 'none');
plot(x, P1 * sin(x), 'k', 'LineWidth', 1.5);
plot(x, P2 * sin(x), 'r', 'LineWidth', 1.2);
plot(x, P3 * sin(x), 'b', 'LineWidth', 1.5);
plot([0 pi], [Pm Pm], 'k--');
xline(d0, ':'); xline(dcr, ':'); xline(dmax, ':');
text(d0, -0.08 * P1, '\delta_0', 'HorizontalAlignment', 'center');
text(dcr, -0.08 * P1, '\delta_{cr}', 'HorizontalAlignment', 'center');
text(dmax, -0.08 * P1, '\delta_{max}', 'HorizontalAlignment', 'center');
legend({'A_1', 'A_2', 'prefault P_{eI}', 'during fault P_{eII}', 'postfault P_{eIII}', 'P_m'}, ...
    'Location', 'northeast');
xlabel('\delta (rad)'); ylabel('P_e (pu)'); xlim([0 pi]); ylim([-0.15 * P1, 1.1 * P1]);
title(sprintf('Equal areas: \\delta_{cr} = %.1f^\\circ', rad2deg(dcr)));

subplot(1, 2, 2); hold on; box on;
a = swing(Pm, P2, P3, d0, 5, 50, 'angle', dcr - deg2rad(5));
b = swing(Pm, P2, P3, d0, 5, 50, 'angle', dcr + deg2rad(5));
plot(a.t, rad2deg(a.d), 'b', 'LineWidth', 1.5);
plot(b.t, rad2deg(b.d), 'r', 'LineWidth', 1.5);
yline(rad2deg(dmax), ':');
legend({'cleared at \delta_{cr} - 5^\circ (stable)', 'cleared at \delta_{cr} + 5^\circ (unstable)', ...
    '\delta_{max}'}, 'Location', 'northwest');
xlabel('t (s)'); ylabel('\delta (deg)'); ylim([10 * floor(min(rad2deg(a.d)) / 10) - 10, 200]);
title('Swing curves (H = 5 MJ/MVA assumed)');
sgtitle(ttl);
set(fig, 'Position', [100 100 1100 420]);
end

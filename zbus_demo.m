function zbus_demo()
%ZBUS_DEMO  Non-interactive demonstration and self-test of the Z-bus program.
%   Every modification is checked against inv(Ybus) of the modified network.
%   Run:  >> zbus_demo
npass = 0; nfail = 0;

fprintf('\n=== 1. Build the Z-bus of a 4-bus system from branch data ===\n');
B = [0 1 0.20j; 0 4 0.25j; 1 2 0.10j; 1 3 0.15j; 2 3 0.20j; 3 4 0.10j; 2 4 0.25j];
[S, steps] = zbus_build(B);
fprintf('  %s\n', steps{:});
zbus_show(S);
check('built Z-bus = inv(Ybus)', S);

fprintf('\n=== 2. Each type of modification ===\n');
S = step(S, 'add', 5, 0, 0.30j);            % Type 1
S = step(S, 'add', 6, 5, 0.10j);            % Type 2
S = step(S, 'add', 6, 0, 0.40j);            % Type 3
S4 = S;
S = step(S, 'add', 2, 6, 0.20j);            % Type 4
S = step(S, 'remove', 2, 6);                % removal of a mesh branch
same('removing 2-6 restores previous Z-bus', S.Z, S4.Z);
S = step(S, 'change', 1, 2, 0.05j);         % impedance change
S = step(S, 'add', 7, 3, 0.10j);
S = step(S, 'remove', 3, 7);                % radial branch -> bus 7 isolated
same('bus 7 dropped', S.bus, 1:6);
S = step(S, 'delbus', 4);                   % bus removal
same('bus 4 removed', S.bus, [1 2 3 5 6]);
zbus_show(S, 1, 'Z-bus after all changes');

fprintf('\n=== 3. Isolating a whole group of buses ===\n');
T = S;
T = step(T, 'add', 8, 3, 0.1j);
T = step(T, 'add', 9, 8, 0.2j);
T = step(T, 'remove', 8, 3);                % floating side is the "p" side
same('buses 8 and 9 dropped', T.bus, [1 2 3 5 6]);
T = step(T, 'add', 10, 0, 0.3j);
T = step(T, 'add', 11, 10, 0.1j);
T = step(T, 'remove', 0, 10);               % last ground tie of 10,11
same('buses 10 and 11 dropped', T.bus, [1 2 3 5 6]);

fprintf('\n=== 4. Z-bus entered directly (topology unknown) ===\n');
[S0] = zbus_build(B);
D = struct('Z', S0.Z, 'bus', 1:4, 'br', zeros(0, 3), 'topo', false);
D = zbus_modify(D, 'remove', 1, 2, 0.10j);
R = zbus_modify(S0, 'remove', 1, 2);
same('remove 1-2 using the matrix only', D.Z, R.Z);
D = zbus_modify(D, 'change', 3, 4, 0.05j, 0.10j);
R = zbus_modify(R, 'change', 3, 4, 0.05j);
same('change 3-4 using the matrix only', D.Z, R.Z);
D = zbus_modify(D, 'add', 5, 2, 0.1j);
D = zbus_modify(D, 'remove', 2, 5);         % uses the remembered impedance
same('radial bus found from the matrix only', D.bus, 1:4);

fprintf('\n=== 5. Random 60-bus systems, 300 random modifications ===\n');
rng_seed(7);
worst = 0;
for trial = 1:3
    S = zbus_build(random_network(60));
    for k = 1:100
        S = random_change(S);
        [ok, err] = zbus_verify(S, true);
        worst = max(worst, err);
        if ~ok, nfail = nfail + 1; fprintf('  FAIL trial %d step %d (err %.3g)\n', trial, k, err); end
    end
end
if worst < 1e-8, npass = npass + 1; end
fprintf('  max |Zbus - inv(Ybus)| over all random changes = %.2e\n', worst);

fprintf('\n==== %d checks passed, %d failed ====\n', npass, nfail);

    % ------------------------------------------------------------------
    function S = step(S, op, varargin)
        [S, msg] = zbus_modify(S, op, varargin{:});
        fprintf('  %s\n', msg);
        check([op ' ' mat2str(cell2mat(varargin(1:min(2, end))))], S);
    end

    function check(name, S)
        ok = zbus_verify(S, true);
        report(name, ok);
    end

    function same(name, a, b)
        report(name, isequal(size(a), size(b)) && max(abs(a(:) - b(:))) < 1e-9);
    end

    function report(name, ok)
        if ok
            npass = npass + 1; fprintf('     [PASS] %s\n', name);
        else
            nfail = nfail + 1; fprintf('     [FAIL] %s\n', name);
        end
    end
end

% ------------------------------------------------------------------------
function B = random_network(n)
B = zeros(0, 3);
for i = 2:n                                  % random spanning tree
    B(end+1, :) = [i randi(i - 1) rz()]; %#ok<AGROW>
end
for i = randperm(n, 4)                       % ground ties
    B(end+1, :) = [i 0 rz()]; %#ok<AGROW>
end
for t = 1:n                                  % extra meshes
    ij = randperm(n, 2);
    B(end+1, :) = [ij rz()]; %#ok<AGROW>
end
B = B(randperm(size(B, 1)), :);
end

function z = rz()
z = 0.01 + 0.05 * rand() + 1j * (0.05 + 0.3 * rand());
end

function S = random_change(S)
n = numel(S.bus);
m = size(S.br, 1);
r = rand();
if n == 0 || r < 0.15
    S = zbus_modify(S, 'add', max([S.bus 0]) + 1, 0, rz());          % Type 1
elseif r < 0.30
    S = zbus_modify(S, 'add', max(S.bus) + 1, S.bus(randi(n)), rz()); % Type 2
elseif r < 0.45
    S = zbus_modify(S, 'add', S.bus(randi(n)), 0, rz());              % Type 3
elseif r < 0.60 && n >= 2
    ij = S.bus(randperm(n, 2));
    S = zbus_modify(S, 'add', ij(1), ij(2), rz());                    % Type 4
elseif r < 0.80 && m > 0
    b = randi(m);
    S = zbus_modify(S, 'remove', real(S.br(b, 1)), real(S.br(b, 2)), S.br(b, 3));
elseif r < 0.93 && m > 0
    b = randi(m);
    S = zbus_modify(S, 'change', real(S.br(b, 1)), real(S.br(b, 2)), rz(), S.br(b, 3));
elseif n > 3
    S = zbus_modify(S, 'delbus', S.bus(randi(n)));
end
end

function rng_seed(s)
if exist('OCTAVE_VERSION', 'builtin')
    rand('seed', s); %#ok<RAND>
else
    rng(s);
end
end

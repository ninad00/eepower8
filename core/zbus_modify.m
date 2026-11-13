function [S, msg, typ] = zbus_modify(S, op, varargin)
%ZBUS_MODIFY  Apply one topology change to a bus impedance (Z-bus) matrix.
%
%   The network model S is a struct with fields
%       S.Z    - n x n bus impedance matrix (complex, symmetric)
%       S.bus  - 1 x n bus numbers (labels) of the rows/columns of S.Z
%       S.br   - m x 3 branch list [from to Zb]   (bus 0 = reference/ground)
%       S.topo - true if S.br describes the complete network
%
%   [S,msg,typ] = zbus_modify(S,'add',    p,q,Zb)          add a branch p-q
%   [S,msg,typ] = zbus_modify(S,'remove', p,q[,Zb])        remove a branch p-q
%   [S,msg,typ] = zbus_modify(S,'change', p,q,Znew[,Zold]) change branch impedance
%   [S,msg,typ] = zbus_modify(S,'delbus', k)               remove bus k
%
%   Use 0 for the reference bus.  The type of modification is identified
%   automatically from which of the two buses already exist in S.Z:
%
%     Type 1  new bus p  -> reference      Znew = [Z 0; 0 Zb]
%     Type 2  new bus p  -> existing k     Znew = [Z Z(:,k); Z(k,:) Zkk+Zb]
%     Type 3  existing k -> reference      Znew = Z - Z(:,k)Z(k,:)/(Zkk+Zb)
%     Type 4  existing j -> existing k     Znew = Z - (Zj-Zk)(Zj-Zk)'/(Zjj+Zkk-2Zjk+Zb)
%
%   Removing a branch = adding -Zb in parallel with it (Type 3/4 with -Zb).
%   If that branch was the only path to the reference for some buses, the
%   denominator becomes zero; those buses are isolated and are dropped.
%   Changing Zold -> Znew = adding Zx = Zold*Znew/(Zold-Znew) in parallel.
%   Mutual coupling between branches is not considered.

if ~isfield(S, 'br'),   S.br = zeros(0, 3); end
if ~isfield(S, 'topo'), S.topo = false;     end
typ = 0;

switch lower(op)
    case 'add'
        need(varargin, 3, 'add needs p, q and Zb');
        [p, q, z] = deal(varargin{1:3});
        check_bus(p); check_bus(q); check_z(z);
        [S, msg, typ] = add_branch(S, p, q, z);
        S.br(end+1, :) = [p q z];

    case 'remove'
        need(varargin, 2, 'remove needs p and q');
        [p, q] = deal(varargin{1:2});
        check_bus(p); check_bus(q);
        z = opt(varargin, 3);
        [row, z] = find_branch(S, p, q, z);
        [S, msg, typ] = remove_branch(S, p, q, z, row);

    case 'change'
        need(varargin, 3, 'change needs p, q and Znew');
        [p, q, znew] = deal(varargin{1:3});
        check_bus(p); check_bus(q);
        [row, zold] = find_branch(S, p, q, opt(varargin, 4));
        if isinf(znew)
            [S, msg, typ] = remove_branch(S, p, q, zold, row);
        elseif abs(znew - zold) <= 1e-12 * max(1, abs(zold))
            msg = 'New impedance equals the present one - Z-bus unchanged.';
        else
            check_z(znew);
            if (p ~= 0 && ~has_bus(S, p)) || (q ~= 0 && ~has_bus(S, q))
                error('zbus:nobus', 'Branch %s is not connected to buses of this Z-bus.', bname(p, q));
            end
            zx = zold * znew / (zold - znew);          % parallel equivalent
            [S, ~, typ] = add_branch(S, p, q, zx);
            if ~isempty(row)
                S.br(row, 3) = znew;
            else
                S.br(end+1, :) = [p q znew];
            end
            msg = sprintf(['Type %d: branch %s changed from %s to %s, done by adding ' ...
                'Zx = Zold*Znew/(Zold-Znew) = %s in parallel.'], ...
                typ, bname(p, q), zfmt(zold), zfmt(znew), zfmt(zx));
        end

    case 'delbus'
        need(varargin, 1, 'delbus needs the bus number');
        k = varargin{1};
        check_bus(k);
        if k == 0, error('zbus:args', 'The reference bus cannot be removed.'); end
        if ~has_bus(S, k), error('zbus:nobus', 'Bus %d is not in the Z-bus.', k); end
        msgs = {};
        if S.topo
            % physically disconnect the bus: remove every branch touching it
            while has_bus(S, k)
                r = find(real(S.br(:,1)) == k | real(S.br(:,2)) == k, 1);
                if isempty(r), break; end
                [S, m1] = remove_branch(S, real(S.br(r,1)), real(S.br(r,2)), S.br(r,3), r);
                msgs{end+1} = m1; %#ok<AGROW>
            end
        end
        if has_bus(S, k)
            i = bus_index(S, k);
            S.Z(i, :) = []; S.Z(:, i) = []; S.bus(i) = [];
            if ~isempty(S.br)
                S.br(real(S.br(:,1)) == k | real(S.br(:,2)) == k, :) = [];
            end
            msgs{end+1} = sprintf(['Bus %d eliminated: its row and column were deleted ' ...
                '(Kron reduction of a zero-injection bus; the rest of the matrix is unchanged).'], k);
        end
        msg = strjoin(msgs, sprintf('\n     '));
        typ = 5;

    otherwise
        error('zbus:args', 'Unknown operation "%s".', op);
end

% keep rows/columns ordered by bus number
[~, o] = sort(S.bus);
S.bus = S.bus(o);
S.Z = S.Z(o, o);
end

% ------------------------------------------------------------------------
function [S, msg, typ] = add_branch(S, p, q, z)
if p == q, error('zbus:args', 'Both ends of the branch are bus %d.', p); end
if p == 0, [p, q] = deal(q, p); end          % if a reference end exists it is q
Z = S.Z;
n = numel(S.bus);
if q == 0
    if ~has_bus(S, p)                         % ---- Type 1
        typ = 1;
        S.Z = [Z zeros(n, 1); zeros(1, n) z];
        S.bus(end+1) = p;
        msg = sprintf('Type 1: new bus %d connected to the reference through Zb = %s.', p, zfmt(z));
    else                                      % ---- Type 3
        typ = 3;
        k = bus_index(S, p);
        den = Z(k, k) + z;
        check_den(den, Z, z);
        S.Z = Z - Z(:, k) * Z(k, :) / den;
        msg = sprintf('Type 3: existing bus %d connected to the reference through Zb = %s.', p, zfmt(z));
    end
else
    hp = has_bus(S, p); hq = has_bus(S, q);
    if hp && hq                               % ---- Type 4
        typ = 4;
        j = bus_index(S, p); k = bus_index(S, q);
        den = Z(j, j) + Z(k, k) - 2 * Z(j, k) + z;
        check_den(den, Z, z);
        S.Z = Z - (Z(:, j) - Z(:, k)) * (Z(j, :) - Z(k, :)) / den;
        msg = sprintf('Type 4: branch Zb = %s added between existing buses %d and %d.', zfmt(z), p, q);
    elseif hp || hq                           % ---- Type 2
        typ = 2;
        if hp, old = p; new = q; else, old = q; new = p; end
        k = bus_index(S, old);
        S.Z = [Z Z(:, k); Z(k, :) Z(k, k) + z];
        S.bus(end+1) = new;
        msg = sprintf('Type 2: new bus %d connected to existing bus %d through Zb = %s.', new, old, zfmt(z));
    else
        error('zbus:isolated', ['Neither bus %d nor bus %d is in the Z-bus yet. Connect one ' ...
            'of them to the network or to the reference first.'], p, q);
    end
end
end

% ------------------------------------------------------------------------
function [S, msg, typ] = remove_branch(S, p, q, z, row)
if p == 0, [p, q] = deal(q, p); end
if ~has_bus(S, p) || (q ~= 0 && ~has_bus(S, q))
    error('zbus:nobus', 'Branch %s is not connected to buses of this Z-bus.', bname(p, q));
end
if ~isempty(row), S.br(row, :) = []; end
Z = S.Z;
k = bus_index(S, p);
if q == 0
    typ = 3;
    v = Z(:, k);                       % voltages for 1 A injected at k
    den = Z(k, k) - z;
else
    typ = 4;
    j = bus_index(S, q);
    v = Z(:, k) - Z(:, j);             % voltages for 1 A in at k, out at j
    den = v(k) - v(j) - z;             % Zkk + Zjj - 2Zjk - Zb
end
scale = max([1; abs(z); abs(Z(:))]);
if abs(den) <= 1e-9 * scale
    % The branch carried all the current: it was the only path to the
    % reference for one part of the network.  That part (|v| = |Zb|) floats.
    fl = abs(v) > 0.5 * abs(z);
    lost = S.bus(fl);
    S.Z(fl, :) = []; S.Z(:, fl) = []; S.bus(fl) = [];
    if ~isempty(S.br)
        S.br(ismember(real(S.br(:,1)), lost) | ismember(real(S.br(:,2)), lost), :) = [];
    end
    typ = 6;
    msg = sprintf(['Branch %s (Zb = %s) was the only path to the reference for bus(es) %s.\n' ...
        '     Removing it isolates them, so their rows/columns were deleted from the Z-bus.'], ...
        bname(p, q), zfmt(z), mat2str(lost));
else
    if q == 0
        S.Z = Z - Z(:, k) * Z(k, :) / den;
    else
        S.Z = Z - v * (Z(k, :) - Z(j, :)) / den;
    end
    msg = sprintf('Type %d (removal): branch %s with Zb = %s removed by adding -Zb in parallel.', ...
        typ, bname(p, q), zfmt(z));
end
end

% ------------------------------------------------------------------------
function [row, z] = find_branch(S, p, q, z)
row = [];
if ~isempty(S.br)
    a = real(S.br(:, 1)); b = real(S.br(:, 2));
    rows = find((a == p & b == q) | (a == q & b == p));
    if ~isempty(rows) && ~isempty(z)
        rows = rows(abs(S.br(rows, 3) - z) <= 1e-9 * max(1, abs(z)));
    end
    if ~isempty(rows)
        row = rows(1);
        if isempty(z), z = S.br(row, 3); end
    end
end
if isempty(row)
    if S.topo
        error('zbus:nobranch', 'There is no branch %s%s in the network.', bname(p, q), ...
            ternary(isempty(z), '', [' with Zb = ' zfmt(z)]));
    elseif isempty(z)
        error('zbus:needz', ['The impedance of branch %s is not known (the Z-bus was entered ' ...
            'directly). Please give its impedance.'], bname(p, q));
    end
end
end

% ------------------------------------------------------------------------
function tf = has_bus(S, k)
tf = k ~= 0 && any(S.bus == k);
end

function i = bus_index(S, k)
i = find(S.bus == k, 1);
end

function check_bus(p)
if ~isscalar(p) || ~isreal(p) || p < 0 || p ~= round(p) || ~isfinite(p)
    error('zbus:args', 'Bus numbers must be non-negative integers (0 = reference).');
end
end

function check_z(z)
if ~isscalar(z) || ~isfinite(z)
    error('zbus:args', 'Branch impedance must be a finite (complex) number.');
end
end

function check_den(den, Z, z)
if abs(den) <= 1e-12 * max([1; abs(z); abs(Z(:))])
    error('zbus:singular', ['This modification makes the Z-bus singular ' ...
        '(Thevenin impedance + Zb = 0).']);
end
end

function need(args, n, txt)
if numel(args) < n, error('zbus:args', '%s.', txt); end
end

function v = opt(args, i)
if numel(args) >= i, v = args{i}; else, v = []; end
end

function s = bname(p, q)
s = sprintf('%s-%s', bstr(p), bstr(q));
end

function s = bstr(p)
if p == 0, s = 'ref'; else, s = sprintf('%d', p); end
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

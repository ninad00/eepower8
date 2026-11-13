function [ok, err, Zy] = zbus_verify(S, quiet)
%ZBUS_VERIFY  Check the Z-bus against inv(Ybus) formed from the branch list.
%   [ok, err] = zbus_verify(S)   ok = true when max|Z - inv(Ybus)| is ~0.
if nargin < 2, quiet = false; end
ok = []; err = NaN; Zy = [];
if ~S.topo
    say(quiet, ['  The network topology is not known (Z-bus was entered directly), ' ...
        'so it cannot be checked against Ybus.\n']);
    return;
end
n = numel(S.bus);
if n == 0
    ok = true; err = 0; say(quiet, '  Z-bus is empty - nothing to verify.\n'); return;
end
Y = zeros(n);
for r = 1:size(S.br, 1)
    p = real(S.br(r, 1)); q = real(S.br(r, 2)); z = S.br(r, 3);
    if z == 0
        say(quiet, '  Branch %d has zero impedance - Ybus cannot be formed.\n', r);
        return;
    end
    y = 1 / z;
    i = find(S.bus == p, 1); j = find(S.bus == q, 1);
    if (p ~= 0 && isempty(i)) || (q ~= 0 && isempty(j))
        error('zbus:verify', 'Branch %d refers to a bus that is not in the Z-bus.', r);
    end
    if p ~= 0, Y(i, i) = Y(i, i) + y; end
    if q ~= 0, Y(j, j) = Y(j, j) + y; end
    if p ~= 0 && q ~= 0
        Y(i, j) = Y(i, j) - y;
        Y(j, i) = Y(j, i) - y;
    end
end
Zy = Y \ eye(n);
err = max(abs(Zy(:) - S.Z(:)));
ok = err <= 1e-8 * max(1, max(abs(S.Z(:))));
if ok
    say(quiet, '  VERIFIED: Z-bus equals inv(Ybus) built from the branch list (max error %.2e).\n', err);
else
    say(quiet, '  MISMATCH: max |Zbus - inv(Ybus)| = %.4g\n', err);
end
end

function say(quiet, varargin)
if ~quiet, fprintf(varargin{:}); end
end

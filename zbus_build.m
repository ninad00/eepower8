function [S, steps] = zbus_build(B)
%ZBUS_BUILD  Build the Z-bus from branch data with the Z-bus building algorithm.
%   [S, steps] = zbus_build(B)   B is m x 3: [from to Zb], bus 0 = reference.
%   Branches are added one at a time (Type 1..4); a branch whose two buses are
%   both still unknown is postponed until one of them has been added.
if isempty(B), B = zeros(0, 3); end
if size(B, 2) ~= 3
    error('zbus:args', 'Branch data must have 3 columns: [from to Zb].');
end
S = struct('Z', zeros(0), 'bus', zeros(1, 0), 'br', zeros(0, 3), 'topo', true);
steps = {};
pending = 1:size(B, 1);
while ~isempty(pending)
    progress = false;
    for t = pending
        p = real(B(t, 1)); q = real(B(t, 2));
        if p == 0 || q == 0 || any(S.bus == p) || any(S.bus == q)
            [S, msg] = zbus_modify(S, 'add', p, q, B(t, 3));
            steps{end+1} = sprintf('Branch %d (%s): %s', t, bpair(p, q), msg); %#ok<AGROW>
            pending(pending == t) = [];
            progress = true;
        end
    end
    if ~progress
        error('zbus:isolated', ['Branches %s are not connected to the reference through ' ...
            'the rest of the network, so the Z-bus does not exist.'], mat2str(pending));
    end
end
end

function s = bpair(p, q)
f = @(x) ifelse(x == 0, 'ref', sprintf('%d', x));
s = [f(p) '-' f(q)];
end

function out = ifelse(c, a, b)
if c, out = a; else, out = b; end
end

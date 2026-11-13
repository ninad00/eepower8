function zbus_branches(S, fid)
%ZBUS_BRANCHES  Print the branch list of the network model S.
if nargin < 2, fid = 1; end
m = size(S.br, 1);
if S.topo
    fprintf(fid, '\nBranch list (%d branches, 0 = reference):\n', m);
else
    fprintf(fid, ['\nBranch list - the Z-bus was entered directly, so only the ' ...
        'branches added in this session are known (%d):\n'], m);
end
if m == 0, fprintf(fid, '   (none)\n'); return; end
fprintf(fid, '   %4s  %5s  %5s   %s\n', 'No.', 'From', 'To', 'Impedance Zb');
for r = 1:m
    fprintf(fid, '   %4d  %5s  %5s   %s\n', r, bs(S.br(r,1)), bs(S.br(r,2)), zfmt(S.br(r,3)));
end
end

function s = bs(p)
p = real(p);
if p == 0, s = 'ref'; else, s = sprintf('%d', p); end
end

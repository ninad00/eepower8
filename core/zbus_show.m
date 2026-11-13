function zbus_show(S, fid, ttl)
%ZBUS_SHOW  Print the Z-bus matrix with bus numbers, in column blocks.
%   zbus_show(S)            prints to the command window
%   zbus_show(S, fid, ttl)  prints to an open file with a title
if nargin < 2 || isempty(fid), fid = 1; end
if nargin < 3, ttl = 'Z-bus matrix'; end

n = numel(S.bus);
Z = S.Z;
if n == 0
    fprintf(fid, '\n%s is empty (no buses connected to the reference).\n', ttl);
    return;
end

scale = max(1, max(abs(Z(:))));
% clear round-off noise so it does not print as -0.00000
re = real(Z); im = imag(Z);
re(abs(re) < 1e-12 * scale) = 0;
im(abs(im) < 1e-12 * scale) = 0;
Z = complex(re, im);
hasIm = any(abs(imag(Z(:))) > 1e-12 * scale);
hasRe = any(abs(real(Z(:))) > 1e-12 * scale);

if hasIm && hasRe
    w = 23; note = '';
    cell2str = @(z) sprintf('  %10.5f%+10.5fj', real(z), imag(z));
elseif hasIm
    w = 13; note = '   (all elements are imaginary:  Z = j x [values below])';
    cell2str = @(z) sprintf('  %11.5f', imag(z));
else
    w = 13; note = '';
    cell2str = @(z) sprintf('  %11.5f', real(z));
end

perBlock = max(1, floor(110 / w));
fprintf(fid, '\n%s  (%d x %d)%s\n', ttl, n, n, note);
for c0 = 1:perBlock:n
    cols = c0:min(n, c0 + perBlock - 1);
    if n > perBlock
        fprintf(fid, '\n  Columns %d to %d\n', cols(1), cols(end));
    end
    fprintf(fid, '%7s', 'Bus |');
    for c = cols
        fprintf(fid, sprintf('%%%ds', w), sprintf('%d', S.bus(c)));
    end
    fprintf(fid, '\n%s\n', repmat('-', 1, 7 + w * numel(cols)));
    for r = 1:n
        fprintf(fid, '%5d |', S.bus(r));
        for c = cols
            fprintf(fid, '%s', cell2str(Z(r, c)));
        end
        fprintf(fid, '\n');
    end
end
end

function s = zfmt(z)
%ZFMT  Short text form of a (complex) impedance, e.g. 0.1 + j0.25.
re = real(z); im = imag(z);
tiny = 1e-12 * max(1, abs(z));
if isinf(z)
    s = 'Inf';
elseif abs(im) <= tiny
    s = sprintf('%.6g', re);
elseif abs(re) <= tiny
    if im < 0, s = sprintf('-j%.6g', -im); else, s = sprintf('j%.6g', im); end
else
    if im < 0, sg = '-'; else, sg = '+'; end
    s = sprintf('%.6g %s j%.6g', re, sg, abs(im));
end
end

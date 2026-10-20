function [f_body, f_wheel] = natural_frequencies(V)
%NATURAL_FREQUENCIES Undamped natural frequencies of the 2-DOF quarter car [Hz].
%   [f_body, f_wheel] = NATURAL_FREQUENCIES(V) with K = [ks -ks; -ks ks+kt],
%   M = diag([ms mu]).

K = [V.ks, -V.ks; -V.ks, V.ks + V.kt];
M = diag([V.ms, V.mu]);
f = sort(sqrt(eig(M\K)))/(2*pi);
f_body  = f(1);
f_wheel = f(2);
end

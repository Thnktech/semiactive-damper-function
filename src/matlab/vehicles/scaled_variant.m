function V = scaled_variant(name, ms, mass_ratio, f_body, f_wheel)
%SCALED_VARIANT Build a scaled vehicle variant from design targets (D15, D16).
%   V = SCALED_VARIANT(name, ms, mass_ratio, f_body, f_wheel) sets
%   mu = mass_ratio*ms and solves ks, kt so that the undamped 2-DOF quarter
%   car has natural frequencies f_body and f_wheel [Hz] exactly.
%
%   Eigenvalues lambda of M\K satisfy
%     lambda1 + lambda2 = ks/ms + (ks + kt)/mu
%     lambda1 * lambda2 = ks*kt/(ms*mu)
%   Eliminating kt gives a quadratic in ks; the smaller root (softer
%   suspension) is used.

V = vehicle_struct(name, 'scaled variant (PA)', 'D16 targets, solved by scaled_variant');
V.ms = ms;
V.mu = mass_ratio*ms;
V.f_body_target  = f_body;
V.f_wheel_target = f_wheel;

% Targets as squared angular frequencies, their sum S and product P (see help).
% The smaller root is the realistic one: the larger gives a stiff suspension
% with a soft tire, i.e. body and wheel modes swapped.
l1 = (2*pi*f_body)^2;
l2 = (2*pi*f_wheel)^2;
S = l1 + l2;
P = l1*l2;
a = 1/V.ms + 1/V.mu;
V.ks = (S - sqrt(S^2 - 4*a*P*V.ms))/(2*a);
V.kt = P*V.ms*V.mu/V.ks;

V = damping_rule(V);
end

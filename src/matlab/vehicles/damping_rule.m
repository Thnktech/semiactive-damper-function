function V = damping_rule(V)
%DAMPING_RULE Set c_min, c_passive, c_max from body-mode damping ratios (D22).
%   V = DAMPING_RULE(V) fills the damping fields of vehicle struct V from
%       c = 2*zeta*sqrt(ks*ms)
%   with zeta_min = 0.1, zeta_passive = 0.3, zeta_max = 0.8.
%   Fields already set (not NaN) are kept.
%
%   Sources (see docs/DECISIONS.md, D22):
%     zeta_passive = 0.3 and zeta_max = 0.8: Slaski (2011), Transport
%       Problems 6(2): passenger cars ~0.3; optimum handling up to 0.8.
%     zeta_min = 0.1: project assumption (PA), below the 0.2 optimum ride.

zeta = struct('min', 0.1, 'passive', 0.3, 'max', 0.8);
c_crit = 2*sqrt(V.ks*V.ms);   % N*s/m, critical damping of the body mode

if isnan(V.c_min),     V.c_min     = zeta.min*c_crit;     end
if isnan(V.c_passive), V.c_passive = zeta.passive*c_crit; end
if isnan(V.c_max),     V.c_max     = zeta.max*c_crit;     end
end

function V = sedan_ref()
%SEDAN_REF Reference vehicle: mid-size sedan, IRI Golden Car ratios (D14).
%   Golden Car (Sayers 1995, TRR 1501): ks/ms = 63.3 s^-2, kt/ms = 653 s^-2,
%   mu/ms = 0.15; dimensionalized with ms = 230 kg as in Mucka (2018).
%   Golden Car damping (c/ms = 6.0 s^-1) is NOT used: Sayers notes it is
%   higher than in most cars. Damping from DAMPING_RULE (D22).

V = vehicle_struct('sedan_ref', 'published', ...
    'Sayers (1995) TRR 1501, Golden Car; ms = 230 kg per Mucka (2018) (D14)');
V.ms = 230;          % kg
V.mu = 0.15*V.ms;    % kg   (34.5)
V.ks = 63.3*V.ms;    % N/m  (14 559)
V.kt = 653*V.ms;     % N/m  (150 190)
V = damping_rule(V);
end

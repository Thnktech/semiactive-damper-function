function [t, zr] = road_iso8608(roadClass, speed_kmh, T, seed)
%ROAD_ISO8608 ISO 8608-based random road profile (harmonic superposition).
%   [t, zr] = ROAD_ISO8608(roadClass, speed_kmh, T, seed)
%     roadClass  'A' | 'B' | 'C' | 'D'
%     speed_kmh  vehicle speed [km/h]
%     T          duration [s]
%     seed       random seed (same seed -> same road)
%   t  [s] column, 1 ms step;  zr  [m] road height, same size.

% 1 ms grid as the plant and controller (D8).
dt = 1e-3;
t  = (0:dt:T)';

% 1) Class value Gd(n0) [m^3]: ISO 8608 defines each class by its displacement
%    PSD at n0 = 0.1 cycles/m; these are the class mid values, each class 4x the
%    previous one (2x in road height).

switch upper(roadClass)
    case 'A'
        Gd0 = 16e-6;
    case 'B'
        Gd0 = 64e-6;
    case 'C'
        Gd0 = 256e-6;
    case 'D'
        Gd0 = 1024e-6;
    otherwise
        error('Invalid road class: use A, B, C, or D.');
end

n0 = 0.1;                            % reference spatial frequency [cycles/m]

% 2) Spatial frequencies: one random frequency inside each of N bins
%    Range 0.011-2.83 cycles/m (wavelengths 0.35-91 m): the band that excites
%    body and wheel modes at road speeds. The random position inside each bin
%    is essential: with equally spaced frequencies the road repeats every
%    1/dn = 354 m (found in M2 by TestRoads).
N  = 1000;
dn = (2.83 - 0.011)/N;                       % bin width = Spacing delta(n)
rng(seed);                                   % moved here: frequencies and phases are random
n  = 0.011 + ((0:N-1)' + rand(N, 1))*dn;     % random position inside each bin

% 3) Amplitudes
%    ISO 8608 shape Gd(n) = Gd(n0)*(n/n0)^-w with waviness w = 2.
Gd = Gd0 * (n/n0).^(-2);   
%    A cosine of amplitude A has variance A^2/2; each wave carries the
%    variance Gd*dn of its bin, so the sum has the target PSD.
A = sqrt(2*Gd*dn);                   % Amplitude of wave i

% 4) Random phases (repeatable)
%    Random phases make the sum look like a real random road; because the
%    seed is fixed, every control strategy drives exactly the same road.
phi = 2*pi*rand(N, 1);

% 5) Distance
V = speed_kmh/3.6;                   % Velocity in m/s
%    The profile is defined over distance; at constant speed the wheel sees
%    it in time as x = V*t (faster driving = higher temporal frequencies).
x = V*t;                             % Distance traveled

% 6) Sum the waves (loop: a 30001x1000 matrix would use 240 MB)
zr = zeros(size(t));
for i = 1:N
    zr = zr + A(i)*cos(2*pi*n(i)*x + phi(i)); 
end

% 7) Smooth start: fade in over the first 1 s, so the car does not
%    start on a sudden road step (KPIs ignore t < 2 s anyway)
zr = zr .* min(t/1, 1);
end

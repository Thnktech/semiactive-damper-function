function [t, zr] = road_iso8608(roadClass, speed_kmh, T, seed)
%ROAD_ISO8608 ISO 8608-based random road profile (harmonic superposition).
%   [t, zr] = ROAD_ISO8608(roadClass, speed_kmh, T, seed)
%     roadClass  'A' | 'B' | 'C' | 'D'
%     speed_kmh  vehicle speed [km/h]
%     T          duration [s]
%     seed       random seed (same seed -> same road)
%   t  [s] column, 1 ms step;  zr  [m] road height, same size.

dt = 1e-3;
t  = (0:dt:T)';

% 1) Class value Gd(n0) [m^3]

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


% 2) Spatial frequencies

% 2) Spatial frequencies: one random frequency inside each of N bins
N  = 1000;
dn = (2.83 - 0.011)/N;                       % bin width = Spacing delta(n)
rng(seed);                                   % moved here: frequencies and phases are random
n  = 0.011 + ((0:N-1)' + rand(N, 1))*dn;     % random position inside each bin

% 3) Amplitudes
Gd = Gd0 * (n/n0).^(-2);   
A = sqrt(2*Gd*dn);                   % Amplitude of wave i

% 4) Random phases (repeatable)
  
phi = 2*pi*rand(N, 1);

% 5) Distance
V = speed_kmh/3.6;                   % Velocity in m/s
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

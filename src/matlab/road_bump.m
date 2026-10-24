function [t, zr] = road_bump(h, L, speed_kmh, T, t0)
%ROAD_BUMP Single half-sine bump on a flat road (scenario SC-BUMP).
%   [t, zr] = ROAD_BUMP(h, L, speed_kmh, T, t0)
%     h          bump height [m]           (SC-BUMP: 0.05)
%     L          bump length [m]           (SC-BUMP: 0.5)
%     speed_kmh  vehicle speed [km/h]      (SC-BUMP: 18)
%     T          duration [s]
%     t0         time the wheel reaches the bump [s]

% 1 ms grid: the same step as the plant solver and the controller (D8), so
% every road sample is used exactly once and logs stay sample-aligned.
dt = 1e-3;
t  = (0:dt:T)';
% The bump is defined in distance, the simulation runs in time: the wheel
% position on the bump is s = V*(t - t0) (negative = not reached yet).
V = speed_kmh/3.6;
s = V*(t - t0);                 % distance into the bump [m]
% Flat road everywhere, then the half-sine only where 0 <= s <= L: the shape of
% the literature bump case used for SC-BUMP (REQ.md, [L4]).
zr = zeros(size(t));
on = s >= 0 & s <= L;           % samples on the bump
zr(on) = h*sin(pi*s(on)/L);
end

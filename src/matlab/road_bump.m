function [t, zr] = road_bump(h, L, speed_kmh, T, t0)
%ROAD_BUMP Single half-sine bump on a flat road (scenario SC-BUMP).
%   [t, zr] = ROAD_BUMP(h, L, speed_kmh, T, t0)
%     h          bump height [m]           (SC-BUMP: 0.05)
%     L          bump length [m]           (SC-BUMP: 0.5)
%     speed_kmh  vehicle speed [km/h]      (SC-BUMP: 18)
%     T          duration [s]
%     t0         time the wheel reaches the bump [s]

dt = 1e-3;
t  = (0:dt:T)';
V = speed_kmh/3.6;
s = V*(t - t0);                 % distance into the bump [m]
zr = zeros(size(t));
on = s >= 0 & s <= L;           % samples on the bump
zr(on) = h*sin(pi*s(on)/L);
end

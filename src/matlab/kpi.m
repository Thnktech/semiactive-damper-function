function K = kpi(t, zs_ddot, F_tire_dyn, susp_travel, F_static, t_skip)
%KPI Performance indicators of one simulation run (REQ-P).
%   K = KPI(t, zs_ddot, F_tire_dyn, susp_travel, F_static)
%   K = KPI(..., t_skip)   transient skipped for RMS KPIs [s], default 2
%
%   K.rms_zs_ddot     RMS body acceleration, t >= t_skip          [m/s^2]
%   K.rms_F_tire_dyn  RMS dynamic tire load, t >= t_skip          [N]
%   K.rms_F_tire_rel  rms_F_tire_dyn / F_static                   [-]
%   K.max_travel_mm   max |zs - zu| over the whole run            [mm]

% 1) Default for t_skip
if nargin < 6
    t_skip = 2; 
end

% 2) Input checks (fail loudly instead of returning wrong numbers)
n = numel(t); 
if numel(zs_ddot) ~= n || numel(F_tire_dyn) ~= n || numel(susp_travel) ~= n
        error('kpi:size', 'Size not equal'); 
end
%    TODO: there must be samples after t_skip
w = t >= t_skip; 
if ~any(w)
    error('kpi:window', 'No samples to analyse'); 
end

% 3) RMS KPIs over the window w
K.rms_zs_ddot    = sqrt(mean(zs_ddot(w).^2));
K.rms_F_tire_dyn = sqrt(mean(F_tire_dyn(w).^2));
K.rms_F_tire_rel = K.rms_F_tire_dyn / F_static;

% 4) Travel over the whole run, in mm
K.max_travel_mm = 1000*max(abs(susp_travel));
end

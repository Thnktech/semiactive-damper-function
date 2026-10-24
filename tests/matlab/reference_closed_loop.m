function R = reference_closed_loop(P, t, zr, mode, fault)
%REFERENCE_CLOSED_LOOP Independent plain-MATLAB closed loop: oracle for the MiL harness.
%   R = REFERENCE_CLOSED_LOOP(P, t, zr, mode)
%   R = REFERENCE_CLOSED_LOOP(P, t, zr, mode, fault)   fault: fault_flag per sample
%   mode: scalar, or one value per sample (mode schedule)
%   re-implements plant + controller with the textbook timing and returns
%   R.zs_dot, R.zu_dot, R.i_cmd, R.fault_active (columns).
%
%   Timing (D8, D19): at each tick t_k the controller samples its inputs and
%   stores the next values in its delay states; its outputs at t_k are the
%   previous delay states. The plant integrates from t_k to t_k+1 with RK4
%   (ode4) and i_cmd(k) held constant. Road z_r linearly interpolated.
%   Plant: equilibrium coordinates, tire lift-off (D23), damper map, lag.
%   Controller: law slots (D24), Damping_to_current, Safety_and_limits
%   (saturation, rate limit, fault latch; D17, D18).

if nargin < 5, fault = zeros(size(t)); end
if isscalar(mode), mode = mode*ones(size(t)); end
h = t(2) - t(1);
N = numel(t);
% Written in plain MATLAB from the equations, sharing no Simulink settings with
% the harness: if both agree, the harness timing is right (it found the
% artificial algebraic loop, D26).
zrf = @(tt) interp1(t, zr, tt, 'linear');
cmap = @(I) P.c_min + (P.c_max - P.c_min)*(min(max(I, P.I_min), P.I_max) - P.I_min)/(P.I_max - P.I_min);
% Plant state derivatives: actuator lag, body, wheel; max(0, ...) is the tire
% lift-off (a tire cannot pull, D23).
f = @(tt, x, i) [ (i - x(1))/P.tau; x(3); ...
    (-P.ks*(x(2) - x(4)) + cmap(x(1))*(x(5) - x(3)))/P.ms; x(5); ...
    ( P.ks*(x(2) - x(4)) - cmap(x(1))*(x(5) - x(3)) + max(0, P.F_static + P.kt*(zrf(tt) - x(4))) - P.F_static)/P.mu];

x = [P.I_default; 0; 0; 0; 0];        % [I_lag; zs; zs_dot; zu; zu_dot]
di = P.I_default; df = 0;             % controller delay states (D19)
R.zs_dot = zeros(N, 1); R.zu_dot = R.zs_dot; R.i_cmd = R.zs_dot; R.fault_active = R.zs_dot;
for k = 1:N
    i = di; fa = df;                                   % outputs at t_k
    R.zs_dot(k) = x(3); R.zu_dot(k) = x(5); R.i_cmd(k) = i; R.fault_active(k) = fa;
    latched = fa ~= 0 || fault(k) > 0.5;               % fault latch (REQ-S-02)
    if latched
        target = P.I_default;                          % fault reaction (D17)
    else
        target = min(max(law_current(P, x(3), x(5), mode(k)), P.I_min), P.I_max);
    end
    di = i + min(max(target - i, -P.dI_max), P.dI_max);   % rate limit (REQ-F-04)
    df = double(latched);
    if k == N, break; end
    tk = t(k);
    k1 = f(tk, x, i); k2 = f(tk + h/2, x + h/2*k1, i);
    k3 = f(tk + h/2, x + h/2*k2, i); k4 = f(tk + h, x + h*k3, i);
    x = x + h/6*(k1 + 2*k2 + 2*k3 + k4);
end
end

% The four law slots and Damping_to_current, re-written from the equations.
function I = law_current(P, zs, zu, mode)
v = zs - zu;
switch mode
    case 1                                            % Law_1_Skyhook
        if zs*v > 0 && abs(v) > P.eps_vrel
            c = P.c_sky*zs/v;
        else
            c = P.c_min;
        end
    case 2                                            % Law_2_Groundhook
        if -zu*v > 0 && abs(v) > P.eps_vrel
            c = P.c_gnd*(-zu)/v;
        else
            c = P.c_min;
        end
    case 3                                            % Law_3_Hybrid: inactive parts contribute 0
        S = 0; G = 0;
        if abs(v) > P.eps_vrel
            if zs*v > 0, S = P.c_sky*zs/v; end
            if -zu*v > 0, G = P.c_gnd*(-zu)/v; end
        end
        c = P.alpha*S + (1 - P.alpha)*G;
    otherwise                                         % Law_0_Passive and default (D20)
        c = P.c_passive;
end
c = min(max(c, P.c_min), P.c_max);                    % Damping_to_current
I = P.I_min + (c - P.c_min)/(P.c_max - P.c_min)*(P.I_max - P.I_min);
end

function P = setup_params(vehicle)
%SETUP_PARAMS Shared parameter struct P for plant and controller (D9).
%   SETUP_PARAMS puts P for the configured vehicle (PROJECT_CONFIG) in the
%   base workspace, where the Simulink models read it.
%   P = SETUP_PARAMS(vehicle) returns P for the named vehicle instead.
%
%   P = vehicle fields (GET_VEHICLE) plus:
%     I_min, I_max, I_default  damper current range / default [A]  (REQ.md)
%     dI_max                   rate limit per 1 ms step [A]            (REQ-F-04)
%     tau                      actuator lag time constant [s]
%     g                        gravity [m/s^2]
%     l0                       spring preload length ms*g/ks [m]
%     Rt0                      tire preload (ms+mu)*g/kt [m]
%     F_static                 static tire load (ms+mu)*g [N]
%     c_sky, c_gnd             skyhook / groundhook gains [N*s/m]      (D25)
%     alpha                    hybrid blend factor [-]                 (D25)
%     eps_vrel                 relative-velocity guard [m/s]           (D25)

if nargin < 1
    P = get_vehicle();
else
    P = get_vehicle(vehicle);
end
P.I_min = 0.3; 
P.I_max = 1.6; 
P.I_default = 0.95; 
P.dI_max = 0.13;                   % rate limit: max change of i_cmd per 1 ms step [A] (REQ-F-04)
P.I_passive = P.I_min + (P.c_passive - P.c_min)/(P.c_max - P.c_min)*(P.I_max - P.I_min);   % passive mode current [A]

P.tau = 0.010;
P.g = 9.81;
P.l0 = P.ms*P.g/P.ks;              % spring preload length
P.Rt0 = (P.ms+P.mu)*P.g/P.kt;      % tire preload
P.F_static = (P.ms+P.mu)*P.g;      % static tire load

% Control-law parameters (D25)
P.c_sky = P.c_max;                 % skyhook gain [N*s/m]
P.c_gnd = P.c_max;                 % groundhook gain [N*s/m]
P.alpha = 0.5;                     % hybrid blend: 1 = skyhook, 0 = groundhook [-]
P.eps_vrel = 1e-3;                 % |v_rel| guard against division by ~0 [m/s]
%
if nargout == 0
    assignin('base', 'P', P);
    clear P
end
end

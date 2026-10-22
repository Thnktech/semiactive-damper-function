function P = setup_params(vehicle)
%SETUP_PARAMS Shared parameter struct P for plant and controller (D9).
%   SETUP_PARAMS puts P for the configured vehicle (PROJECT_CONFIG) in the
%   base workspace, where the Simulink models read it.
%   P = SETUP_PARAMS(vehicle) returns P for the named vehicle instead.
%
%   P = vehicle fields (GET_VEHICLE) plus:
%     I_min, I_max, I_default  damper current range / default [A]  (REQ.md)
%     tau                      actuator lag time constant [s]
%     g                        gravity [m/s^2]
%     l0                       spring preload length ms*g/ks [m]
%     Rt0                      tire preload (ms+mu)*g/kt [m]
%     F_static                 static tire load (ms+mu)*g [N]

if nargin < 1
    P = get_vehicle();
else
    P = get_vehicle(vehicle);
end
P.I_min = 0.3; P.I_max = 1.6; P.I_default = 0.95; P.tau = 0.010;
P.g = 9.81;
P.l0 = P.ms*P.g/P.ks;              % spring preload length
P.Rt0 = (P.ms+P.mu)*P.g/P.kt;      % tire preload
P.F_static = (P.ms+P.mu)*P.g;      % static tire load

if nargout == 0
    assignin('base', 'P', P);
    clear P
end
end

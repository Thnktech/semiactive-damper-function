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
%     mbc                      weights/scales shared by LQR and MPC    (D30)
%     lqr                      LQR sample time and gain K              (D34)
%     mpc                      MPC formulation, Ts, horizons, weights  (D31)
%   Without an output argument it also puts the MPC object mpc_law5 in the
%   base workspace (DESIGN_MPC).

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

% Model-based laws (v2): one goal for LQR and MPC (D30, D31, D34).
% Each output and the force are divided by a typical size, then weighted.
P.mbc.y_scale  = [2; 0.3*P.F_static; 0.05];  % zs_ddot [m/s^2], F_tire_dyn [N], susp_travel [m]
P.mbc.y_weight = [1; 1; 0.1];                % comfort, road holding, travel (initial tuning)
P.mbc.u_scale  = P.c_max;                    % force scale: c_max at 1 m/s [N]
P.mbc.u_weight = 0.01;                       % weight on the force request [-]

% Law_4_LQR (D34): gain for F_cmd = -K*x at the controller rate
P.lqr.Ts = 0.001;                            % [s]
P.lqr.K  = design_lqr(P, P.lqr.Ts);          % 1x5, states as in qc_prediction_model

% Law_5_MPC (D31): classic receding-horizon MPC; change any value here
P.mpc.formulation = 1;                       % 1 = classic (list in design_mpc)
P.mpc.Ts = 0.005;                            % MPC sample time [s] (5 controller steps)
P.mpc.p  = 10;                               % prediction horizon [samples] -> 50 ms
P.mpc.m  = 5;                                % control horizon [samples]
P.mpc.du_weight = 0.1;                       % weight on force changes between MPC steps [-]
P.mpc.F_bound = 3*P.c_max;                   % placeholder |F| limit, replaced online (D32) [N]
%
if nargout == 0
    assignin('base', 'P', P);
    % The MPC block reads its controller object by this name (D31).
    assignin('base', 'mpc_law5', design_mpc(P));
    clear P
end
end

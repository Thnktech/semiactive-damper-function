function sys = qc_prediction_model(P)
%QC_PREDICTION_MODEL Linear quarter car with actuator lag for the model-based laws (D30).
%   sys = QC_PREDICTION_MODEL(P) returns the continuous state-space model that
%   the LQR (Law_4) and MPC (Law_5) slots use to predict the vehicle:
%
%     states   x = [zs - zu; zs_dot; zu - zr; zu_dot; F_d]
%     inputs   u = [F_cmd; zr_dot]
%     outputs  y = [zs_ddot; F_tire_dyn; susp_travel]
%
%   zs - zu      suspension deflection [m]
%   zu - zr      tire deflection [m]
%   F_d          damper force [N], positive when it resists extension
%   F_cmd        requested damper force [N] (what the law decides)
%   zr_dot       road velocity [m/s] (a disturbance, not decided by the law)
%   All positions are deviations from static equilibrium (signals.md).
%
%   Why relative states: every quantity in the cost (body acceleration, tire
%   load, travel) is then a function of the state alone. With absolute
%   positions the tire load would need zr as a direct input, and an LQR gain
%   would penalize the wheel for following the road.
%
%   Why the force lag state F_d: the damper cannot change its force
%   instantly (P.tau, the same first-order lag as in the plant). Without it,
%   body acceleration would depend directly on F_cmd, which the MPC toolbox
%   does not allow and which the real damper cannot do.
%
%   Known differences to plant.slx (model mismatch, by design): linear tire
%   without lift-off; the plant's lag acts on the damping coefficient, here
%   on the force; no gravity (deviations from equilibrium).

ms = P.ms; mu = P.mu; ks = P.ks; kt = P.kt; tau = P.tau;

% Rows follow the states: d/dt [zs-zu, zs_dot, zu-zr, zu_dot, F_d]
A = [ 0      1   0      -1   0
     -ks/ms  0   0       0  -1/ms      % body: spring and damper force pull it back
      0      0   0       1   0
      ks/mu  0  -kt/mu   0   1/mu      % wheel: spring, damper and tire
      0      0   0       0  -1/tau];   % damper force follows F_cmd with lag tau
B = [ 0      0
      0      0
      0     -1                         % tire deflection shrinks when the road rises
      0      0
      1/tau  0];
% Outputs: body acceleration = row 2 of A; tire load grows when the tire is
% compressed (zu - zr < 0); travel = suspension deflection.
C = [-ks/ms  0   0   0  -1/ms
      0      0  -kt  0   0
      1      0   0   0   0];
D = zeros(3, 2);

sys = ss(A, B, C, D);
sys.StateName  = {'susp_defl', 'zs_dot', 'tire_defl', 'zu_dot', 'F_d'};
sys.InputName  = {'F_cmd', 'zr_dot'};
sys.OutputName = {'zs_ddot', 'F_tire_dyn', 'susp_travel'};
end

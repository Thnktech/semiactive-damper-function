function Y = simulate_harness(P, t, zr, mode, fault)
%SIMULATE_HARNESS Run model/harness/harness.slx (plant + controller, closed loop).
%   Y = SIMULATE_HARNESS(P, t, zr, mode)
%   Y = SIMULATE_HARNESS(P, t, zr, mode, fault)
%     P      parameter struct (SETUP_PARAMS)
%     t      time [s], column, 1 ms step, starting at 0
%     zr     road height [m], same size as t
%     mode   control mode (0 passive, 1 skyhook, 2 groundhook, 3 hybrid, 4 LQR,
%            5 MPC, 6 preview MPC)
%     fault  fault_flag per sample (optional, default all 0)
%   Y.t and the 13 harness outputs (columns):
%     zs_ddot, susp_travel, F_tire_dyn, zs_dot, zu_dot, fault_flag, mode, i_cmd, fault_active,
%     zs, zu, zr, F_d (v2: controller inputs 5-8, D36)

% 1) Default: no fault
if nargin < 5
    fault = zeros(size(t)); 
end

% 2) Simulation input: model, parameters, workspace variables, stop time, logging
in = Simulink.SimulationInput('harness');
in = in.setVariable('P', P);
% The MPC blocks read their controller objects mpc_law5 and mpc_law6,
% built from this run's P so that both always match (D31, D40).
in = set_mpc_objects(in, P);
% The harness reads road, fault and mode with From Workspace blocks, each as
% [time value]. setVariable gives them to this run only.
in = in.setVariable('road_in', [t(:) zr(:)]);
in = in.setVariable('road_ahead_in', [t(:) road_ahead(P, zr)]);
in = in.setVariable('fault_in', [t(:) fault(:)]);
% mode may change during a run (mode-schedule tests, MiL logs); a single
% number is expanded to one value per sample.
if isscalar(mode)
    mode = mode*ones(size(t)); 
end      % constant mode -> vector
in = in.setVariable('mode_in', [t(:) mode(:)]);
in = in.setModelParameter('StopTime', num2str(t(end)), 'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');

% 3) Run
out = sim(in);

% 4) Outputs in harness port order
names = {'zs_ddot', 'susp_travel', 'F_tire_dyn', 'zs_dot', 'zu_dot', 'fault_flag', 'mode', 'i_cmd', 'fault_active', ...
         'zs', 'zu', 'zr', 'F_d'};
Y.t = out.yout{1}.Values.Time;
for k = 1:numel(names)
    Y.(names{k}) = out.yout{k}.Values.Data(:); 
end
end

% Ideal look-ahead sensor of the preview MPC (D39): the road height
% T_L = (p+1)*Ts of P.mpcp ahead of the wheel, by shifting the 1 ms road
% samples (exact, no interpolation); after the end the last height is held,
% as the From Workspace block holds the road itself.
function ahead = road_ahead(P, zr)
n = round((P.mpcp.p + 1)*P.mpcp.Ts/1e-3);
zr = zr(:);
ahead = [zr(1+n:end); repmat(zr(end), min(n, numel(zr)), 1)];
end

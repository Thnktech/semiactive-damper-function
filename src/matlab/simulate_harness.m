function Y = simulate_harness(P, t, zr, mode, fault)
%SIMULATE_HARNESS Run model/harness/harness.slx (plant + controller, closed loop).
%   Y = SIMULATE_HARNESS(P, t, zr, mode)
%   Y = SIMULATE_HARNESS(P, t, zr, mode, fault)
%     P      parameter struct (SETUP_PARAMS)
%     t      time [s], column, 1 ms step, starting at 0
%     zr     road height [m], same size as t
%     mode   control mode (0 passive, 1 skyhook, 2 groundhook, 3 hybrid)
%     fault  fault_flag per sample (optional, default all 0)
%   Y.t and the 9 harness outputs (columns):
%     zs_ddot, susp_travel, F_tire_dyn, zs_dot, zu_dot, fault_flag, mode, i_cmd, fault_active

% 1) Default: no fault
if nargin < 5
    fault = zeros(size(t)); 
end

% 2) Simulation input: model, parameters, workspace variables, stop time, logging
in = Simulink.SimulationInput('harness');
in = in.setVariable('P', P);
in = in.setVariable('road_in', [t(:) zr(:)]);
in = in.setVariable('fault_in', [t(:) fault(:)]);
if isscalar(mode)
    mode = mode*ones(size(t)); 
end      % constant mode -> vector
in = in.setVariable('mode_in', [t(:) mode(:)]);
in = in.setModelParameter('StopTime', num2str(t(end)), 'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');

% 3) Run
out = sim(in);

% 4) Outputs in harness port order
names = {'zs_ddot', 'susp_travel', 'F_tire_dyn', 'zs_dot', 'zu_dot', 'fault_flag', 'mode', 'i_cmd', 'fault_active'};
Y.t = out.yout{1}.Values.Time;
for k = 1:numel(names)
    Y.(names{k}) = out.yout{k}.Values.Data(:); 
end
end

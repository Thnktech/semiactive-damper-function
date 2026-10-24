function Y = simulate_plant(P, t, zr, i_cmd)
%SIMULATE_PLANT Run model/plant/plant.slx for one road and current input.
%   Y = SIMULATE_PLANT(P, t, zr, i_cmd)
%     P      parameter struct (SETUP_PARAMS)
%     t      time [s], column, 1 ms step, starting at 0
%     zr     road height [m], same size as t
%     i_cmd  current [A]: scalar (held constant) or same size as t
%   Y.t, Y.zs_dot, Y.zu_dot, Y.zs_ddot, Y.susp_travel, Y.F_tire_dyn (columns)

% 1) Constant current -> vector
%    (the passive baseline uses one fixed current, P.I_passive)
if isscalar(i_cmd)
    i_cmd = i_cmd*ones(size(t)); 
end

% 2) Simulation input: model, parameters, inputs, stop time, output logging
%    A SimulationInput makes each run self-contained: the model gets exactly
%    this P and these inputs, never a stale P left in the base workspace
%    (a real M2/M3 problem). Runs can also be repeated or run in parallel.
in = Simulink.SimulationInput('plant');
in = in.setVariable('P', P);                     % P reaches the model without the base workspace
in = in.setExternalInput([t(:) zr(:) i_cmd(:)]); % columns: time, In1 (z_r), In2 (i_cmd)
in = in.setModelParameter('StopTime', num2str(t(end)), 'SaveOutput', 'on', 'OutputSaveName', 'yout', 'SaveFormat', 'Dataset');

% 3) Run
out = sim(in);

% 4) Outputs in port order (zs_dot, zu_dot, zs_ddot, susp_travel, F_tire_dyn)
names = {'zs_dot', 'zu_dot', 'zs_ddot', 'susp_travel', 'F_tire_dyn'};
Y.t = out.yout{1}.Values.Time;
for k = 1:numel(names)
    Y.(names{k}) = out.yout{k}.Values.Data(:); 
end


end

function T = run_lag_sensitivity(vehicle)
%RUN_LAG_SENSITIVITY How much does the damper's actuator lag change the controller's benefit? (M6)
%   T = RUN_LAG_SENSITIVITY()          configured vehicle (PROJECT_CONFIG)
%   T = RUN_LAG_SENSITIVITY(vehicle)   named vehicle
%
%   Runs SC-C80 (class C, 80 km/h, 30 s, seed 1) in all four modes for three
%   actuator lags tau = 5, 10, 20 ms and writes
%     results/sensitivity/lag_sensitivity_<vehicle>.csv
%     results/sensitivity/lag_sensitivity_<vehicle>.png
%
%   Why this study: the controller computes a new current every 1 ms, but the
%   real damper valve needs time to follow (actuator lag, first order with time
%   constant tau, inside the plant). The value 10 ms is an assumption (P.tau,
%   setup_params); real valves need about 5-35 ms (REQ.md, [L10]). If the
%   benefit of a strategy depends strongly on tau, that is a limitation the
%   README must state. Expected: the slower the valve, the smaller the benefit,
%   because skyhook switches quickly between soft and firm.
%
%   Checks built in (TestSensitivity): the tau = 10 ms rows must equal the
%   committed M3 comparison exactly, since that is the same run.

% ---- 1) Parameters and output folder ----
if nargin < 1
    P0 = setup_params();
else
    P0 = setup_params(vehicle);
end
root = project_root();
outDir = fullfile(root, 'results', 'sensitivity');
if ~isfolder(outDir)
    mkdir(outDir);
end

% ---- 2) The study grid ----
% Lags in seconds: half, equal to and twice the assumed 10 ms.
taus = [0.005 0.010 0.020];
modes = [0 1 2 3];
modeNames = {'passive', 'skyhook', 'groundhook', 'hybrid'};
% The same road for every run: SC-C80, identical to run_comparison, so the
% tau = 10 ms rows can be compared with the committed M3 results.
[t, zr] = road_iso8608('C', 80, 30, 1);

% ---- 3) Run every lag in every mode ----
rows = cell(numel(taus)*numel(modes), 8);
k = 0;
for tau = taus
    % Work on a copy of the parameters: P0 stays untouched, and no file
    % (setup_params.m) is changed. Only the plant uses tau (Actuator_Lag block,
    % gain 1/P.tau), so the controller itself is the same in every run.
    P = P0;

    % TODO (you): uncomment the next line. It sets the actuator lag of this run.
    % Without it every run uses the default 10 ms and all three lags look the same.
    % P.tau = tau;

    for m = modes
        k = k + 1;
        fprintf('  tau = %2.0f ms, %-10s (%2d/%d)\n', 1e3*tau, modeNames{m+1}, k, size(rows, 1));

        % TODO (you): uncomment the next two lines. The first runs the closed
        % loop (plant + controller) in mode m; the second computes the KPIs
        % from it, exactly as in run_comparison.
        % Y = simulate_harness(P, t, zr, m);
        % K = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static);

        rows(k, :) = {1e3*tau, P.name, m, modeNames{m+1}, ...
            K.rms_zs_ddot, K.rms_F_tire_dyn, K.rms_F_tire_rel, K.max_travel_mm};
    end
end
T = cell2table(rows, 'VariableNames', {'tau_ms', 'vehicle', 'mode', 'mode_name', ...
    'rms_zs_ddot', 'rms_F_tire_dyn', 'rms_F_tire_rel', 'max_travel_mm'});

% ---- 4) Change vs passive at the SAME lag [%], negative = better ----
% Each controller is compared with passive under the same tau. (Passive uses
% one constant current, so the lag hardly matters for it; the comparison
% still uses its own lag to be fair.)
T.d_comfort_pct = zeros(height(T), 1);
T.d_tire_pct = zeros(height(T), 1);
T.d_travel_pct = zeros(height(T), 1);
for r = 1:height(T)
    p = T.tau_ms == T.tau_ms(r) & T.mode == 0;          % passive row of the same lag
    T.d_comfort_pct(r) = 100*(T.rms_zs_ddot(r)/T.rms_zs_ddot(p) - 1);
    T.d_tire_pct(r)    = 100*(T.rms_F_tire_dyn(r)/T.rms_F_tire_dyn(p) - 1);
    T.d_travel_pct(r)  = 100*(T.max_travel_mm(r)/T.max_travel_mm(p) - 1);
end

% ---- 5) Write the CSV (committed: the README numbers come from it) ----
writetable(T, fullfile(outDir, sprintf('lag_sensitivity_%s.csv', P0.name)));

% ---- 6) One plot: change vs passive over tau, one line per controller ----
% Left: comfort, right: road holding. A line that rises towards 0 with tau
% means the strategy loses its effect when the valve is slow.
f = figure('Visible', 'off', 'Position', [100 100 1000 420]);
tl = tiledlayout(f, 1, 2);
cols = lines(4);                                     % same colours as run_comparison
for j = 1:2
    nexttile; hold on
    for m = 1:3
        r = T.mode == m;
        if j == 1, y = T.d_comfort_pct(r); else, y = T.d_tire_pct(r); end
        plot(T.tau_ms(r), y, '-o', 'Color', cols(m+1, :), 'DisplayName', modeNames{m+1});
    end
    yline(0, 'k-', 'HandleVisibility', 'off'); hold off; grid on
    xlabel('Actuator lag \tau [ms]'); xticks(1e3*taus);
    if j == 1
        ylabel('\Delta RMS body acceleration vs passive [%]');
        title('Comfort (negative = better)');
    else
        ylabel('\Delta RMS dynamic tire load vs passive [%]');
        title('Road holding (negative = better)');
        legend('Location', 'best');
    end
end
title(tl, sprintf('Actuator-lag sensitivity, class C, 80 km/h, %s', strrep(P0.name, '_', '\_')));
exportgraphics(f, fullfile(outDir, sprintf('lag_sensitivity_%s.png', P0.name)));
close(f)

fprintf('Results in %s\n', outDir);
end

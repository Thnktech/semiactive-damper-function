function T = run_comparison(vehicle)
%RUN_COMPARISON Passive, skyhook, groundhook, hybrid on the baseline scenarios (M3).
%   T = RUN_COMPARISON()          configured vehicle (PROJECT_CONFIG)
%   T = RUN_COMPARISON(vehicle)   named vehicle
%   Same roads, seed, duration and bump as RUN_BASELINE; every mode sees identical inputs.
%   Writes results/comparison/kpi_comparison_<vehicle>.csv and 2 PNG plots.

% 1) Parameters and output folder (as in run_baseline)
if nargin < 1
    P = setup_params(); 
else
    P = setup_params(vehicle); 
end

root = project_root();
outDir = fullfile(root, 'results', 'comparison');
if ~isfolder(outDir)
    mkdir(outDir);
end

% 2) Scenarios: build ONE list, so every mode gets exactly the same roads
modes     = [0 1 2 3];
modeNames = {'passive', 'skyhook', 'groundhook', 'hybrid'};
classes = {'A', 'B', 'C', 'D'};  speeds = [50 80];  seed = 1;  Tsim = 30;
scen = struct('name', {}, 'cls', {}, 'v', {}, 't', {}, 'zr', {});


for c_idx = 1:numel(classes)
    c = classes{c_idx}; % Extracts 'A', 'B', etc.
    for v = speeds
        [t, zr] = road_iso8608(c, v, Tsim, seed);
        scen(end+1) = struct('name', sprintf('%s%d', c, v), 'cls', c, 'v', v, 't', t, 'zr', zr);
    end
end

% Bump
[tb, zb] = road_bump(0.05, 0.5, 18, 6, 2.5);
scen(end+1) = struct('name', 'BUMP', 'cls', '-', 'v', 18, 't', tb, 'zr', zb);

% 3) Run every scenario in every mode
Yc80 = cell(1, 4);
rows = {};
for s = 1:numel(scen)
    for m = modes
        Y = simulate_harness(P, scen(s).t, scen(s).zr, m);
        K = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static);
        rows(end+1, :) = {scen(s).name, P.name, m, modeNames{m+1}, scen(s).cls, scen(s).v, seed, K.rms_zs_ddot, K.rms_F_tire_dyn, K.rms_F_tire_rel, K.max_travel_mm};
        if strcmp(scen(s).name, 'C80')
            Yc80{m+1} = Y;
        end
    end
end

% 4) Table
T = cell2table(rows, 'VariableNames', {'scenario', 'vehicle', 'mode', 'mode_name', 'road_class', ...
              'speed_kmh', 'seed', 'rms_zs_ddot', 'rms_F_tire_dyn', 'rms_F_tire_rel', 'max_travel_mm'});

% 5) Change vs passive [%] for each row (passive row of the SAME scenario = reference)
T.d_comfort_pct = zeros(height(T), 1); 
T.d_tire_pct = zeros(height(T), 1); 
T.d_travel_pct = zeros(height(T), 1); 
for r = 1:height(T)
    p = strcmp(T.scenario, T.scenario{r}) & T.mode == 0;      % its passive row
    T.d_comfort_pct(r) = 100*(T.rms_zs_ddot(r)/T.rms_zs_ddot(p) - 1);
    T.d_tire_pct(r)    = 100*(T.rms_F_tire_dyn(r)/T.rms_F_tire_dyn(p) - 1);
    T.d_travel_pct(r)  = 100*(T.max_travel_mm(r)/T.max_travel_mm(p) - 1);
end
%    Negative = better than passive (less acceleration / tire load / travel).

% 6) Write CSV
writetable(T, fullfile(outDir, sprintf('kpi_comparison_%s.csv', P.name)));

% 7) Plots
cols = lines(4);                                   % one color per mode
% Plot 1: trade-off, controllers vs passive, all scenarios
f = figure('Visible', 'off'); hold on
for m = 1:3
    r = T.mode == m;
    scatter(T.d_comfort_pct(r), T.d_tire_pct(r), 40, cols(m+1, :), 'filled', 'DisplayName', modeNames{m+1});
end
xline(0, 'k-', 'HandleVisibility', 'off'); yline(0, 'k-', 'HandleVisibility', 'off'); hold off
xlabel('\Delta RMS body acceleration vs passive [%]  (negative = more comfort)');
ylabel('\Delta RMS dynamic tire load vs passive [%]  (negative = better grip)');
legend('Location', 'best'); grid on
title(sprintf('Comfort vs road holding, 9 scenarios, %s', strrep(P.name, '_', '\_')));
exportgraphics(f, fullfile(outDir, sprintf('comparison_tradeoff_%s.png', P.name))); close(f)

% Plot 2: C80, 10-13 s, body acceleration (all modes) and current (controllers)
f = figure('Visible', 'off'); tl = tiledlayout(f, 2, 1);
nexttile; hold on
for m = 0:3
    w = Yc80{m+1}.t >= 10 & Yc80{m+1}.t <= 13;
    plot(Yc80{m+1}.t(w), Yc80{m+1}.zs_ddot(w), 'Color', cols(m+1, :), 'DisplayName', modeNames{m+1});
end
hold off; ylabel('z_s'''' [m/s^2]'); legend('Location', 'eastoutside'); grid on
nexttile; hold on
for m = 1:3
    w = Yc80{m+1}.t >= 10 & Yc80{m+1}.t <= 13;
    plot(Yc80{m+1}.t(w), Yc80{m+1}.i_cmd(w), 'Color', cols(m+1, :), 'DisplayName', modeNames{m+1});
end
hold off; ylabel('i_{cmd} [A]'); legend('Location', 'eastoutside'); grid on
xlabel(tl, 'Time [s]'); title(tl, sprintf('Class C, 80 km/h, %s', strrep(P.name, '_', '\_')));
exportgraphics(f, fullfile(outDir, sprintf('comparison_C80_time_%s.png', P.name))); close(f)

end

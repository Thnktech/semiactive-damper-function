function T = run_baseline(vehicle)
%RUN_BASELINE Passive baseline: KPIs on roads A-D at 50/80 km/h and the
%bump (M2). - Run 9 passive scenarios
%   T = RUN_BASELINE()          configured vehicle (PROJECT_CONFIG)
%   T = RUN_BASELINE(vehicle)   named vehicle
%   Writes results/baseline/kpi_baseline_<vehicle>.csv and 3 PNG plots.
%   File names contain the vehicle name (D13; D21 keeps private ones out of git).

% 1) Parameters
if nargin < 1
    P = setup_params();
else
    P = setup_params(vehicle);
end

% 2) Output folder (repo root from the open project)
root = project_root();
outDir = fullfile(root, 'results', 'baseline');
if ~isfolder(outDir)
    mkdir(outDir);
end

% 3) Random-road scenarios
classes = {'A', 'B', 'C', 'D'};
speeds  = [50 80];
% Fixed seed and duration: the same roads in every run and in M3 (run_comparison),
% so every later 'x % better than passive' compares identical inputs.
% 30 s = SC-C80 definition (about 36 body-mode periods for a stable RMS).
seed = 1;  
Tsim = 30;
rows = {};
for c_idx = 1:numel(classes)
    c = classes{c_idx}; % Extracts 'A', 'B', etc.
    for v = speeds
        [t, zr] = road_iso8608(c, v, Tsim, seed);               % Create Road based on Class and Velocity
        % Passive = the plant alone with the fixed current I_passive, which gives
        % c_passive through the damper map (no controller yet in M2).
        Y = simulate_plant(P, t, zr, P.I_passive);              % Simulate plant with This Road and Velocity
        K = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static); % Extracts KPI from simulated plant
        rows(end+1, :) = {sprintf('%s%d', c, v), P.name, c, v, seed, K.rms_zs_ddot, K.rms_F_tire_dyn, K.rms_F_tire_rel, K.max_travel_mm}; %#ok<AGROW>
 
        if strcmp(c, 'C') && v == 80  % keep Y, t, zr for class C at 80 km/h (needed for plot 2)
            Yc = Y;  zc = zr;
        end
    end
end

% 4) Bump scenario
[tb, zb] = road_bump(0.05, 0.5, 18, 6, 2.5);   % SC-BUMP: 50 mm x 0.5 m half-sine at 18 km/h, bump at 2.5 s, 6 s run
Yb = simulate_plant(P, tb, zb, P.I_passive);   % passive plant on the bump
Kb = kpi(Yb.t, Yb.zs_ddot, Yb.F_tire_dyn, Yb.susp_travel, P.F_static);   % KPIs of the bump run
% No road class and no seed for the bump: it is deterministic (NaN = not used).
rows(end+1, :) = {'BUMP', P.name, '-', 18, NaN, Kb.rms_zs_ddot, Kb.rms_F_tire_dyn, Kb.rms_F_tire_rel, Kb.max_travel_mm};

% 5) Table -> CSV
T = cell2table(rows, 'VariableNames', {'scenario', 'vehicle', 'road_class','speed_kmh', 'seed', 'rms_zs_ddot', 'rms_F_tire_dyn', 'rms_F_tire_rel', 'max_travel_mm'});
writetable(T, fullfile(outDir, sprintf('kpi_baseline_%s.csv', P.name)));

% 6) Plots (invisible figures, so it also works in batch mode)
%    Plot 1: rms_zs_ddot per road class, one line per speed

f = figure('Visible', 'off');  
hold on
for v = speeds
    r = T.speed_kmh == v & ~strcmp(T.scenario, 'BUMP');
    plot(1:numel(classes), T.rms_zs_ddot(r), '-o', 'DisplayName', sprintf('%d km/h', v));
end
hold off
% Log scale: each road class doubles the road height, so the KPIs grow by
% about a constant factor per class and appear as straight lines.
set(gca, 'XTick', 1:numel(classes), 'XTickLabel', classes, 'YScale', 'log');
xlabel('ISO 8608-based road class'); ylabel('RMS body acceleration [m/s^2]');
legend('Location', 'northwest'); grid on
title(sprintf('Passive baseline, %s', strrep(P.name, '_', '\_')));
exportgraphics(f, fullfile(outDir, sprintf('baseline_kpi_by_class_%s.png', P.name)));
close(f)

%    Plot 2: class C, 80 km/h: three stacked subplots over time:
%            zr [mm], zs_ddot [m/s^2], F_tire_dyn [N]
% A new invisible figure per plot, exported and closed right away: each PNG
% then contains only its own plot (reusing one figure mixed plots in M2).
f = figure('Visible', 'off');
tl = tiledlayout(f, 3, 1);
nexttile; plot(Yc.t, 1000*zc);         ylabel('z_r [mm]'); grid on
nexttile; plot(Yc.t, Yc.zs_ddot);      ylabel('z_s'''' [m/s^2]'); grid on
nexttile; plot(Yc.t, Yc.F_tire_dyn);   ylabel('F_{tire,dyn} [N]'); grid on
xlabel(tl, 'Time [s]');
title(tl, sprintf('Passive, class C, 80 km/h, %s', strrep(P.name, '_', '\_')));
exportgraphics(f, fullfile(outDir, sprintf('baseline_C80_time_%s.png', P.name)));
close(f)

%    Plot 3: bump: zr [mm], susp_travel [mm], zs_ddot [m/s^2] over time
f = figure('Visible', 'off');
tl = tiledlayout(f, 3, 1);
nexttile; plot(Yb.t, 1000*zb);              ylabel('z_r [mm]'); grid on
nexttile; plot(Yb.t, 1000*Yb.susp_travel);  ylabel('z_s - z_u [mm]'); grid on
nexttile; plot(Yb.t, Yb.zs_ddot);           ylabel('z_s'''' [m/s^2]'); grid on
xlabel(tl, 'Time [s]');
title(tl, sprintf('Passive, bump 50 mm x 0.5 m, 18 km/h, %s', strrep(P.name, '_', '\_')));
exportgraphics(f, fullfile(outDir, sprintf('baseline_bump_%s.png', P.name)));
close(f)
end

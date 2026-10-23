function S = run_study(cfg)
%RUN_STUDY Run any set of roads with any set of control strategies and compare KPIs.
%   S = RUN_STUDY(cfg) runs every road in cfg.roads with every mode in cfg.modes
%   (passive is always added as the reference), computes the KPIs and their
%   change versus passive on the same road, and writes a CSV, a Markdown
%   summary and plots. Edit my_study.m instead of calling this directly.
%
%   cfg fields (defaults in brackets):
%     name          study name, used as output folder           ['study']
%     vehicle       vehicle name (GET_VEHICLE)                  [PROJECT_CONFIG vehicle]
%     modes         control modes to compare                    [1 2 3]
%     roads         cell array of road codes:                   [{'C80'}]
%                     'C80'    ISO 8608-based class C at 80 km/h (any class A-D, any speed)
%                     'BUMP'   SC-BUMP: 50 mm x 0.5 m half-sine at 18 km/h
%                     'BUMP30' same bump at 30 km/h
%     T             duration of random-road runs [s]            [30]
%     seed          road seed                                   [1]
%     timePlotRoads roads that also get a time-signal plot      [{}]
%     timeWindow    time window of those plots [s]              [[10 13]]
%     outDir        output folder        [results/studies/<name>, git-ignored]
%
%   S.T        table, one row per road and mode (absolute KPIs + d_*_pct vs passive)
%   S.signals  time signals per road and mode (struct array)
%   S.outDir   where the files were written
%   Output file names contain the vehicle name (D13; D21 keeps private ones out of git).

cfg = defaults(cfg);
P = setup_params(cfg.vehicle);
names = law_names();
modes = unique([0, cfg.modes(:)']);                    % passive always included, sorted
for m = modes
    if ~isKey(names, m)
        error('run_study:mode', 'Mode %d has no Law_%d_<Name> slot in controller.slx.', m, m);
    end
end
if ~isfolder(cfg.outDir), mkdir(cfg.outDir); end

% ---- roads (built once, so every mode sees identical inputs) ----
roads = struct('code', {}, 'cls', {}, 'v', {}, 't', {}, 'zr', {});
for r = 1:numel(cfg.roads)
    roads(end+1) = make_road(cfg.roads{r}, cfg); %#ok<AGROW>
end

% ---- runs ----
nRun = numel(roads)*numel(modes);
rows = cell(nRun, 10);
sig = struct('road', {}, 'mode', {}, 'name', {}, 'Y', {}, 'zr', {});
fprintf('run_study "%s": %d roads x %d modes = %d runs (%s)\n', cfg.name, numel(roads), numel(modes), nRun, P.name);
k = 0;
for r = 1:numel(roads)
    for m = modes
        k = k + 1;
        fprintf('  [%2d/%d] %-7s %s\n', k, nRun, roads(r).code, names(m));
        Y = simulate_harness(P, roads(r).t, roads(r).zr, m);
        K = kpi(Y.t, Y.zs_ddot, Y.F_tire_dyn, Y.susp_travel, P.F_static);
        rows(k, :) = {roads(r).code, P.name, m, names(m), roads(r).cls, roads(r).v, ...
            K.rms_zs_ddot, K.rms_F_tire_dyn, K.rms_F_tire_rel, K.max_travel_mm};
        sig(end+1) = struct('road', roads(r).code, 'mode', m, 'name', names(m), 'Y', Y, 'zr', roads(r).zr); %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'road', 'vehicle', 'mode', 'mode_name', 'road_class', ...
    'speed_kmh', 'rms_zs_ddot', 'rms_F_tire_dyn', 'rms_F_tire_rel', 'max_travel_mm'});

% ---- change vs passive on the same road [%] (negative = better) ----
T.d_comfort_pct = zeros(height(T), 1);
T.d_tire_pct = zeros(height(T), 1);
T.d_travel_pct = zeros(height(T), 1);
for i = 1:height(T)
    p = strcmp(T.road, T.road{i}) & T.mode == 0;
    T.d_comfort_pct(i) = 100*(T.rms_zs_ddot(i)/T.rms_zs_ddot(p) - 1);
    T.d_tire_pct(i)    = 100*(T.rms_F_tire_dyn(i)/T.rms_F_tire_dyn(p) - 1);
    T.d_travel_pct(i)  = 100*(T.max_travel_mm(i)/T.max_travel_mm(p) - 1);
end

% ---- files ----
tag = P.name;
writetable(T, fullfile(cfg.outDir, sprintf('kpi_%s.csv', tag)));
write_summary(T, cfg, P, fullfile(cfg.outDir, sprintf('summary_%s.md', tag)));
plot_deltas(T, modes, names, cfg, tag);
plot_tradeoff(T, modes, names, cfg, tag);
for r = 1:numel(cfg.timePlotRoads)
    plot_time(sig, cfg.timePlotRoads{r}, modes, cfg, tag);
end
fprintf('Results in %s\n', cfg.outDir);

S.T = T; S.signals = sig; S.outDir = cfg.outDir; S.cfg = cfg;
end

% =====================================================================
function cfg = defaults(cfg)
if nargin < 1 || isempty(cfg), cfg = struct(); end
d = struct('name', 'study', 'vehicle', getfield(project_config(), 'vehicle'), 'modes', [1 2 3], ...
    'roads', {{'C80'}}, 'T', 30, 'seed', 1, 'timePlotRoads', {{}}, 'timeWindow', [10 13], 'outDir', '');
for f = fieldnames(d)'
    if ~isfield(cfg, f{1}) || (isempty(cfg.(f{1})) && ~strcmp(f{1}, 'timePlotRoads'))
        cfg.(f{1}) = d.(f{1});
    end
end
if ischar(cfg.roads), cfg.roads = {cfg.roads}; end
if ischar(cfg.timePlotRoads), cfg.timePlotRoads = {cfg.timePlotRoads}; end
if isempty(cfg.outDir)
    cfg.outDir = fullfile(project_root(), 'results', 'studies', cfg.name);
end
end

function road = make_road(code, cfg)
code = upper(strtrim(code));
tokR = regexp(code, '^([A-D])(\d+)$', 'tokens', 'once');
tokB = regexp(code, '^BUMP(\d*)$', 'tokens', 'once');
if ~isempty(tokR)
    v = str2double(tokR{2});
    [t, zr] = road_iso8608(tokR{1}, v, cfg.T, cfg.seed);
    road = struct('code', code, 'cls', tokR{1}, 'v', v, 't', t, 'zr', zr);
elseif ~isempty(tokB)
    v = 18;
    if ~isempty(tokB{1}), v = str2double(tokB{1}); end
    [t, zr] = road_bump(0.05, 0.5, v, 6, 2.5);
    road = struct('code', code, 'cls', '-', 'v', v, 't', t, 'zr', zr);
else
    error('run_study:road', 'Unknown road code "%s". Use e.g. ''C80'', ''A50'', ''BUMP'', ''BUMP30''.', code);
end
end

function write_summary(T, cfg, P, file)
fid = fopen(file, 'w'); c = onCleanup(@() fclose(fid));
fprintf(fid, '# Study: %s\n\nVehicle `%s` · random roads %g s, seed %d · KPIs: RMS over t >= 2 s, travel over the whole run.\n', ...
    cfg.name, P.name, cfg.T, cfg.seed);
fprintf(fid, 'Change vs passive on the same road; negative = better.\n\n');
fprintf(fid, '| Road | Strategy | RMS z̈s [m/s²] | Δ comfort | RMS ΔF tire [N] | Δ tire load | Max travel [mm] | Δ travel |\n');
fprintf(fid, '|---|---|---|---|---|---|---|---|\n');
for i = 1:height(T)
    fprintf(fid, '| %s | %s | %.3f | %+.1f %% | %.0f | %+.1f %% | %.1f | %+.1f %% |\n', T.road{i}, T.mode_name{i}, ...
        T.rms_zs_ddot(i), T.d_comfort_pct(i), T.rms_F_tire_dyn(i), T.d_tire_pct(i), T.max_travel_mm(i), T.d_travel_pct(i));
end
end

function plot_deltas(T, modes, names, cfg, tag)
ctrl = modes(modes ~= 0);
if isempty(ctrl), return; end
roads = unique(T.road, 'stable');
f = figure('Visible', 'off', 'Position', [100 100 1100 800]);
tl = tiledlayout(f, 3, 1);
kp = {'d_comfort_pct', 'd_tire_pct', 'd_travel_pct'};
lab = {'\Delta comfort [%]', '\Delta tire load [%]', '\Delta travel [%]'};
for j = 1:3
    nexttile; D = zeros(numel(roads), numel(ctrl));
    for r = 1:numel(roads)
        for m = 1:numel(ctrl)
            D(r, m) = T.(kp{j})(strcmp(T.road, roads{r}) & T.mode == ctrl(m));
        end
    end
    bar(categorical(roads, roads), D); yline(0, 'k-'); grid on; ylabel(lab{j});
    if j == 1, legend(arrayfun(@(m) names(m), ctrl, 'UniformOutput', false), 'Location', 'eastoutside'); end
end
title(tl, sprintf('%s: change vs passive (negative = better), %s', strrep(cfg.name, '_', '\_'), strrep(tag, '_', '\_')));
exportgraphics(f, fullfile(cfg.outDir, sprintf('delta_bars_%s.png', tag))); close(f);
end

function plot_tradeoff(T, modes, names, cfg, tag)
ctrl = modes(modes ~= 0);
if isempty(ctrl), return; end
f = figure('Visible', 'off'); hold on
col = lines(max(modes) + 1);
for m = ctrl
    r = T.mode == m;
    scatter(T.d_comfort_pct(r), T.d_tire_pct(r), 40, col(m+1, :), 'filled', 'DisplayName', names(m));
end
xline(0, 'k-', 'HandleVisibility', 'off'); yline(0, 'k-', 'HandleVisibility', 'off'); hold off; grid on
xlabel('\Delta RMS body acceleration vs passive [%]'); ylabel('\Delta RMS dynamic tire load vs passive [%]');
legend('Location', 'best');
title(sprintf('%s: comfort vs road holding (lower-left = better in both)', strrep(cfg.name, '_', '\_')));
exportgraphics(f, fullfile(cfg.outDir, sprintf('tradeoff_%s.png', tag))); close(f);
end

function plot_time(sig, road, modes, cfg, tag)
road = upper(road);
s = sig(strcmp({sig.road}, road));
if isempty(s), warning('run_study:timePlot', 'Time plot road %s is not in cfg.roads.', road); return; end
f = figure('Visible', 'off', 'Position', [100 100 1100 800]);
tl = tiledlayout(f, 3, 1);
col = lines(max(modes) + 1);
w = s(1).Y.t >= cfg.timeWindow(1) & s(1).Y.t <= cfg.timeWindow(2);
if ~any(w), w = true(size(s(1).Y.t)); end                 % short runs (bump): whole run
nexttile; plot(s(1).Y.t(w), 1000*s(1).zr(w), 'k'); ylabel('z_r [mm]'); grid on
nexttile; hold on
for i = 1:numel(s)
    plot(s(i).Y.t(w), s(i).Y.zs_ddot(w), 'Color', col(s(i).mode+1, :), 'DisplayName', s(i).name);
end
hold off; ylabel('z_s'''' [m/s^2]'); grid on; legend('Location', 'eastoutside')
nexttile; hold on
for i = 1:numel(s)
    plot(s(i).Y.t(w), s(i).Y.i_cmd(w), 'Color', col(s(i).mode+1, :), 'DisplayName', s(i).name);
end
hold off; ylabel('i_{cmd} [A]'); grid on; legend('Location', 'eastoutside')
xlabel(tl, 'Time [s]'); title(tl, sprintf('%s, road %s, %s', strrep(cfg.name, '_', '\_'), road, strrep(tag, '_', '\_')));
exportgraphics(f, fullfile(cfg.outDir, sprintf('time_%s_%s.png', road, tag))); close(f);
end

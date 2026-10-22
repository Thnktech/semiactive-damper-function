%MY_STUDY Your study: choose roads and control strategies, then run this script.
%   Only edit the block below. Results go to results/studies/<name>/ (git-ignored):
%   kpi_<vehicle>.csv, summary_<vehicle>.md, delta_bars, tradeoff and time plots.
%   Passive is always added as the reference.

% ===================== EDIT HERE =====================
cfg.name    = 'my_study';             % output folder name
cfg.vehicle = 'sedan_ref';            % 'sedan_ref', 'small_car', 'suv', 'light_van' (or private 'erod_front', 'erod_rear')
cfg.modes   = [1 3];                  % 1 skyhook, 2 groundhook, 3 hybrid, 4... your own Law_<n>_ slots
cfg.roads   = {'C50', 'C80', 'D80', 'BUMP'};   % class A-D + speed (any), 'BUMP' (18 km/h), 'BUMP30', ...
cfg.T       = 30;                     % random-road duration [s] (KPIs use t >= 2 s)
cfg.seed    = 1;                      % same seed = same road for every strategy
cfg.timePlotRoads = {'C80', 'BUMP'};  % roads that also get a time-signal plot ({} = none)
cfg.timeWindow    = [10 13];          % time window of those plots [s] (bump: whole run)
% =====================================================

S = run_study(cfg);
disp(S.T(:, {'road', 'mode_name', 'rms_zs_ddot', 'd_comfort_pct', 'd_tire_pct', 'd_travel_pct'}))

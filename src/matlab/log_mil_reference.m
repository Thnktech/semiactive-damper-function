function files = log_mil_reference(scenarios, varargin)
%LOG_MIL_REFERENCE Log controller I/O from the MiL harness as reference data for M5.
%   files = LOG_MIL_REFERENCE() logs SC-C80, SC-BUMP and SC-FAULT.
%   files = LOG_MIL_REFERENCE(scenarios) logs the named scenarios.
%   files = LOG_MIL_REFERENCE(..., 'AllowDirty', true) logs from uncommitted
%   code (for trying out only; such logs must not be committed).
%
%   Writes tests/data/mil_<scenario>.csv (columns t, zs_dot, zu_dot,
%   fault_flag, mode, i_cmd, fault_active; one row per 1 ms step from t = 0;
%   '%.17g') and mil_<scenario>.json (metadata, REQ-V-02).
%   Rules: docs/mil_to_sil.md sections 2-4. Reference vehicle only (D12, D21).

if nargin < 1 || isempty(scenarios), scenarios = {'SC-C80', 'SC-BUMP', 'SC-FAULT'}; end
if ischar(scenarios), scenarios = {scenarios}; end
opt = struct('AllowDirty', false);
for k = 1:2:numel(varargin), opt.(varargin{k}) = varargin{k+1}; end

root = project_root();
cfg = project_config();
P = setup_params(cfg.vehicle);
if ~strcmp(P.label, 'published')
    error('log_mil:vehicle', 'Reference logs use the published reference vehicle only, not "%s" (D21).', P.name);
end
[commit, dirty] = git_state(root);
if dirty && ~opt.AllowDirty
    error('log_mil:dirty', ['Working tree has uncommitted changes: commit first, so the logged git hash ' ...
        'identifies the model that produced the data (REQ-V-02, mil_to_sil.md 5.1).']);
end
outDir = fullfile(root, 'tests', 'data');
if ~isfolder(outDir), mkdir(outDir); end

files = {};
for s = 1:numel(scenarios)
    sc = define(scenarios{s});
    Y = simulate_harness(P, sc.t, sc.zr, sc.mode, sc.fault);
    D = [Y.t, Y.zs_dot, Y.zu_dot, Y.fault_flag, Y.mode, Y.i_cmd, Y.fault_active];
    cols = {'t', 'zs_dot', 'zu_dot', 'fault_flag', 'mode', 'i_cmd', 'fault_active'};

    csvFile = fullfile(outDir, sprintf('mil_%s.csv', sc.id));
    fid = fopen(csvFile, 'w');
    fprintf(fid, '%s\n', strjoin(cols, ','));
    fprintf(fid, [strjoin(repmat({'%.17g'}, 1, numel(cols)), ',') '\n'], D');
    fclose(fid);

    meta = struct( ...
        'scenario', sc.id, 'description', sc.description, ...
        'vehicle', P.name, 'road', sc.road, 'mode_schedule', sc.modeText, 'fault', sc.faultText, ...
        'git_commit', commit, 'git_dirty', dirty, ...
        'model', 'controller', 'harness', 'harness', 'plant', 'plant', ...
        'sample_time_s', 1e-3, 'rows', size(D, 1), 'columns', {cols}, 'number_format', '%.17g', ...
        'matlab_release', version('-release'), 'simulink_version', ver('simulink').Version, ...
        'generated', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
        'rules', 'docs/mil_to_sil.md; REQ-V-01, REQ-V-02; D7, D19');
    jsonFile = fullfile(outDir, sprintf('mil_%s.json', sc.id));
    fid = fopen(jsonFile, 'w');
    fprintf(fid, '%s\n', jsonencode(meta, 'PrettyPrint', true));
    fclose(fid);

    fprintf('%-9s %6d rows -> %s\n', sc.id, size(D, 1), csvFile);
    files(end+1, :) = {csvFile, jsonFile}; %#ok<AGROW>
end
end

% ---------------------------------------------------------------------
function sc = define(id)
sc.id = id;
switch id
    case 'SC-C80'
        [t, zr] = road_iso8608('C', 80, 10, 1);
        m = ones(size(t));
        m(t >= 2) = 2; m(t >= 4) = 3; m(t >= 6) = 7; m(t >= 7) = 0; m(t >= 8) = 1.5; m(t >= 9) = 1;
        sc.description = 'Class C, 80 km/h; every law slot, invalid modes 7 and 1.5, mode changes';
        sc.road = struct('type', 'iso8608', 'class', 'C', 'speed_kmh', 80, 'seed', 1, 'duration_s', 10);
        sc.modeText = '1 [0,2) 2 [2,4) 3 [4,6) 7 [6,7) 0 [7,8) 1.5 [8,9) 1 [9,10]';
        f = zeros(size(t)); sc.faultText = 'none';
    case 'SC-BUMP'
        [t, zr] = road_bump(0.05, 0.5, 18, 6, 2.5);
        m = ones(size(t)); m(t >= 4) = 3;
        sc.description = 'SC-BUMP: half-sine 50 mm x 0.5 m at 18 km/h, bump at 2.5 s; skyhook then hybrid';
        sc.road = struct('type', 'bump', 'height_m', 0.05, 'length_m', 0.5, 'speed_kmh', 18, 't0_s', 2.5, 'duration_s', 6);
        sc.modeText = '1 [0,4) 3 [4,6]';
        f = zeros(size(t)); sc.faultText = 'none';
    case 'SC-FAULT'
        [t, zr] = road_iso8608('C', 80, 10, 1);
        m = 3*ones(size(t)); m(t >= 7) = 1;
        k = round(t*1000);
        f = double(k == 4000 | (k >= 6000 & mod(floor((k - 6000)/100), 2) == 0));
        sc.description = 'Class C, 80 km/h, hybrid; one-sample fault pulse at 4 s, toggling from 6 s; mode change to skyhook at 7 s (must be ignored)';
        sc.road = struct('type', 'iso8608', 'class', 'C', 'speed_kmh', 80, 'seed', 1, 'duration_s', 10);
        sc.modeText = '3 [0,7) 1 [7,10]';
        sc.faultText = 'pulse at 4.000 s (1 sample); toggling 1/0 every 100 ms from 6 s';
    otherwise
        error('log_mil:scenario', 'Unknown scenario "%s" (SC-C80, SC-BUMP, SC-FAULT).', id);
end
sc.t = t; sc.zr = zr; sc.mode = m; sc.fault = f;
end

function [commit, dirty] = git_state(root)
[s1, commit] = system(sprintf('git -C "%s" rev-parse HEAD', root));
[s2, st] = system(sprintf('git -C "%s" status --porcelain', root));
if s1 ~= 0 || s2 ~= 0
    error('log_mil:git', 'git is not available: %s', strtrim(commit));
end
commit = strtrim(commit);
dirty = ~isempty(strtrim(st));
end

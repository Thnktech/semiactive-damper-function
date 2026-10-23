function info = generate_controller_code(varargin)
%GENERATE_CONTROLLER_CODE Generate C code of controller.slx for the back-to-back test (M5).
%   info = GENERATE_CONTROLLER_CODE() generates Simulink Coder (GRT) C code of
%   the controller, packs it with packNGo and unpacks it into
%   src/generated/controller/, together with a provenance record:
%     src/generated/controller/provenance.json   (read by the Python tests)
%     src/generated/controller/README.md         (the same, for people)
%   info = GENERATE_CONTROLLER_CODE('AllowDirty', true) also runs with
%   uncommitted changes (for trying out only).
%
%   The folder src/generated/controller/ is git-ignored: the generated files
%   carry the MathWorks academic license banner, so they stay local (D10 rev.
%   2026-10-24). CI checks the committed local result instead
%   (results/back_to_back.json, written by run_tests).
%
%   The code-generation settings are applied by this script to the model in
%   memory and the model is closed WITHOUT saving (D27): controller.slx on
%   disk never changes, so the MiL logs keep pointing to the right commit.
%
%   Parameters: the controller reads 25 block parameters from the struct P
%   (c_min, c_sky, I_default, ...). Their values for the reference vehicle are
%   written into the generated code, the same vehicle as the MiL logs (D12).
%
%   Afterwards: run_tests() builds the code, replays the MiL logs through it
%   and records the result (by hand: python src/python/build_controller.py,
%   python src/python/back_to_back.py, pytest -q tests/python).
%   Rules: docs/mil_to_sil.md; REQ-V-01; D7, D10, D19, D27, D28.

opt = struct('AllowDirty', false);
for k = 1:2:numel(varargin)
    opt.(varargin{k}) = varargin{k+1};
end

mdl    = 'controller';
root   = project_root();
outDir = fullfile(root, 'src', 'generated', 'controller');

% --- 1. Preconditions: reference vehicle, committed code ---
% The generated code must belong to one commit, exactly like the MiL logs.
cfg = project_config();
P = setup_params(cfg.vehicle);
if ~strcmp(P.label, 'published')
    error('gen_code:vehicle', 'Code is generated for the published reference vehicle only, not "%s" (D21).', P.name);
end
[commit, dirty] = git_state(root);
if dirty && ~opt.AllowDirty
    error('gen_code:dirty', ['Working tree has uncommitted changes: commit first, so the recorded git ' ...
        'hash identifies the model the code was generated from.']);
end

% --- 2. P in the base workspace, restored afterwards ---
% The blocks look for P in the base workspace. A P left behind from a
% different vehicle would silently end up in the code, so this run puts the
% reference P there and gives back whatever was there before.
% (No nested function in the cleanup handle: it would keep the cleanup
% object itself alive, and the restore would never run.)
hadP = evalin('base', 'exist(''P'', ''var'')') == 1;
oldP = [];
if hadP
    oldP = evalin('base', 'P');
end
assignin('base', 'P', P);
restoreP = onCleanup(@() restoreBaseP(hadP, oldP));   % runs also on error

% --- 3. Build in a temporary folder ---
% slbuild writes controller_grt_rtw/ and slprj/ into the code-generation
% folder. A temporary folder keeps the repository clean; only the packed
% sources are copied into src/generated/controller/.
tmp = tempname;
mkdir(tmp);
Simulink.fileGenControl('set', 'CodeGenFolder', tmp, 'CacheFolder', tmp);
resetFolders = onCleanup(@() Simulink.fileGenControl('reset'));

% --- 4. Code-generation settings: in memory only (D27) ---
% close_system(mdl, 0) closes without saving, also if anything below fails.
load_system(mdl);
closeModel = onCleanup(@() close_system(mdl, 0));
settings = struct( ...
    'SystemTargetFile',       'grt.tlc', ...              % generic real-time target, no Embedded Coder
    'GenCodeOnly',            'on', ...                   % C sources only; gcc builds them outside MATLAB
    'MatFileLogging',         'off', ...                  % no MAT-file logging runtime in the code
    'CodeInterfacePackaging', 'Nonreusable function', ... % global I/O structs controller_U / controller_Y
    'GenerateReport',         'off', ...
    'RTWVerbose',             'off');
names = fieldnames(settings);
for k = 1:numel(names)
    set_param(mdl, names{k}, settings.(names{k}));
end
% Settings that are already right and must stay so (checked, not changed)
must = struct('SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', 'FixedStep', '0.001', ...
    'TargetLang', 'C', 'CombineOutputUpdateFcns', 'on', 'DefaultParameterBehavior', 'Tunable');
names = fieldnames(must);
for k = 1:numel(names)
    actual = get_param(mdl, names{k});
    if ~strcmp(actual, must.(names{k}))
        error('gen_code:setting', '%s is "%s", expected "%s".', names{k}, actual, must.(names{k}));
    end
end

% --- 5. Generate and pack ---
slbuild(mdl);
bi = load(fullfile(tmp, [mdl '_grt_rtw'], 'buildInfo.mat'));
zipFile = fullfile(tmp, 'controller_code.zip');
packNGo(bi.buildInfo, 'packType', 'flat', 'fileName', zipFile);

% --- 6. Replace the local sources ---
% Old files are removed first, so a file the new code no longer needs cannot
% stay behind and be compiled by mistake.
if isfolder(outDir)
    rmdir(outDir, 's');
end
mkdir(outDir);
unzip(zipFile, outDir);
% packNGo also packs buildInfo.mat: binary, with absolute paths of this PC,
% not needed for building. Not committed.
if isfile(fullfile(outDir, 'buildInfo.mat'))
    delete(fullfile(outDir, 'buildInfo.mat'));
end
src = dir(fullfile(outDir, '*.c'));
hdr = dir(fullfile(outDir, '*.h'));
withMain = {};
for k = 1:numel(src)
    if ~isempty(regexp(fileread(fullfile(outDir, src(k).name)), '\<int\s+main\s*\(', 'once'))
        withMain{end+1} = src(k).name; %#ok<AGROW>
    end
end

% --- 7. Provenance ---
% sources: SHA-256 of the files that determine the code. A Python test
% compares them with the checked-out files: if controller.slx or the
% parameters change without regenerating, the test fails.
inputs = {'model/controller/controller.slx', 'src/matlab/setup_params.m', ...
    ['src/matlab/vehicles/' cfg.vehicle '.m']};
hashes = struct('path', inputs, 'sha256', '');
for k = 1:numel(inputs)
    hashes(k).sha256 = sha256(fullfile(root, inputs{k}));
end
info = struct( ...
    'model', mdl, 'vehicle', P.name, ...
    'git_commit', commit, 'git_dirty', dirty, ...
    'matlab_release', version('-release'), ...
    'simulink_coder_version', ver('simulinkcoder').Version, ...
    'generated', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
    'settings', settings, ...
    'c_files', {sort({src.name})}, 'h_files', {sort({hdr.name})}, ...
    'files_with_main', {withMain}, ...
    'sources', hashes, ...
    'rules', 'docs/mil_to_sil.md; REQ-V-01; D7, D19, D27');
fid = fopen(fullfile(outDir, 'provenance.json'), 'w');
fprintf(fid, '%s\n', jsonencode(info, 'PrettyPrint', true));
fclose(fid);
writeReadme(fullfile(outDir, 'README.md'), info);

fprintf('Generated %d .c / %d .h files -> %s\n', numel(src), numel(hdr), outDir);
if ~isempty(withMain)
    fprintf('Files with main() (not compiled): %s\n', strjoin(withMain, ', '));
end
fprintf('Next: python src/python/build_controller.py\n');
end

% ---------------------------------------------------------------------
function restoreBaseP(hadP, oldP)
if hadP
    assignin('base', 'P', oldP);
else
    evalin('base', 'clear P');
end
end

function h = sha256(file)
% SHA-256 of a file's bytes, as lowercase hex (same as Python hashlib).
% Text files are hashed without carriage returns (CR, byte 13), so a
% Windows (CRLF) and a Linux (LF) checkout give the same hash. .slx is
% binary and hashed as is. tests/python/test_back_to_back.py does the same.
fid = fopen(file, 'r');
if fid < 0
    error('gen_code:hash', 'Cannot read %s', file);
end
bytes = fread(fid, inf, '*uint8');
fclose(fid);
[~, ~, ext] = fileparts(file);
if ~strcmpi(ext, '.slx')
    bytes(bytes == 13) = [];
end
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
d = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(d, 2)', 1, []));
end

function [commit, dirty] = git_state(root)
[s1, commit] = system(sprintf('git -C "%s" rev-parse HEAD', root));
[s2, st] = system(sprintf('git -C "%s" status --porcelain', root));
if s1 ~= 0 || s2 ~= 0
    error('gen_code:git', 'git is not available: %s', strtrim(commit));
end
commit = strtrim(commit);
dirty = ~isempty(strtrim(st));
end

function s = listOrDash(c)
if isempty(c)
    s = '-';
else
    s = strjoin(c, ', ');
end
end

function writeReadme(file, info)
% Human-readable copy of the provenance; written with '%s\n' only, so no
% text is ever interpreted as a format.
s = info.settings;
L = {
    '# src/generated/controller (local only, git-ignored)'
    ''
    'Simulink Coder (GRT) C code of `model/controller/controller.slx`, packed with `packNGo`.'
    '**Generated - do not edit.** Regenerate with `generate_controller_code()` in MATLAB.'
    'Not committed: the files carry the MathWorks academic license banner (D10 rev. 2026-10-24).'
    ''
    '| Item | Value |'
    '|---|---|'
    sprintf('| Model | `%s` |', info.model)
    sprintf('| Vehicle (parameters in the code) | `%s` |', info.vehicle)
    sprintf('| Model git commit | `%s` |', info.git_commit)
    sprintf('| MATLAB release | %s (Simulink Coder %s) |', info.matlab_release, info.simulink_coder_version)
    sprintf('| Generated (UTC) | %s |', info.generated)
    sprintf('| Target | `%s`, %s, MatFileLogging %s, GenCodeOnly %s |', s.SystemTargetFile, ...
        s.CodeInterfacePackaging, s.MatFileLogging, s.GenCodeOnly)
    sprintf('| C files | %s |', strjoin(info.c_files, ', '))
    sprintf('| Not compiled (contain `main`) | %s |', listOrDash(info.files_with_main))
    ''
    'Settings are applied by the script to the model in memory; `controller.slx` is not saved (D27).'
    'Machine-readable record incl. SHA-256 of the source files: `provenance.json` (this folder).'
    ''
    'Build: `python src/python/build_controller.py` (gcc, `-O2 -ffp-contract=off`).'
    'Replay + record: `python src/python/back_to_back.py` -> `results/back_to_back.json` (committed).'
    'Test: `pytest -q tests/python` (REQ-V-01 generated-code back-to-back against `tests/data/mil_SC-*.csv`).'
    };
fid = fopen(file, 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', L{:});
fclose(fid);
end

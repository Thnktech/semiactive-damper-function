function R = run_tests(mode)
%RUN_TESTS Run all tests and write the traceability report (M4).
%   R = RUN_TESTS() runs every MATLAB test (KnownFail included) and the pytest
%   suite, exports JUnit XML to results/test/ and writes results/traceability.md.
%   R = RUN_TESTS('dev') runs the MATLAB tests without KnownFail; no report.
%   R is a table with one row per requirement and its verdict ('dev': the
%   MATLAB test results).
%
%   How a test is linked to a requirement:
%     - MATLAB test: it carries the tag, e.g. TestTags = {'REQ-S-01'}
%     - pytest test: its name contains the ID with '_', e.g. test_REQ_V_02_...
%   Measured values come from record_evidence calls inside the tests.
%   The verdict rules are in judge() below.

if nargin < 1
    mode = 'all';
end
dev    = strcmp(mode, 'dev');
root   = matlab.project.rootProject().RootFolder;
outDir = fullfile(root, 'results', 'test');

% Commit of the code under test, read before the tests run. '-dirty' means
% uncommitted changes, so the report does not belong to that commit exactly.
commit = gitVersion(root);

% --- 1. Output folder and evidence file ---
% Every record_evidence call in a test appends one line to the file named by
% EVIDENCE_FILE. Delete the old file so this run starts empty.
if ~isfolder(outDir)
    mkdir(outDir);
end
evFile = fullfile(outDir, 'evidence.jsonl');
if isfile(evFile)
    delete(evFile);
end
setenv('EVIDENCE_FILE', evFile);
resetEnv = onCleanup(@() setenv('EVIDENCE_FILE', ''));   % also runs on error or Ctrl+C

% --- 2. MATLAB tests ---
suite = testsuite(fullfile(root, 'tests', 'matlab'));
if dev
    suite = suite.selectIf(~matlab.unittest.selectors.HasTag('KnownFail'));
end
runner = testrunner('textoutput');
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat( ...
    fullfile(outDir, 'matlab_junit.xml')));
res = runner.run(suite);            % res(k) is the result of suite(k): same order
if dev
    disp(res);
    R = res;
    return
end

% --- 3. Python tests ---
% pytest runs in the project's virtual environment and writes its own JUnit
% XML. A non-zero exit status only means that a test failed; the verdicts
% handle that, so the script does not stop here.
pyXml = fullfile(outDir, 'pytest_junit.xml');
if isfile(pyXml)
    delete(pyXml);
end
if ispc
    python = fullfile('.venv', 'Scripts', 'python.exe');
    cdCmd  = 'cd /d';
else
    python = fullfile('.venv', 'bin', 'python');
    cdCmd  = 'cd';
end
% The command starts with cd, not with a quote: Windows cmd would otherwise
% strip the first and last quote of the line and break the paths.
[~, out] = system(sprintf('%s "%s" && %s -m pytest -q tests/python --junitxml="%s"', ...
    cdCmd, root, python, pyXml));
fprintf('%s\n', out);
if ~isfile(pyXml)
    error('run_tests:pytest', 'pytest wrote no report. Is .venv set up?\n%s', out);
end
py = readPytest(pyXml);

% --- 4. Requirements, evidence, verdicts ---
req = readRequirements(fullfile(root, 'requirements', 'REQ.md'));
ev  = readEvidence(evFile);
for i = 1:numel(req)
    [req(i).tests, req(i).verdict, req(i).measured] = judge(req(i).id, suite, res, py, ev);
end
R = struct2table(rmfield(req(:), {'acceptance', 'tests'}));

% --- 5. Report ---
writeReport(fullfile(root, 'results', 'traceability.md'), req, commit);
v = R.verdict;
fprintf('\nTraceability: %d Pass, %d Fail (%d known), %d Unverified -> results/traceability.md\n', ...
    sum(strcmp(v, 'Pass')), sum(startsWith(v, 'Fail')), sum(strcmp(v, 'Fail (known)')), ...
    sum(strcmp(v, 'Unverified')));
disp(R(:, {'id', 'title', 'verdict'}));

% A failure that is not tagged KnownFail is new: say so loudly
isKnown = arrayfun(@(s) any(strcmp(s.Tags, 'KnownFail')), suite);
newFail = [{suite([res.Failed] & ~isKnown).Name}, {py([py.failed]).name}];
if ~isempty(newFail)
    warning('run_tests:fail', 'Unexpected failures (not tagged KnownFail)\n  %s', strjoin(newFail, '\n  '));
end
end

function commit = gitVersion(root)
% Short commit hash, with '-dirty' if tracked files have uncommitted changes.
% The report itself is excluded: rewriting it must not mark the next run dirty.
[~, commit] = system(sprintf('git -C "%s" rev-parse --short HEAD', root));
[~, dirty]  = system(sprintf('git -C "%s" status --porcelain --untracked-files=no -- . ":(exclude)results/traceability.md"', root));
commit = strtrim(commit);
if ~isempty(strtrim(dirty))
    commit = [commit '-dirty'];
end
end

function py = readPytest(xmlFile)
% Struct array (name, failed, skipped), one element per pytest test case.
% A JUnit test case looks like
%   <testcase classname="..." name="test_x" time="0.01" />           passed
%   <testcase classname="..." name="test_y" ...><failure .../></testcase>
% Token 1 is the name: '\s' before 'name' so 'classname' does not match.
% Token 2 is either '/>' (passed, no body) or the body up to </testcase>.
txt = fileread(xmlFile);
% (In MATLAB regexp '\b' is a backspace, not a word boundary: do not use it.)
tok = regexp(txt, '<testcase[^>]*?\sname="([^"]*)"[^>]*?(/>|>.*?</testcase>)', 'tokens');
py  = struct('name', {}, 'failed', {}, 'skipped', {});
for k = 1:numel(tok)
    body = tok{k}{2};
    py(k).name    = tok{k}{1};
    py(k).failed  = contains(body, {'<failure', '<error'});
    py(k).skipped = contains(body, '<skipped');
end
end

function req = readRequirements(mdFile)
% Struct array (id, title, acceptance) from every table row starting '| REQ-'.
% Columns: ID | Title | Statement | Rationale | Verification | Acceptance | Evidence | Status
% Some cells contain an escaped pipe '\|' (e.g. |i_cmd(k) - i_cmd(k-1)| in
% REQ-F-04), so split only on pipes without a backslash in front. The row
% starts and ends with '|', so c{1} and c{end} are empty and the ID is c{2}.
lines = readlines(mdFile, 'Encoding', 'UTF-8');
rows  = lines(startsWith(lines, '| REQ-'));
req   = struct('id', {}, 'title', {}, 'acceptance', {}, 'tests', {}, 'verdict', {}, 'measured', {});
for i = 1:numel(rows)
    c = strtrim(regexp(char(rows(i)), '(?<!\\)\|', 'split'));
    if numel(c) ~= 10
        error('run_tests:req', 'Expected 8 columns in this REQ.md row\n%s', rows(i));
    end
    req(i).id         = c{2};
    req(i).title      = c{3};
    req(i).acceptance = c{7};
end
end

function ev = readEvidence(evFile)
% Struct array of the JSON lines written by record_evidence; empty if none.
% One line: {"req":"REQ-S-01","test":"...","quantity":"...","value":5,"unit":"ms"}
ev = struct('req', {}, 'test', {}, 'quantity', {}, 'value', {}, 'unit', {});
if ~isfile(evFile)
    return
end
L = readlines(evFile, 'Encoding', 'UTF-8');
L = L(strlength(L) > 0);
for k = 1:numel(L)
    ev(k) = jsondecode(char(L(k)));
end
end

function [tests, verdict, measured] = judge(id, suite, res, py, ev)
% Names of the tests carrying requirement id, its verdict, its measured values.
%   no test                          -> Unverified (e.g. REQ-V-01 until M5)
%   any test failed                  -> Fail, or 'Fail (known)' if every failed
%                                       test is a MATLAB test tagged KnownFail
%   any incomplete/skipped, no fail  -> Unverified (not proven either way)
%   all passed                       -> Pass

% Tests that belong to this requirement
inM   = arrayfun(@(s) any(strcmp(s.Tags, id)), suite);      % MATLAB: tag
inP   = arrayfun(@(p) contains(p.name, strrep(id, '-', '_')), py);  % pytest: name
mTest = suite(inM);
mRes  = res(inM);
pRes  = py(inP);
tests = [{mTest.Name}, strcat({'pytest: '}, {pRes.name})];   % {} keeps the space

failed     = [[mRes.Failed], [pRes.failed]];
incomplete = [[mRes.Incomplete], [pRes.skipped]];
if isempty(tests)
    verdict = 'Unverified';
elseif any(failed)
    failedM = mTest([mRes.Failed]);
    allKnown = all(arrayfun(@(s) any(strcmp(s.Tags, 'KnownFail')), failedM));
    if allKnown && ~any([pRes.failed])
        verdict = 'Fail (known)';
    else
        verdict = 'Fail';
    end
elseif any(incomplete)
    verdict = 'Unverified';
else
    verdict = 'Pass';
end

% Measured values recorded by the tests. A pytest-only requirement records
% none, so the pass count is the evidence instead.
e = ev(strcmp({ev.req}, id));
if ~isempty(e)
    parts    = arrayfun(@(x) sprintf('%s: %.4g %s', x.quantity, x.value, x.unit), e, 'UniformOutput', false);
    measured = strjoin(parts, '<br>');
elseif ~isempty(tests)
    measured = sprintf('%d/%d tests passed', sum(~failed & ~incomplete), numel(tests));
else
    measured = '–';
end
end

function writeReport(mdFile, req, commit)
% Markdown report. Opened as UTF-8 because the acceptance texts contain
% characters such as ≤, ± and ε. Every line goes through fprintf('%s\n', ...):
% the texts contain '%' (e.g. '10 %'), which fprintf would read as a format
% code if the text itself were the format.
% A '|' inside a cell would end the cell, so escape it as '\|' (pipes that
% are already escaped, as in the acceptance texts, are left alone).
esc = @(s) regexprep(s, '(?<!\\)\|', '\\|');
v = {req.verdict};
L = {
    '# Traceability'
    ''
    'Generated by `src/matlab/run_tests.m`; do not edit by hand. Requirements: [REQ.md](../requirements/REQ.md).'
    ''
    sprintf('- Generated: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')))
    sprintf('- Commit: `%s`', commit)
    sprintf('- MATLAB: %s', version)
    sprintf('- Result: **%d Pass, %d Fail (%d known), %d Unverified** of %d requirements', ...
        sum(strcmp(v, 'Pass')), sum(startsWith(v, 'Fail')), sum(strcmp(v, 'Fail (known)')), ...
        sum(strcmp(v, 'Unverified')), numel(v))
    ''
    'Pass: all linked tests passed. Fail (known): the failing test is tagged `KnownFail` (accepted, strategy to be improved). Unverified: no test yet, or a test could not run.'
    ''
    '| REQ | Title | Tests | Acceptance | Measured | Verdict |'
    '|---|---|---|---|---|---|'
    };
for i = 1:numel(req)
    t = strjoin(strcat('`', req(i).tests, '`'), '<br>');
    if isempty(t)
        t = '–';
    end
    L{end+1, 1} = sprintf('| %s | %s | %s | %s | %s | **%s** |', req(i).id, esc(req(i).title), ...
        esc(t), esc(req(i).acceptance), esc(req(i).measured), req(i).verdict); %#ok<AGROW>
end
L{end+1, 1} = '';
L{end+1, 1} = 'Raw output of the run (git-ignored): `results/test/matlab_junit.xml`, `pytest_junit.xml`, `evidence.jsonl`.';

fid = fopen(mdFile, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_tests:write', 'Cannot write %s', mdFile);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', L{:});
end

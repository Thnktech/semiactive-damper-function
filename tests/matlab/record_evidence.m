function record_evidence(req, test, quantity, value, unit)
%RECORD_EVIDENCE Store a measured value for the traceability report (M4).
%   RECORD_EVIDENCE(req, test, quantity, value, unit) appends one JSON line
%   {req, test, quantity, value, unit} to the file named by the environment
%   variable EVIDENCE_FILE (set by run_tests). Without it, nothing happens,
%   so tests behave the same when run directly with runtests.
%
%   Example: record_evidence('REQ-S-01', 'TestSafety/REQ_S_01_fault_reaction_time', ...
%                            'fault reaction time', 5.0, 'ms')

f = getenv('EVIDENCE_FILE');
if isempty(f)
    return
end
e = struct('req', req, 'test', test, 'quantity', quantity, 'value', value, 'unit', unit);
fid = fopen(f, 'a');
if fid < 0
    warning('record_evidence:file', 'Cannot write evidence file %s', f);
    return
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(e));
end
